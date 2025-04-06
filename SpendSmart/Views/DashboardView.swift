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

struct DashboardView: View {
    var email: String
    @EnvironmentObject var appState: AppState
    @State private var currentUserReceipts: [Receipt] = []
    @Environment(\.colorScheme) private var colorScheme
    @State private var showNewExpenseSheet = false
    @State private var isRefreshing = false // For refresh control
    @State private var isLoading = false
    @State private var showingEarned = false // false = showing Spent, true = showing Earned
    // MARK: - Fetch Receipts
    func fetchUserReceipts() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        isLoading = true  // Start loading
        defer { isLoading = false }  // Ensure loading stops after fetch
        
        do {
            let response = try await supabase
                .from("receipts")
                .select()
                .eq("user_id", value: userId)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                if let date = formatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date: \(dateString)"
                )
            }
            
            let receipts = try decoder.decode([Receipt].self, from: response.data)
            withAnimation {
                currentUserReceipts = receipts
            }
        } catch let error as DecodingError {
            print("❌ Decoding Error fetching receipts: \(error)")
        } catch {
            print("❌ General Error fetching receipts: \(error.localizedDescription)")
        }
    }

    
    // MARK: - Insert Receipt
    func insertReceipt(newReceipt: Receipt) async {
        do {
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            try await supabase
                .from("receipts")
                .insert(newReceipt)
                .execute()
            
            print("✅ Receipt inserted successfully!")
        } catch {
            print("❌ Error inserting receipt: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Calculate Costs By Category (Including Tax)
    func calculateCostByCategory(receipts: [Receipt]) -> [(category: String, total: Double)] {
        var categoryTotals: [String: Double] = [:]
        
        for receipt in receipts {
            // Sum each item's price by category.
            for item in receipt.items {
                categoryTotals[item.category, default: 0] += item.price
            }
            // Add the receipt's tax to the "Tax" category.
            categoryTotals["Tax", default: 0] += receipt.total_tax
        }
        
        return categoryTotals.map { (category: $0.key, total: $0.value) }
    }
    
    // MARK: - Calculate Summary Data
    func calculateSummary(receipts: [Receipt]) -> (totalExpense: Double, totalTax: Double) {
        var totalExpense = 0.0
        var totalTax = 0.0
        
        for receipt in receipts {
            totalExpense += receipt.total_amount
            totalTax += receipt.total_tax
        }
        
        return (totalExpense, totalTax)
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
//                        let summary = calculateSummary(receipts: currentUserReceipts)
                        let costByCategory = calculateCostByCategory(receipts: currentUserReceipts)
                        
                        // Monthly Bar Chart
                        MonthlyBarChartView(receipts: currentUserReceipts)
                            .padding(.bottom, 5)
                        
                        // Category List View
                        ExpenseCategoryListView(categoryCosts: costByCategory)
                            .padding(.bottom, 5)
                        
                        // Moved Donut Chart to bottom
                        VStack(spacing: 16) {
                            
                            Chart(costByCategory, id: \.category) { item in
                                SectorMark(
                                    angle: .value("Total", item.total),
                                    innerRadius: .ratio(0.65),
                                    angularInset: 2.0
                                )
                                .cornerRadius(12)
                                .foregroundStyle(by: .value("Category", item.category))
                                .annotation(position: .overlay) {
                                    Text("$\(Int(item.total))")
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
struct SummaryCardView: View {
    var totalExpense: Double
    var totalTax: Double
    var receiptCount: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Text("Home")
                .font(.instrumentSerif(size: 36))
                .foregroundColor(colorScheme == .dark ? .white : .black)

            HStack {
                SummaryItemView(title: "Total Expenses", amount: totalExpense)
                Divider()
                    .frame(height: 50)
                    .background(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                SummaryItemView(title: "Tax Paid", amount: totalTax)
            }

            Text(receiptCount == 1 ? "1 receipt" : "\(receiptCount) receipts")
                .font(.instrumentSans(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundGradient) // Using the same background style
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.7),
                                    accentColor.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: shadowColor, radius: 8, x: 0, y: 4) // Keeping a similar shadow
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

    var body: some View {
        VStack {
            Text(title)
                .font(.instrumentSans(size: 14))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
            Text("$\(amount, specifier: "%.2f")")
                .font(.spaceGrotesk(size: 20, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MonthlyBarChartView: View {
    var receipts: [Receipt]
    @Environment(\.colorScheme) private var colorScheme
    
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
        
        // Sum receipts by month
        for receipt in receipts {
            let monthStr = dateFormatter.string(from: receipt.purchase_date)
            monthlyTotals[monthStr, default: 0] += receipt.total_amount
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
                                Text("$\(Int(doubleValue))")
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

            Text(String(format: "$%.2f", item.total))
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
