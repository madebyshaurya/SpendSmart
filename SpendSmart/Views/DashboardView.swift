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
import UIKit

struct DashboardView: View {
    var email: String
    var openSubscriptions: (() -> Void)? = nil
    @EnvironmentObject var appState: AppState
    @State private var currentUserReceipts: [Receipt] = []
    @Environment(\.colorScheme) private var colorScheme
    @State private var showNewExpenseSheet = false
    @State private var isRefreshing = false // For refresh control
    @State private var isLoading = false
    @State private var showingEarned = false // false = showing Spent, true = showing Earned
    @State private var selectedReceipt: Receipt? = nil
    @State private var showMapView = false
    @State private var lastFetchTime: Date = Date()
    @State private var lastSuccessfulReceipts: [Receipt] = []
    
    // MARK: - Fetch Receipts
    func fetchUserReceipts() async throws {
        print("🔄 [DashboardView] Starting fetchUserReceipts...")
        print("🔄 [DashboardView] Current receipts count: \(currentUserReceipts.count)")
        
        // Only show loading indicator if we don't have any receipts yet
        if currentUserReceipts.isEmpty {
            isLoading = true
        }
        
        defer { 
            isLoading = false 
            lastFetchTime = Date()
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
                lastSuccessfulReceipts = receipts // Store successful fetch
            }
            print("✅ [DashboardView] Receipts successfully assigned to currentUserReceipts")
        } catch {
            print("❌ [DashboardView] Error fetching receipts: \(error.localizedDescription)")
            print("❌ [DashboardView] Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ [DashboardView] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ [DashboardView] Error userInfo: \(nsError.userInfo)")
                
                // Handle network cancellation errors gracefully
                if (nsError.domain == "NSURLErrorDomain" && nsError.code == -999) || 
                   (nsError.domain == "SupabaseManager" && nsError.code == -999) {
                    // Don't log this as it's normal behavior during refresh
                    // Don't clear the receipts array for cancelled requests
                    return
                }
            }
            
            // Only set empty array for actual errors, not cancellations
            // But preserve existing receipts if this is a refresh operation
            if currentUserReceipts.isEmpty {
                if !lastSuccessfulReceipts.isEmpty {
                    print("⚠️ [DashboardView] Restoring last successful receipts due to fetch error")
                    withAnimation {
                        currentUserReceipts = lastSuccessfulReceipts
                    }
                } else {
                    withAnimation {
                        currentUserReceipts = []
                    }
                }
            } else {
                print("⚠️ [DashboardView] Keeping existing receipts due to fetch error")
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

        // Add subscriptions as a separate category (only actual charges this month)
        let subsChargedThisMonth = SubscriptionService.shared.actualChargedMonthlyCost(inPreferredCurrency: preferredCurrency, converter: currencyManager.convertAmountSync)
        if subsChargedThisMonth > 0 {
            categoryTotals["Subscriptions", default: 0] += subsChargedThisMonth
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

        // Include only actual subscription charges this month to the totalExpense displayed in dashboard summary
        let subsChargedThisMonth = SubscriptionService.shared.actualChargedMonthlyCost(inPreferredCurrency: preferredCurrency, converter: CurrencyManager.shared.convertAmountSync)
        return (totalExpense + subsChargedThisMonth, totalTax, totalSavings)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            BackgroundGradientView()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.sectionSpacing) {
                    // App title with enhanced typography
                    Text("SpendSmart")
                        .font(DesignTokens.Typography.brandTitle(size: UIFontMetrics.default.scaledValue(for: 36)))
                        .foregroundColor(DesignTokens.Colors.Neutral.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .hierarchySpacing(.section)
                        .accessibilityAddTraits(.isHeader)

                    if isLoading && currentUserReceipts.isEmpty {
                        LoadingCard(
                            title: "Loading receipts...",
                            subtitle: "Fetching your latest expense data"
                        )
                        .hierarchySpacing(.content)
                    } else {
                        let summary = calculateSummary(receipts: currentUserReceipts)
                        let costByCategory = calculateCostByCategory(receipts: currentUserReceipts)
                        
                        // Show refresh indicator if refreshing with existing data
                        if isRefreshing && !currentUserReceipts.isEmpty {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Refreshing...")
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }

                        // Enhanced dashboard components with better spacing
                        SavingsSummaryView(
                            totalExpense: summary.totalExpense, 
                            totalTax: summary.totalTax, 
                            totalSavings: summary.totalSavings, 
                            receiptCount: currentUserReceipts.count
                        )

                        SubscriptionSummaryView(onManageTap: { openSubscriptions?() })
                            .semanticSpacing(.cardOuter)

                        MonthlyBarChartView(receipts: currentUserReceipts)
                            .semanticSpacing(.cardOuter)

                        ExpenseCategoryListView(categoryCosts: costByCategory)
                            .semanticSpacing(.cardOuter)

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
                                            Text("Expense Map")
                                                .font(.instrumentSans(size: 24, weight: .semibold))
                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                        }
                                    }

                                    Text("Explore purchases by location")
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
                        CategoryDonutChartView(costByCategory: costByCategory)
                            .padding(.bottom, 5)
                    }
                }
                .padding(.bottom, 100) // Add padding for FAB
            }
            .refreshable {
                print("🔄 [DashboardView] Pull-to-refresh triggered")
                isRefreshing = true
                
                // Add a small delay to ensure the refresh animation is visible
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                do {
                    try await fetchUserReceipts()
                } catch {
                    print("❌ [DashboardView] Refresh failed: \(error.localizedDescription)")
                    // Don't clear existing data on refresh failure
                }
                
                // Add a small delay before hiding the refresh indicator
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                isRefreshing = false
                
                print("🔄 [DashboardView] Pull-to-refresh completed")
            }

            // Enhanced Floating Action Button
            VStack {
                Spacer()
                PrimaryButton(
                    "New Expense",
                    icon: "plus",
                    isLoading: false,
                    isDisabled: false
                ) {
                    if appState.isHapticsEnabled {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                    showNewExpenseSheet.toggle()
                }
                .frame(maxWidth: 280)
                .designSystemShadow(DesignTokens.Shadow.lg)
                .scaleEffect(showNewExpenseSheet ? 1.02 : 1.0)
                .animation(DesignTokens.Animation.spring, value: showNewExpenseSheet)
                .padding(.bottom, DesignTokens.Spacing.xl)
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showNewExpenseSheet) {
                NewExpenseView(onReceiptAdded: { newReceipt in
                    Task {
                        await insertReceipt(newReceipt: newReceipt)
                        do {
                            try await fetchUserReceipts()
                        } catch {
                            print("❌ [DashboardView] Failed to refresh after adding receipt: \(error.localizedDescription)")
                        }
                        await MainActor.run {
                            if appState.isHapticsEnabled {
                                let notify = UINotificationFeedbackGenerator()
                                notify.notificationOccurred(.success)
                            }
                            showNewExpenseSheet = false
                            selectedReceipt = newReceipt
                        }
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
                do {
                    try await fetchUserReceipts()
                } catch {
                    print("❌ [DashboardView] Initial fetch failed: \(error.localizedDescription)")
                }
            }
        }
        
    }
}

// moved SavingsSummaryView, MonthlyBarChartView, ExpenseCategoryListView, and related helpers to HelperViews

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(email: "user@example.com")
            .preferredColorScheme(.dark)
    }
}
