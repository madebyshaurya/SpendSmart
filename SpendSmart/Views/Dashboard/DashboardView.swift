import SwiftUI
import Charts
import MapKit

// MARK: - Dashboard View

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var haptics = HapticManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @Binding var showSettings: Bool

    @AppStorage("hasSeenBatchTip") private var hasSeenBatchTip = false
    @AppStorage("hasSeenInsightsTip") private var hasSeenInsightsTip = false
    @AppStorage("totalScanCount") private var totalScanCount = 0

    @State private var selectedWeekday: WeekdaySpending?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    DashboardSkeletonView()
                } else if viewModel.allReceipts.isEmpty {
                    EmptyStateView(type: .dashboard)
                        .background(Color.brandBackground)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {

                            // 1. Compact header — greeting + streak badge + settings gear
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.greetingMessage)
                                        .font(.manrope(size: 14, weight: .medium))
                                        .foregroundStyle(Color.brandTextSecondary)
                                    Text(viewModel.welcomeName)
                                        .font(.instrumentSerif(size: 26))
                                        .foregroundStyle(Color.brandTextPrimary)
                                }

                                Spacer()

                                CompactStreakBadge()

                                Button {
                                    haptics.buttonPress()
                                    showSettings = true
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.brandAccentLight)
                                            .frame(width: 40, height: 40)
                                        Text(viewModel.userEmoji)
                                            .font(.system(size: 18))
                                    }
                                }
                                .accessibilityLabel("Settings")
                            }
                            .animateEntrance(index: 0)

                            // 2. Hero spending card
                            HeroSummarySection(
                                selectedRange: $viewModel.selectedRange,
                                totalSpent: viewModel.totalSpent,
                                currencySymbol: viewModel.currencySymbol,
                                percentageChange: viewModel.percentageChange,
                                comparisonText: viewModel.comparisonText
                            )
                            .animateEntrance(index: 1)

                            // 3. Two-column quick stats grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                // Receipts count
                                quickStatTile(
                                    icon: "doc.text.fill",
                                    iconColor: .brandVibrantBlue,
                                    label: "Receipts",
                                    value: "\(viewModel.allReceipts.filter { $0.purchase_date >= viewModel.startDate }.count)"
                                )

                                // Average per receipt
                                quickStatTile(
                                    icon: "divide.circle.fill",
                                    iconColor: .brandSkyBlue,
                                    label: "Avg / Receipt",
                                    value: viewModel.formatCurrency(viewModel.averagePerReceipt)
                                )
                            }
                            .animateEntrance(index: 2)

                            // 4. Spending trend chart — clean card, no picker
                            if !viewModel.spendingChartData.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Spending Trend")
                                        .font(.manrope(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.brandTextPrimary)

                                    SpendingLineChart(
                                        data: viewModel.spendingChartData,
                                        chartHeight: 180
                                    )
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.brandSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.brandBorder, lineWidth: 1)
                                        )
                                )
                                .animateEntrance(index: 3)
                            }

                            // 5. Discovery banners
                            if totalScanCount >= 1 && !hasSeenBatchTip {
                                DiscoveryBanner(
                                    icon: "square.stack.3d.up",
                                    title: "Batch Mode Available",
                                    message: "Scan multiple receipts at once — toggle Batch Mode in the scanner.",
                                    onDismiss: { hasSeenBatchTip = true }
                                )
                            }
                            if totalScanCount >= 5 && !hasSeenInsightsTip && !SubscriptionManager.shared.isPlus {
                                DiscoveryBanner(
                                    icon: "lightbulb.fill",
                                    title: "Unlock Smart Insights",
                                    message: "You have enough data for AI spending insights. Upgrade to Plus!",
                                    onDismiss: { hasSeenInsightsTip = true }
                                )
                            }

                            // 6. AI Insights
                            if viewModel.aiInsight != nil || viewModel.isLoadingInsight {
                                DashboardAIInsightsSection(
                                    topCategory: viewModel.aiInsight?.topCategory ?? "Top Category",
                                    topCategoryAmount: viewModel.aiInsight?.topCategoryAmount ?? 0,
                                    topCategoryPercentage: viewModel.aiInsight?.topCategoryPercentage ?? 0,
                                    insightText: viewModel.aiInsight?.insight ?? "Your spending pattern insight will appear here.",
                                    comparisonNote: viewModel.aiInsight?.comparisonNote ?? "vs. last period",
                                    isLoading: viewModel.isLoadingInsight,
                                    onRefresh: {
                                        Task { await viewModel.refreshAIInsight() }
                                    }
                                )
                                .animateEntrance(index: 4)
                            }

                            // 7. Recent receipts
                            if !viewModel.recentReceipts.isEmpty {
                                RecentReceiptsSection(
                                    receipts: viewModel.recentReceipts,
                                    hasCloudWriteAccess: subscriptionManager.hasCloudWriteAccess
                                )
                                .animateEntrance(index: 5)
                            }

                            // 8. Map preview
                            if !viewModel.mapPreviewLocations.isEmpty {
                                DashboardMapPreviewSection(
                                    locations: viewModel.mapPreviewLocations,
                                    position: $viewModel.mapPreviewPosition,
                                    isLoading: viewModel.isMapPreviewLoading
                                )
                                .animateEntrance(index: 6)
                            }
                        }
                        .padding()
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.brandBackground)
                }
            }
            .refreshable {
                haptics.pullToRefresh()
                await viewModel.loadDashboardData()
            }
            .task {
                await viewModel.loadDashboardData()
                await viewModel.loadMapPreview()
                await viewModel.loadAIInsight()
            }
            .onChange(of: subscriptionManager.subscriptionStatus.tier) { _, _ in
                Task { await viewModel.loadDashboardData() }
            }
            .onChange(of: viewModel.allReceipts.count) { _, _ in
                Task { await viewModel.loadMapPreview() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Quick Stat Tile

    private func quickStatTile(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.manrope(size: 12, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
                Text(value)
                    .font(.ibmPlexMono(size: 18))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Color.brandTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Currency Mix

    private var currencyUsageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currencies")
                .font(.manrope(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandTextPrimary)

            if viewModel.currencyData.count <= 1, let currency = viewModel.currencyData.first {
                HStack {
                    Text(currency.code)
                        .font(.ibmPlexMono(size: 20))
                        .foregroundStyle(Color.brandTextPrimary)
                    Spacer()
                    Text("All receipts")
                        .font(.manrope(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brandSurfaceElevated)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.currencyData.prefix(4)) { currency in
                        HStack {
                            Text(currency.code)
                                .font(.ibmPlexMono(size: 14))
                                .foregroundStyle(Color.brandTextPrimary)

                            Spacer()

                            Text("\(currency.count) receipts")
                                .font(.manrope(size: 12, weight: .medium))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Payment Methods

    private var paymentMethodsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cards Used")
                .font(.manrope(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandTextPrimary)

            VStack(spacing: 8) {
                ForEach(viewModel.paymentMethodData.prefix(4)) { method in
                    HStack {
                        Text(method.method)
                            .font(.manrope(size: 14, weight: .medium))
                            .foregroundStyle(Color.brandTextPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(method.count) uses")
                            .font(.ibmPlexMono(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(Color.brandTextSecondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Spending Chart Card
    
    private var spendingChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Trend")
                .font(.manrope(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandTextPrimary)
            
            SpendingLineChart(
                data: viewModel.spendingChartData,
                chartHeight: 180
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Top Stores Card
    
    // MARK: - Recent Transactions Card
    
    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.manrope(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandTextPrimary)
            
            VStack(spacing: 8) {
                ForEach(viewModel.recentReceipts) { receipt in
                    RecentReceiptRow(receipt: receipt)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Savings Highlight Card
    
    private var savingsHighlightCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.brandSuccess.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "tag.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.brandSuccess)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("You've saved")
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
                
                Text(viewModel.formatCurrency(viewModel.totalSavings))
                    .font(.ibmPlexMono(size: 24))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(Color.brandSuccess)
                
                Text(viewModel.selectedRange.rawValue.lowercased())
                    .font(.manrope(size: 13, weight: .regular))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandTextTertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSuccessLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandSuccess.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Compact Streak Badge (inline header version)

private struct CompactStreakBadge: View {
    @AppStorage("scanStreakCount") private var streakCount = 0

    var body: some View {
        if streakCount > 0 {
            HStack(spacing: 4) {
                Image(systemName: streakCount >= 7 ? "flame.fill" : "flame")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(streakCount >= 7 ? Color.orange : Color.brandVibrantBlue)
                Text("\(streakCount)")
                    .font(.ibmPlexMono(size: 14))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(streakCount >= 7 ? Color.orange : Color.brandVibrantBlue)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((streakCount >= 7 ? Color.orange : Color.brandVibrantBlue).opacity(0.12))
            )
        }
    }
}

// MARK: - Recent Receipt Row

private struct RecentReceiptRow: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            CategoryIcon(category: receipt.items.first?.category ?? "Other", size: 40)
            
            // Receipt info
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.store_name.isEmpty ? "Unknown Store" : receipt.store_name)
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .lineLimit(1)
                
                Text(receipt.purchase_date.formatted(date: .abbreviated, time: .omitted))
                    .font(.manrope(size: 12, weight: .regular))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                CurrencyText(amount: receipt.total_amount, currency: receipt.currency)
                    .font(.ibmPlexMono(size: 14))
                    .monospacedDigit()
                    .foregroundStyle(Color.brandTextPrimary)

                if receipt.savings > 0 {
                    CurrencyText(amount: -receipt.savings, currency: receipt.currency)
                        .font(.manrope(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandSuccess)
                }

                if receipt.currency != CurrencyService.shared.preferredCurrency {
                    Text("Converted from \(receipt.currency)")
                        .font(.manrope(size: 10, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brandBackground)
        )
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: receipt.currency)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Insight Stat Card

private struct InsightStatCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.manrope(size: 11, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)

            Text(value)
                .font(.manrope(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .font(.ibmPlexMono(size: 12))
                .monospacedDigit()
                .foregroundStyle(Color.brandTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Weekday Chart

private struct WeekdayBarChart: View {
    let data: [WeekdaySpending]
    @State private var selectedDay: String?

    private var selectedDayItem: WeekdaySpending? {
        guard let selectedDay else { return nil }
        return data.first(where: { $0.label == selectedDay })
    }

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Day", item.label),
                y: .value("Total", item.totalAmount)
            )
            .foregroundStyle(Color.brandVibrantBlue)
            .cornerRadius(4)
            .opacity(selectedDay == nil || selectedDay == item.label ? 1.0 : 0.3)

            if let selectedItem = selectedDayItem {
                RuleMark(x: .value("Selected Day", selectedItem.label))
                    .foregroundStyle(Color.brandBorder)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 8) {
                        VStack(spacing: 2) {
                            Text(selectedItem.label)
                                .font(.manrope(size: 11, weight: .medium))
                                .foregroundStyle(Color.brandTextSecondary)
                            Text(CurrencyService.shared.formatAmount(selectedItem.totalAmount, currency: CurrencyService.shared.preferredCurrency))
                                .font(.ibmPlexMono(size: 14))
                                .monospacedDigit()
                                .foregroundStyle(Color.brandTextPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.brandSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    }
            }
        }
        .chartXSelection(value: $selectedDay)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.brandBorder)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("$\(Int(amount))")
                            .font(.manrope(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                }
            }
        }
        .onChange(of: selectedDay) { oldValue, newValue in
            if oldValue != newValue, newValue != nil {
                HapticManager.shared.selection()
            }
        }
        .frame(height: 170)
    }
}

// MARK: - Currency Mix Chart

private struct CurrencyMixChart: View {
    let data: [CurrencyUsage]
    @State private var selectedCurrency: String?

    private var selectedCurrencyItem: CurrencyUsage? {
        guard let selectedCurrency else { return nil }
        return data.first(where: { $0.code == selectedCurrency })
    }

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Currency", item.code),
                y: .value("Count", item.count)
            )
            .foregroundStyle(Color.brandRoyalBlue)
            .cornerRadius(4)
            .opacity(selectedCurrency == nil || selectedCurrency == item.code ? 1.0 : 0.3)

            if let selectedItem = selectedCurrencyItem {
                RuleMark(x: .value("Selected Currency", selectedItem.code))
                    .foregroundStyle(Color.brandBorder)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 8) {
                        VStack(spacing: 2) {
                            Text(selectedItem.code)
                                .font(.manrope(size: 11, weight: .medium))
                                .foregroundStyle(Color.brandTextSecondary)
                            Text("\(selectedItem.count) receipts")
                                .font(.ibmPlexMono(size: 14))
                                .monospacedDigit()
                                .foregroundStyle(Color.brandTextPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.brandSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    }
            }
        }
        .chartXSelection(value: $selectedCurrency)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.brandBorder)
                AxisValueLabel {
                    if let amount = value.as(Int.self) {
                        Text("\(amount)")
                            .font(.manrope(size: 10))
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                }
            }
        }
        .onChange(of: selectedCurrency) { oldValue, newValue in
            if oldValue != newValue, newValue != nil {
                HapticManager.shared.selection()
            }
        }
        .frame(height: 170)
    }
}

// MARK: - Enhanced Receipt Row (with Store Logo like Reference)

struct EnhancedReceiptRow: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: 14) {
            // Store logo
            BrandLogoView(storeName: receipt.store_name, logoSearchTerm: receipt.store_name)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
            
            // Store info and date
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.store_name.isEmpty ? "Unknown Store" : receipt.store_name)
                    .font(.manrope(size: 15, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(.manrope(size: 12, weight: .regular))
                        .foregroundStyle(Color.brandTextTertiary)
                    
                    // Category pill
                    if let category = receipt.items.first?.category, !category.isEmpty {
                        Text("•")
                            .foregroundStyle(Color.brandTextTertiary)
                        Text(category.capitalized)
                            .font(.manrope(size: 11, weight: .medium))
                            .foregroundStyle(CategoryData.color(for: category))
                    }
                }
            }
            
            Spacer()
            
            // Amount (formatted as negative like reference)
            Text("-" + formatCurrency(receipt.total_amount))
                .font(.ibmPlexMono(size: 15))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(Color.brandTextPrimary)
        }
        .padding(.vertical, 8)
    }
    
    private var formattedDate: String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(receipt.purchase_date) {
            return "Today, " + AppFormatters.timeOnly.string(from: receipt.purchase_date)
        } else if calendar.isDateInYesterday(receipt.purchase_date) {
            return "Yesterday"
        } else {
            return AppFormatters.monthDay.string(from: receipt.purchase_date)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        let formatter = AppFormatters.currency(code: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Discovery Banner

private struct DiscoveryBanner: View {
    let icon: String
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.brandVibrantBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.manrope(size: 14, weight: .bold))
                    .foregroundColor(.brandTextPrimary)
                Text(message)
                    .font(.manrope(size: 12, weight: .regular))
                    .foregroundColor(.brandTextSecondary)
            }
            Spacer()
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.brandTextTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandVibrantBlue.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandVibrantBlue.opacity(0.15), lineWidth: 1)
                )
        )
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
        .animation(.brandSnappy, value: true)
    }
}

// MARK: - Preview

#Preview {
    DashboardView(showSettings: .constant(false))
}
