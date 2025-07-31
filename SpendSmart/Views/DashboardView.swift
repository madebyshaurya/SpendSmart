//
//  DashboardView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-14.
//

import SwiftUI
import AuthenticationServices
import Supabase
import Charts
import Foundation
import MapKit

struct DashboardView: View {
    var email: String
    @EnvironmentObject var appState: AppState
    @State private var currentUserReceipts: [Receipt] = []
    @Environment(\.colorScheme) private var colorScheme
    @State private var showNewExpenseSheet = false
    @State private var isRefreshing = false // For refresh control
    @State private var isLoading = false
    @State private var showingEarned = false // false = showing Spent, true = showing Earned
    @State private var selectedReceipt: Receipt? = nil
    @State private var showMapView = false
    // MARK: - Fetch Receipts
    func fetchUserReceipts() async {
        print("🔄 [DashboardView] Starting fetchUserReceipts...")
        isLoading = true  // Start loading
        defer { 
            isLoading = false 
            print("🔄 [DashboardView] Finished fetchUserReceipts, isLoading set to false")
        }

        // Check if we're in guest mode (using local storage)
        if appState.useLocalStorage {
            print("💾 [DashboardView] Using local storage mode")
            // Get receipts from local storage
            let receipts = LocalStorageService.shared.getReceipts()
            print("💾 [DashboardView] Retrieved \(receipts.count) receipts from local storage")
            withAnimation {
                currentUserReceipts = receipts
            }
            print("✅ [DashboardView] Local receipts loaded successfully")
            return
        }

        print("🌐 [DashboardView] Using remote Supabase mode")
        print("🔐 [DashboardView] User logged in: \(appState.isLoggedIn)")
        print("📧 [DashboardView] User email: \(appState.userEmail)")

        // If not in guest mode, fetch from backend API
        do {
            print("📡 [DashboardView] Calling supabase.fetchReceipts...")
            let receipts = try await supabase.fetchReceipts(page: 1, limit: 1000)
            print("✅ [DashboardView] Successfully received \(receipts.count) receipts from Supabase")
            
            // Log first few receipts for debugging
            for (index, receipt) in receipts.prefix(3).enumerated() {
                print("📋 [DashboardView] Receipt \(index + 1): \(receipt.store_name) - $\(receipt.total_amount) (\(receipt.items.count) items)")
            }
            
            withAnimation {
                currentUserReceipts = receipts
            }
            print("✅ [DashboardView] Receipts successfully assigned to currentUserReceipts")
        } catch {
            print("❌ [DashboardView] Error fetching receipts: \(error.localizedDescription)")
            print("❌ [DashboardView] Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ [DashboardView] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ [DashboardView] Error userInfo: \(nsError.userInfo)")
            }
            
            // Set empty array on error so UI doesn't show stale data
            withAnimation {
                currentUserReceipts = []
            }
        }
    }


    // MARK: - Insert Receipt
    func insertReceipt(newReceipt: Receipt) async {
        // Check if we're in guest mode (using local storage)
        if appState.useLocalStorage {
            // Save receipt to local storage
            LocalStorageService.shared.addReceipt(newReceipt)
            print("✅ Receipt saved to local storage successfully!")
            return
        }

        // If not in guest mode, save via backend API
        do {
            _ = try await supabase.createReceipt(newReceipt)
            print("✅ Receipt inserted successfully!")
        } catch {
            print("❌ Error inserting receipt: \(error.localizedDescription)")
        }
    }

    // MARK: - Update Receipt
    func updateReceipt(updatedReceipt: Receipt) async {
        // Check if we're in guest mode (using local storage)
        if appState.useLocalStorage {
            // Update in local storage
            var receipts = LocalStorageService.shared.getReceipts()
            if let index = receipts.firstIndex(where: { $0.id == updatedReceipt.id }) {
                receipts[index] = updatedReceipt
                LocalStorageService.shared.saveReceipts(receipts)
                print("✅ Receipt updated in local storage successfully!")
            }
            return
        }

        // If not in guest mode, update via backend API
        do {
            _ = try await supabase.updateReceipt(updatedReceipt)
            print("✅ Receipt updated successfully!")
        } catch {
            print("❌ Error updating receipt: \(error.localizedDescription)")
        }
    }

    // MARK: - Calculate Costs By Category (Including Tax)
    func calculateCostByCategory(receipts: [Receipt]) -> [(category: String, total: Double)] {
        var categoryTotals: [String: Double] = [:]
        let currencyManager = CurrencyManager.shared
        let preferredCurrency = currencyManager.preferredCurrency

        for receipt in receipts {
            // Sum each item's price by category, but only if it's not a discount or points redemption
            for item in receipt.items {
                // Skip items that are discounts or points redemptions
                if item.isDiscount || (item.price == 0 && item.discountDescription?.lowercased().contains("point") == true) {
                    continue
                }

                // Convert item price to preferred currency
                let convertedPrice = currencyManager.convertAmountSync(item.price,
                                                                    from: receipt.currency,
                                                                    to: preferredCurrency)

                categoryTotals[item.category, default: 0] += convertedPrice
            }

            // Add the receipt's tax to the "Tax" category (converted to preferred currency)
            let convertedTax = currencyManager.convertAmountSync(receipt.total_tax,
                                                              from: receipt.currency,
                                                              to: preferredCurrency)
            categoryTotals["Tax", default: 0] += convertedTax
        }

        return categoryTotals.map { (category: $0.key, total: $0.value) }
    }

    // MARK: - Calculate Summary Data
    func calculateSummary(receipts: [Receipt]) -> (totalExpense: Double, totalTax: Double, totalSavings: Double) {
        var totalExpense = 0.0
        var totalTax = 0.0
        var totalSavings = 0.0

        let currencyManager = CurrencyManager.shared
        let preferredCurrency = currencyManager.preferredCurrency

        for receipt in receipts {
            // Convert amounts to preferred currency before adding
            let convertedAmount = currencyManager.convertAmountSync(receipt.total_amount,
                                                                 from: receipt.currency,
                                                                 to: preferredCurrency)
            let convertedTax = currencyManager.convertAmountSync(receipt.total_tax,
                                                              from: receipt.currency,
                                                              to: preferredCurrency)
            let convertedSavings = currencyManager.convertAmountSync(receipt.savings,
                                                                  from: receipt.currency,
                                                                  to: preferredCurrency)

            // Add the converted amounts
            totalExpense += convertedAmount
            totalTax += convertedTax
            totalSavings += convertedSavings
        }

        return (totalExpense, totalTax, totalSavings)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            BackgroundGradientView()

            ScrollView {
                VStack(spacing: 20) {
                    // App title at top
                    Text("SpendSmart")
                        .font(.instrumentSerifItalic(size: 36))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)

                    if isLoading {
                        ProgressView("Loading receipts...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(.top, 30)
                    } else if currentUserReceipts.isEmpty {
                        Text("No receipts found.")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding()
                    } else {
                        let summary = calculateSummary(receipts: currentUserReceipts)
                        let costByCategory = calculateCostByCategory(receipts: currentUserReceipts)

                        // Summary Card with Savings
                        SavingsSummaryView(totalExpense: summary.totalExpense, totalTax: summary.totalTax, totalSavings: summary.totalSavings, receiptCount: currentUserReceipts.count)
                            .padding(.bottom, 5)

                        // Monthly Bar Chart
                        MonthlyBarChartView(receipts: currentUserReceipts)
                            .padding(.bottom, 5)

                        // Category List View
                        ExpenseCategoryListView(categoryCosts: costByCategory)
                            .padding(.bottom, 5)

                        // Map View Button
                        Button {
                            showMapView = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "map.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)

                                        HStack(spacing: 8) {
                                            Text("Spending Map")
                                                .font(.instrumentSans(size: 24, weight: .semibold))
                                                .foregroundColor(colorScheme == .dark ? .white : .black)

                                            Text("BETA")
                                                .font(.instrumentSans(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.blue)
                                                )
                                        }
                                    }

                                    Text("View your spending patterns by location")
                                        .font(.instrumentSans(size: 16))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                                }

                                Spacer()

                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.9))
                                    .shadow(color: colorScheme == .dark ? Color.blue.opacity(0.2) : Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(0.5),
                                                Color.blue.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.bottom, 5)

                        // Donut Chart
                        VStack(spacing: 16) {
                            HStack {
                                Text("Spending Breakdown")
                                    .font(.instrumentSans(size: 24, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                Spacer()
                            }
                            .padding(.horizontal)

                            Chart(costByCategory, id: \.category) { item in
                                SectorMark(
                                    angle: .value("Total", item.total),
                                    innerRadius: .ratio(0.65),
                                    angularInset: 2.0
                                )
                                .cornerRadius(12)
                                .foregroundStyle(by: .value("Category", item.category))
                                .annotation(position: .overlay) {
                                    Text(CurrencyManager.shared.formatAmount(item.total, currencyCode: CurrencyManager.shared.preferredCurrency))
                                        .font(.spaceGrotesk(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(8)
                                }
                            }
                            .chartLegend(.visible)
                            .frame(height: 250)
                            .padding(30)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(colorScheme == .dark ?
                                          Color.black.opacity(0.5) :
                                          Color.white.opacity(0.9))
                                    .shadow(color: colorScheme == .dark ?
                                            Color.blue.opacity(0.2) :
                                            Color.black.opacity(0.1),
                                            radius: 8, x: 0, y: 4)
                            )
                            .padding()
                        }
                    }
                }
                .padding(.bottom, 100) // Add padding for FAB
            }
            .refreshable {
                isRefreshing = true
                await fetchUserReceipts()
                isRefreshing = false
            }

            // New Expense Button with Animation
            VStack {
                Spacer()
                Button {
                    showNewExpenseSheet.toggle()
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(.leading, 10)

                        Text("New Expense")
                            .font(.instrumentSans(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 15)
                    .padding(.horizontal, 60)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.blue.gradient)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                    .scaleEffect(showNewExpenseSheet ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showNewExpenseSheet)
                }
                .padding(.bottom, 20)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(isPresented: $showNewExpenseSheet) {
                NewExpenseView(onReceiptAdded: { newReceipt in
                    Task {
                        await insertReceipt(newReceipt: newReceipt)
                        await fetchUserReceipts()
                    }
                })
                .environmentObject(appState)
            }
            .sheet(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt, onUpdate: { updatedReceipt in
                    // Update the receipt in our local array and database
                    Task {
                        await updateReceipt(updatedReceipt: updatedReceipt)
                        if let index = currentUserReceipts.firstIndex(where: { $0.id == updatedReceipt.id }) {
                            currentUserReceipts[index] = updatedReceipt
                        }
                    }
                })
                .environmentObject(appState)
            }

            // Map View Modal
            if showMapView {
                MapViewModal(isPresented: $showMapView, receipts: currentUserReceipts)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: currentUserReceipts)
        .onAppear {
            Task {
                await fetchUserReceipts()
            }
        }
    }
}

