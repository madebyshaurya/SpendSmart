import SwiftUI

// MARK: - Supporting Types

enum StatisticsTimeRange: String, CaseIterable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    
    var title: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .quarter: return "3 Months"
        case .year: return "This Year"
        }
    }
    
    var currentLabel: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .quarter: return "This Quarter"
        case .year: return "This Year"
        }
    }
    
    var previousLabel: String {
        switch self {
        case .week: return "Last Week"
        case .month: return "Last Month"
        case .quarter: return "Last Quarter"
        case .year: return "Last Year"
        }
    }
}

enum StatisticsTab: String, CaseIterable {
    case overview = "overview"
    case categories = "categories"
    case stores = "stores"
    case trends = "trends"
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .categories: return "Categories"
        case .stores: return "Stores"
        case .trends: return "Trends"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .categories: return "chart.pie"
        case .stores: return "building.2"
        case .trends: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Statistics View Model

@MainActor
class StatisticsViewModel: ObservableObject {
    @Published var spendingData: [SpendingDataPoint] = []
    @Published var previousPeriodData: [SpendingDataPoint] = []
    @Published var categoryData: [CategoryData] = []
    @Published var storeData: [StoreSpendingData] = []
    @Published var heatmapData: [HeatmapData] = []
    @Published var hourlyData: [HourlySpendingData] = []
    @Published var stackedData: [StackedBarData] = []
    
    @Published var totalSpent: Double = 0
    @Published var receiptCount: Int = 0
    @Published var dailyAverage: Double = 0
    @Published var topCategory: String = "-"
    
    var formattedTotalSpent: String {
        CurrencyService.shared.formatAmount(totalSpent, currency: CurrencyService.shared.preferredCurrency)
    }
    
    var formattedDailyAverage: String {
        CurrencyService.shared.formatAmount(dailyAverage, currency: CurrencyService.shared.preferredCurrency)
    }
    
    func loadData(for timeRange: StatisticsTimeRange) {
        spendingData = []
        previousPeriodData = []
        categoryData = []
        storeData = []
        heatmapData = []
        hourlyData = []
        stackedData = []
        totalSpent = 0
        receiptCount = 0
        dailyAverage = 0
        topCategory = "-"
    }
}
