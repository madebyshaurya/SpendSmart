//
//  SubscriptionInsightsView.swift
//  SpendSmart
//
//  Created by AI Assistant on 2025-01-19.
//

import SwiftUI
import Charts

/// Comprehensive subscription insights and analytics view
struct SubscriptionInsightsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var currencyManager = CurrencyManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeframe: Timeframe = .month
    @State private var animateCharts = false
    
    enum Timeframe: String, CaseIterable {
        case month = "This Month"
        case quarter = "This Quarter"
        case year = "This Year"
        case lifetime = "All Time"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                BackgroundGradientView()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header with timeframe selector
                        VStack(spacing: 16) {
                            Text("Subscription Insights")
                                .font(.instrumentSerifItalic(size: 32))
                                .foregroundColor(.primary)
                                .padding(.top, 8)
                            
                            // Timeframe picker
                            Picker("Timeframe", selection: $selectedTimeframe) {
                                ForEach(Timeframe.allCases, id: \.self) { timeframe in
                                    Text(timeframe.rawValue).tag(timeframe)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .glassBackground(cornerRadius: 12)
                        }
                        .padding(.horizontal)
                        
                        // Key metrics cards
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                            MetricCard(
                                title: "Monthly Spending",
                                value: formattedMonthlyTotal,
                                subtitle: "across \(activeSubscriptions.count) services",
                                icon: "creditcard.fill",
                                color: .blue,
                                isAnimated: animateCharts
                            )
                            
                            MetricCard(
                                title: "Average Cost",
                                value: formattedAverageCost,
                                subtitle: "per subscription",
                                icon: "chart.bar.fill",
                                color: .green,
                                isAnimated: animateCharts
                            )
                            
                            MetricCard(
                                title: "Next Renewal",
                                value: nextRenewalText,
                                subtitle: nextRenewalSubtitle,
                                icon: "calendar.badge.clock",
                                color: .orange,
                                isAnimated: animateCharts
                            )
                            
                            MetricCard(
                                title: "Annual Cost",
                                value: formattedAnnualTotal,
                                subtitle: "projected spending",
                                icon: "banknote.fill",
                                color: .purple,
                                isAnimated: animateCharts
                            )
                        }
                        .padding(.horizontal)
                        
                        // Spending breakdown chart
                        if !activeSubscriptions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Spending Breakdown")
                                    .font(.instrumentSans(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                
                                SpendingBreakdownChart(subscriptions: activeSubscriptions, isAnimated: animateCharts)
                                    .frame(height: 300)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical, 16)
                            .glassBackground(cornerRadius: 20, tint: .blue)
                            .padding(.horizontal)
                        }
                        
                        // Renewal timeline
                        if !upcomingRenewals.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Upcoming Renewals")
                                    .font(.instrumentSans(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                
                                ForEach(upcomingRenewals.prefix(5), id: \.id) { subscription in
                                    RenewalRow(subscription: subscription)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 16)
                            .glassBackground(cornerRadius: 20, tint: .green)
                            .padding(.horizontal)
                        }
                        
                        // Cost optimization suggestions
                        if !costOptimizationSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Cost Optimization")
                                    .font(.instrumentSans(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                
                                ForEach(costOptimizationSuggestions, id: \.title) { suggestion in
                                    OptimizationSuggestionCard(suggestion: suggestion)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 16)
                            .glassBackground(cornerRadius: 20, tint: .orange)
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .font(.instrumentSans(size: 16, weight: .medium))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export Report", action: exportReport)
                        Button("Share Insights", action: shareInsights)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateCharts = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var activeSubscriptions: [Subscription] {
        subscriptionService.subscriptions.filter { $0.is_active }
    }
    
    private var monthlyTotal: Double {
        activeSubscriptions.reduce(0) { total, subscription in
            total + subscription.monthlyEquivalentAmount
        }
    }
    
    private var annualTotal: Double {
        monthlyTotal * 12
    }
    
    private var averageCost: Double {
        guard !activeSubscriptions.isEmpty else { return 0 }
        return monthlyTotal / Double(activeSubscriptions.count)
    }
    
    private var formattedMonthlyTotal: String {
        currencyManager.formatAmount(monthlyTotal, currencyCode: currencyManager.preferredCurrency)
    }
    
    private var formattedAnnualTotal: String {
        currencyManager.formatAmount(annualTotal, currencyCode: currencyManager.preferredCurrency)
    }
    
    private var formattedAverageCost: String {
        currencyManager.formatAmount(averageCost, currencyCode: currencyManager.preferredCurrency)
    }
    
    private var upcomingRenewals: [Subscription] {
        let calendar = Calendar.current
        let thirtyDaysFromNow = calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        
        return activeSubscriptions
            .filter { $0.next_renewal_date <= thirtyDaysFromNow }
            .sorted { $0.next_renewal_date < $1.next_renewal_date }
    }
    
    private var nextRenewal: Subscription? {
        upcomingRenewals.first
    }
    
    private var nextRenewalText: String {
        guard let next = nextRenewal else { return "None soon" }
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: next.next_renewal_date, relativeTo: Date())
    }
    
    private var nextRenewalSubtitle: String {
        guard let next = nextRenewal else { return "No renewals in 30 days" }
        return next.service_name
    }
    
    private var costOptimizationSuggestions: [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []
        
        // Find expensive subscriptions
        let expensiveThreshold = monthlyTotal * 0.3
        let expensiveSubscriptions = activeSubscriptions.filter { $0.monthlyEquivalentAmount > expensiveThreshold }
        if !expensiveSubscriptions.isEmpty {
            suggestions.append(OptimizationSuggestion(
                title: "Review High-Cost Services",
                description: "Consider downgrading or canceling expensive subscriptions that you rarely use.",
                potentialSavings: expensiveSubscriptions.reduce(0) { $0 + $1.monthlyEquivalentAmount } * 0.5,
                type: .warning
            ))
        }
        
        // Find duplicate categories
        let serviceCategories = Dictionary(grouping: activeSubscriptions) { $0.category ?? "Uncategorized" }
        let duplicateCategories = serviceCategories.filter { $1.count > 2 }
        if !duplicateCategories.isEmpty {
            let potentialSavings = duplicateCategories.values.flatMap { $0 }.reduce(0) { $0 + $1.monthlyEquivalentAmount } * 0.3
            suggestions.append(OptimizationSuggestion(
                title: "Multiple Services in Same Category",
                description: "You have multiple subscriptions in the same category. Consider consolidating.",
                potentialSavings: potentialSavings,
                type: .info
            ))
        }
        
        // Trials ending soon
        let calendar = Calendar.current
        let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let endingTrials = activeSubscriptions.filter {
            $0.is_trial && ($0.trial_end_date ?? Date.distantFuture) <= sevenDaysFromNow
        }
        if !endingTrials.isEmpty {
            suggestions.append(OptimizationSuggestion(
                title: "Trials Ending Soon",
                description: "Don't forget to cancel or convert trials that are ending soon.",
                potentialSavings: endingTrials.reduce(0) { $0 + $1.monthlyEquivalentAmount },
                type: .warning
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Actions
    
    private func exportReport() {
        // Export functionality could be implemented here
        // Consider implementing PDF generation or data export
    }
    
    private func shareInsights() {
        let text = "My monthly subscription spending: \(formattedMonthlyTotal) across \(activeSubscriptions.count) services. Annual projection: \(formattedAnnualTotal)"
        
        let activityController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let isAnimated: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.instrumentSans(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .scaleEffect(isAnimated ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isAnimated)
                
                Text(title)
                    .font(.instrumentSans(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.instrumentSans(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .glassBackground(cornerRadius: 16)
    }
}

struct SpendingBreakdownChart: View {
    let subscriptions: [Subscription]
    let isAnimated: Bool
    
    var body: some View {
        Chart(Array(subscriptions.prefix(8)), id: \.id) { subscription in
            SectorMark(
                angle: .value("Amount", subscription.monthlyEquivalentAmount),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(by: .value("Service", subscription.service_name))
            .opacity(isAnimated ? 1.0 : 0.0)
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: isAnimated)
    }
}

struct RenewalRow: View {
    let subscription: Subscription
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(subscription.service_name.prefix(1)).uppercased())
                        .font(.instrumentSans(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.service_name)
                    .font(.instrumentSans(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(renewalDateText)
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(CurrencyManager.shared.formatAmount(subscription.amount, currencyCode: subscription.currency))
                .font(.instrumentSans(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
    }
    
    private var renewalDateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: subscription.next_renewal_date, relativeTo: Date())
    }
}

struct OptimizationSuggestion {
    let title: String
    let description: String
    let potentialSavings: Double
    let type: SuggestionType
    
    enum SuggestionType {
        case info, warning, success
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .success: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .success: return "checkmark.circle"
            }
        }
    }
}

struct OptimizationSuggestionCard: View {
    let suggestion: OptimizationSuggestion
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(suggestion.type.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.instrumentSans(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(suggestion.description)
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if suggestion.potentialSavings > 0 {
                    Text("Potential savings: \(CurrencyManager.shared.formatAmount(suggestion.potentialSavings, currencyCode: CurrencyManager.shared.preferredCurrency))/month")
                        .font(.instrumentSans(size: 11, weight: .medium))
                        .foregroundColor(suggestion.type.color)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .glassBackground(cornerRadius: 12, tint: suggestion.type.color)
    }
}

// Extension to calculate monthly equivalent for subscriptions
extension Subscription {
    var monthlyEquivalentAmount: Double {
        switch billing_cycle {
        case .weekly:
            return amount * 4.33 // Average weeks per month
        case .monthly:
            return amount
        case .quarterly:
            return amount / 3
        case .semiannual:
            return amount / 6
        case .annual:
            return amount / 12
        case .custom:
            let intervalMonths = Double(interval_count ?? 1)
            return amount / intervalMonths
        }
    }
}