// MARK: - Summary Card View
struct SavingsSummaryView: View {
    var totalExpense: Double
    var totalTax: Double
    var totalSavings: Double
    var receiptCount: Int
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Spending Summary")
                    .font(.instrumentSans(size: 24, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()

                Text(receiptCount == 1 ? "1 receipt" : "\(receiptCount) receipts")
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
                    )
            }

            HStack(spacing: 12) {
                // Actual Expenses
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.blue)
                        Text("Actual Spent")
                            .font(.instrumentSans(size: 14))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    }

                    Text(currencyManager.formatAmount(totalExpense, currencyCode: currencyManager.preferredCurrency))
                        .font(.spaceGrotesk(size: 24, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.1))
                )

                // Savings - Only show if totalSavings > 0
                if totalSavings > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.green)
                            Text("Savings")
                                .font(.instrumentSans(size: 14))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                        }

                        Text(currencyManager.formatAmount(totalSavings, currencyCode: currencyManager.preferredCurrency))
                            .font(.spaceGrotesk(size: 24, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.green.opacity(0.15) : Color.green.opacity(0.1))
                    )
                }
            }

            // Tax row
            HStack {
                Image(systemName: "building.columns.fill")
                    .foregroundColor(.orange)
                Text("Tax Paid")
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))

                Spacer()

                Text(currencyManager.formatAmount(totalTax, currencyCode: currencyManager.preferredCurrency))
                    .font(.spaceGrotesk(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.orange.opacity(0.15) : Color.orange.opacity(0.1))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.9))
                .shadow(color: colorScheme == .dark ? Color.blue.opacity(0.2) : Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .transition(.opacity)
    }

    // This creates the same kind of background look as your ReceiptCard
    private var backgroundGradient: some ShapeStyle {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color(UIColor.systemBackground).opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white,
                    Color.white.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // This will be the color of the border. You can pick any color you like!
    private var accentColor: Color {
        return Color.blue // You can change this to your preferred color
    }

    // This creates a subtle shadow, similar to the ReceiptCard
    private var shadowColor: Color {
        colorScheme == .dark
        ? accentColor.opacity(0.3)
        : accentColor.opacity(0.2)
    }
}

