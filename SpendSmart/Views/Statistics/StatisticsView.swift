//
//  StatisticsView.swift
//  SpendSmart
//
//  Comprehensive statistics dashboard with spending analytics.
//  Features: Spending trends, category breakdown, store analysis, time patterns, and more.
//

import SwiftUI
import SwiftUICharts

// MARK: - Statistics View

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @StateObject private var haptics = HapticManager.shared
    
    @State private var selectedTimeRange: StatisticsTimeRange = .month
    @State private var selectedTab: StatisticsTab = .overview
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time range picker
                    timeRangePicker
                    
                    // Tab selector
                    tabSelector
                    
                    // Content based on selected tab
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .categories:
                        categoriesContent
                    case .stores:
                        storesContent
                    case .trends:
                        trendsContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(Color.brandBackground)
            // .scrollEdgeEffectStyle requires iOS 26
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            viewModel.loadData(for: selectedTimeRange)
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            viewModel.loadData(for: newRange)
        }
    }
    
    // MARK: - Time Range Picker
    
    private var timeRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatisticsTimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedTimeRange = range
                        }
                        haptics.selection()
                    } label: {
                        Text(range.title)
                            .font(.manrope(size: 14, weight: selectedTimeRange == range ? .semibold : .medium))
                            .foregroundStyle(selectedTimeRange == range ? .white : Color.brandTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedTimeRange == range ? Color.brandVibrantBlue : Color.brandSurface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(StatisticsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = tab
                    }
                    haptics.light()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(tab.title)
                            .font(.manrope(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.brandVibrantBlue : Color.brandTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ?
                            Color.brandVibrantBlue.opacity(0.1) :
                            Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.brandSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: 20) {
            // Summary cards
            summaryCardsSection
            
            // Spending trend chart
            statisticsCard(title: "Spending Trend", icon: "chart.line.uptrend.xyaxis") {
                if viewModel.spendingData.isEmpty {
                    emptyStateView(message: "No spending data available")
                } else {
                    SpendingLineChart(
                        data: viewModel.spendingData,
                        chartHeight: 180
                    )
                }
            }
            
            // Category breakdown
            statisticsCard(title: "Top Categories", icon: "chart.pie.fill") {
                if viewModel.categoryData.isEmpty {
                    emptyStateView(message: "No category data available")
                } else {
                    CategoryPieChart(
                        data: Array(viewModel.categoryData.prefix(5)),
                        chartSize: 160
                    )
                }
            }
        }
    }
    
    // MARK: - Categories Content
    
    private var categoriesContent: some View {
        VStack(spacing: 20) {
            // Category pie chart
            statisticsCard(title: "Category Breakdown", icon: "chart.pie") {
                if viewModel.categoryData.isEmpty {
                    emptyStateView(message: "No category data available")
                } else {
                    CategoryPieChart(
                        data: viewModel.categoryData,
                        showLegend: true,
                        chartSize: 180
                    )
                }
            }
            
            // Category bar chart
            statisticsCard(title: "Category Comparison", icon: "chart.bar.fill") {
                if viewModel.categoryData.isEmpty {
                    emptyStateView(message: "No category data available")
                } else {
                    CategoryBarChart(
                        data: viewModel.categoryData
                    )
                }
            }
        }
    }
    
    // MARK: - Stores Content
    
    private var storesContent: some View {
        VStack(spacing: 20) {
            // Top stores
            statisticsCard(title: "Top Stores", icon: "building.2.fill") {
                if viewModel.storeData.isEmpty {
                    emptyStateView(message: "No store data available")
                } else {
                    StoreBreakdownChart(
                        data: viewModel.storeData,
                        maxStores: 8
                    )
                }
            }
            
            // Store heatmap
            statisticsCard(title: "Spending Calendar", icon: "calendar") {
                if viewModel.heatmapData.isEmpty {
                    emptyStateView(message: "No calendar data available")
                } else {
                    SpendingHeatmapCalendar(
                        data: viewModel.heatmapData,
                        month: Date()
                    )
                }
            }
        }
    }
    
    // MARK: - Trends Content
    
    private var trendsContent: some View {
        VStack(spacing: 20) {
            // Period comparison
            statisticsCard(title: "Period Comparison", icon: "arrow.left.arrow.right") {
                if viewModel.spendingData.isEmpty || viewModel.previousPeriodData.isEmpty {
                    emptyStateView(message: "Not enough data for comparison")
                } else {
                    PeriodComparisonChart(
                        currentPeriod: viewModel.spendingData,
                        previousPeriod: viewModel.previousPeriodData,
                        currentLabel: selectedTimeRange.currentLabel,
                        previousLabel: selectedTimeRange.previousLabel
                    )
                }
            }
            
            // Time of day
            statisticsCard(title: "Spending by Time", icon: "clock.fill") {
                if viewModel.hourlyData.isEmpty {
                    emptyStateView(message: "No time data available")
                } else {
                    TimeOfDayChart(
                        data: viewModel.hourlyData
                    )
                }
            }
            
            // Daily stacked chart
            statisticsCard(title: "Daily Categories", icon: "chart.bar.xaxis") {
                if viewModel.stackedData.isEmpty {
                    emptyStateView(message: "No daily data available")
                } else {
                    StackedCategoryBarChart(
                        data: viewModel.stackedData
                    )
                }
            }
        }
    }
    
    // MARK: - Summary Cards
    
    private var summaryCardsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(
                title: "Total Spent",
                value: viewModel.formattedTotalSpent,
                icon: "dollarsign.circle.fill",
                color: .brandVibrantBlue
            )
            
            summaryCard(
                title: "Receipts",
                value: "\(viewModel.receiptCount)",
                icon: "doc.text.fill",
                color: .brandRoyalBlue
            )
            
            summaryCard(
                title: "Avg per Day",
                value: viewModel.formattedDailyAverage,
                icon: "chart.bar.fill",
                color: .chartBlue3
            )
            
            summaryCard(
                title: "Top Category",
                value: viewModel.topCategory,
                icon: "tag.fill",
                color: .chartBlue4
            )
        }
    }
    
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.ibmPlexMono(size: 20))
                .foregroundStyle(Color.brandTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.manrope(size: 12, weight: .medium))
                .foregroundStyle(Color.brandTextSecondary)
        }
        .padding(16)
        .background(Color.brandSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Statistics Card
    
    private func statisticsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandVibrantBlue)
                
                Text(title)
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Spacer()
            }
            
            content()
        }
        .padding(20)
        .background(Color.brandSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.brandTextTertiary)
            
            Text(message)
                .font(.manrope(size: 14))
                .foregroundStyle(Color.brandTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview

#Preview {
    StatisticsView()
}