struct SummaryItemView: View {
    let title: String
    let amount: Double
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        VStack {
            Text(title)
                .font(.instrumentSans(size: 14))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
            Text(currencyManager.formatAmount(amount, currencyCode: currencyManager.preferredCurrency))
                .font(.spaceGrotesk(size: 20, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MonthlyBarChartView: View {
    var receipts: [Receipt]
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared

    // Function to group receipts by month
    func receiptsByMonth() -> [(month: String, total: Double)] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"

        var monthlyTotals: [String: Double] = [:]
        let calendar = Calendar.current

        // Initialize with last 8 months
        let currentDate = Date()
        for i in 0..<8 {
            if let date = calendar.date(byAdding: .month, value: -i, to: currentDate) {
                let monthStr = dateFormatter.string(from: date)
                monthlyTotals[monthStr] = 0
            }
        }

        // Sum receipts by month using actualAmountSpent converted to preferred currency
        let currencyManager = CurrencyManager.shared
        let preferredCurrency = currencyManager.preferredCurrency

        for receipt in receipts {
            let monthStr = dateFormatter.string(from: receipt.purchase_date)
            // Convert amount to preferred currency before adding
            let convertedAmount = currencyManager.convertAmountSync(receipt.actualAmountSpent,
                                                                 from: receipt.currency,
                                                                 to: preferredCurrency)
            monthlyTotals[monthStr, default: 0] += convertedAmount
        }

        // Sort by month (chronologically)
        let sortedMonths = monthlyTotals.keys.sorted { month1, month2 in
            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            return months.firstIndex(of: month1)! < months.firstIndex(of: month2)!
        }

        return sortedMonths.prefix(8).map { (month: $0, total: monthlyTotals[$0]!) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Monthly")
                    .font(.instrumentSans(size: 24))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()
            }

            let monthlyData = receiptsByMonth()
            // Make sure we have data before showing the chart
            if !monthlyData.isEmpty {
                Chart(monthlyData, id: \.month) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.total)
                    )
                    .cornerRadius(6)
                    .foregroundStyle(Color.blue.gradient)
                }
                .chartYAxis {
                    AxisMarks(preset: .extended, position: .leading) { value in
                        if let doubleValue = value.as(Double.self) {
                            AxisGridLine()
                            AxisValueLabel {
                                Text(currencyManager.formatAmount(doubleValue, currencyCode: currencyManager.preferredCurrency))
                                    .font(.instrumentSans(size: 12))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let month = value.as(String.self) {
                                Text(month)
                                    .font(.instrumentSans(size: 12))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ?
                      Color.black.opacity(0.5) :
                      Color.white.opacity(0.9))
                .shadow(color: colorScheme == .dark ?
                        Color.blue.opacity(0.2) :
                        Color.black.opacity(0.1),
                        radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct ExpenseCategoryListView: View {
    var categoryCosts: [(category: String, total: Double)]
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared

    // Category icon mapping
    func iconForCategory(_ category: String) -> (name: String, color: Color) {
        switch category.lowercased() {
        case "rent", "housing":
            return ("house.fill", .red)
        case "bills", "utilities":
            return ("creditcard.fill", .blue)
        case "groceries", "food":
            return ("cart.fill", .green)
        case "internet", "wifi":
            return ("wifi", .purple)
        case "tax":
            return ("dollarsign.circle.fill", .orange)
        case "transport", "travel":
            return ("car.fill", .yellow)
        case "entertainment", "fun":
            return ("gamecontroller.fill", .pink)
        case "shopping", "clothing":
            return ("bag.fill", .cyan)
        case "health", "medical":
            return ("cross.case.fill", .mint)
        case "education", "school":
            return ("book.fill", .teal)
        case "subscriptions", "services":
            return ("person.crop.circle.fill", .indigo)
        case "dining":
            return ("fork.knife", .pink)
        case "other":
            return ("tag.fill", .gray)
        default:
            return ("tag.fill", .gray)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            let sortedCategories = categoryCosts.sorted(by: { $0.total > $1.total })
            ForEach(sortedCategories.indices, id: \.self) { index in
                categoryRow(item: sortedCategories[index], isFirst: index == 0, isLast: index == sortedCategories.count - 1)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ?
                      Color.black.opacity(0.5) :
                      Color.white.opacity(0.9))
                .shadow(color: colorScheme == .dark ?
                            Color.blue.opacity(0.2) :
                            Color.black.opacity(0.1),
                        radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.5),
                            Color.blue.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal)
    }

    // Extracted category row into a separate function
    private func categoryRow(item: (category: String, total: Double), isFirst: Bool, isLast: Bool) -> some View {
        let iconInfo = iconForCategory(item.category)

        let rowContent = HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconInfo.color.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: iconInfo.name)
                    .foregroundColor(iconInfo.color)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.category)
                    .font(.instrumentSans(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text("\(item.category.lowercased()) and related expenses")
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            .padding(.leading, 8)

            Spacer()

            Text(currencyManager.formatAmount(item.total, currencyCode: currencyManager.preferredCurrency))
                .font(.spaceGrotesk(size: 18, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding()
        .background(
            colorScheme == .dark ?
                Color.black.opacity(0.5) :
                Color.white.opacity(0.9)
        )
        .cornerRadius(isFirst ? 20 : 0)

        return VStack(spacing: 0) {
            rowContent

            if !isLast {
                Divider()
                    .padding(.horizontal)
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
            }
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(email: "user@example.com")
            .preferredColorScheme(.dark)
    }
}
