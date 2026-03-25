import SwiftUI
import Charts
import MapKit

// MARK: - Dashboard View Model

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var recentReceipts: [Receipt] = []
    @Published var allReceipts: [Receipt] = []
    @Published var totalSpent: Double = 0.0
    @Published var percentageChange: Double? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedRange: TimeRange = .month {
        didSet {
            if oldValue != selectedRange {
                Task { await loadDashboardData() }
            }
        }
    }
    
    // Chart data
    @Published var spendingChartData: [SpendingDataPoint] = []
    @Published var categoryData: [CategoryData] = []
    @Published var topStores: [StoreSpending] = []
    @Published var totalSavings: Double = 0.0
    @Published var previousPeriodData: [SpendingDataPoint] = []
    @Published var taxChartData: [SpendingDataPoint] = []
    @Published var weekdayData: [WeekdaySpending] = []
    @Published var currencyData: [CurrencyUsage] = []
    @Published var paymentMethodData: [PaymentMethodUsage] = []
    
    // Enhanced chart data
    @Published var storeBreakdownData: [StoreSpendingData] = []
    @Published var stackedCategoryData: [StackedBarData] = []
    @Published var heatmapData: [HeatmapData] = []
    @Published var hourlySpendingData: [HourlySpendingData] = []

    @Published var aiInsight: AIInsightData?
    @Published var isLoadingInsight: Bool = false
    
    private let supabase = SupabaseManager.shared
    private let subscriptionManager = SubscriptionManager.shared
    
    /// Optional prefetched receipts from AppState to avoid redundant network calls
    var prefetchedReceipts: [Receipt]?
    
    /// Determines the best default time range based on available receipt data
    /// Priority: This Week → This Month → This Year → All Time
    func determineSmartDefaultRange(from receipts: [Receipt]) -> TimeRange {
        let calendar = Calendar.current
        let now = Date()
        
        // Check this week
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let thisWeekReceipts = receipts.filter { $0.purchase_date >= weekStart }
        if !thisWeekReceipts.isEmpty {
            return .week
        }
        
        // Check this month  
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let thisMonthReceipts = receipts.filter { $0.purchase_date >= monthStart }
        if !thisMonthReceipts.isEmpty {
            return .month
        }
        
        // Check this year
        let yearStart = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let thisYearReceipts = receipts.filter { $0.purchase_date >= yearStart }
        if !thisYearReceipts.isEmpty {
            return .year
        }
        
        // Fall back to all time if there's any data
        if !receipts.isEmpty {
            return .allTime
        }
        
        // Default to month if no data
        return .month
    }

    /// Track if this is the initial load (for smart default selection)
    private var isInitialLoad: Bool = true
    private var hasLoadedAIInsight: Bool = false

    struct AIInsightData {
        let topCategory: String
        let topCategoryAmount: Double
        let topCategoryPercentage: Double
        let insight: String
        let comparisonNote: String
    }

    func loadDashboardData() async {
        isLoading = true
        errorMessage = nil
        hasLoadedAIInsight = false
        aiInsight = nil
        
        do {
            let calendar = Calendar.current
            let now = Date()
            
            // Fetch all receipts first (we need them for smart default)
            var receipts: [Receipt] = []
            
            // Use prefetched receipts if available (faster initial load)
            if let prefetched = prefetchedReceipts {
                receipts = prefetched
                prefetchedReceipts = nil // Clear after use to ensure fresh data on refresh
            } else if subscriptionManager.hasCloudWriteAccess {
                receipts = try await supabase.fetchReceipts()
            } else {
                receipts = LocalReceiptStorage.shared.getAllReceipts()
            }
            
            // On initial load, determine the smart default range based on data
            if isInitialLoad && !receipts.isEmpty {
                isInitialLoad = false
                let smartRange = determineSmartDefaultRange(from: receipts)
                if smartRange != selectedRange {
                    await MainActor.run {
                        // Update without triggering reload (we'll process below)
                        self.selectedRange = smartRange
                    }
                }
            }
            
            // Get date range
            let (startDate, endDate) = getDateRange(for: selectedRange, calendar: calendar, now: now)
            
            // Filter by date range
            let filteredReceipts = receipts.filter { receipt in
                if selectedRange == .allTime { return true }
                return receipt.purchase_date >= startDate && receipt.purchase_date <= endDate
            }
            
            // Calculate totals (normalized to preferred currency)
            var total = 0.0
            var savings = 0.0
            
            // Get user's preferred currency
            let targetCurrency = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
            let currencyService = CurrencyService.shared
            
            var weekdayTotals: [Int: Double] = [:]
            var weekdayCounts: [Int: Int] = [:]
            var currencyCounts: [String: Int] = [:]
            var currencyTotals: [String: Double] = [:]
            var paymentCounts: [String: Int] = [:]
            var convertedDailyTotals: [Date: Double] = [:]
            var convertedDailyTaxTotals: [Date: Double] = [:]
            var storeAggregates: [String: (total: Double, count: Int, receipts: [Receipt])] = [:]
            
            // Enhanced chart data aggregates
            var hourlyTotals: [Int: Double] = [:]
            var hourlyCounts: [Int: Int] = [:]
            var dailyCategoryTotals: [Date: [String: Double]] = [:]
            var dailyReceiptCounts: [Date: Int] = [:]

            for receipt in filteredReceipts {
                // Convert total amount
                let convertedAmount = await currencyService.convert(
                    receipt.total_amount,
                    from: receipt.currency,
                    to: targetCurrency
                )
                total += convertedAmount

                let weekday = calendar.component(.weekday, from: receipt.purchase_date)
                weekdayTotals[weekday, default: 0] += convertedAmount
                weekdayCounts[weekday, default: 0] += 1

                let day = calendar.startOfDay(for: receipt.purchase_date)
                convertedDailyTotals[day, default: 0] += convertedAmount

                let currency = receipt.currency.isEmpty ? targetCurrency : receipt.currency
                currencyCounts[currency, default: 0] += 1
                currencyTotals[currency, default: 0] += receipt.total_amount

                let paymentMethod = receipt.payment_method.trimmingCharacters(in: .whitespacesAndNewlines)
                let paymentKey = paymentMethod.isEmpty ? "Card" : paymentMethod
                paymentCounts[paymentKey, default: 0] += 1

                let store = receipt.store_name.isEmpty ? "Unknown" : receipt.store_name
                var storeEntry = storeAggregates[store] ?? (0, 0, [])
                storeEntry.total += convertedAmount
                storeEntry.count += 1
                storeEntry.receipts.append(receipt)
                storeAggregates[store] = storeEntry
                
                // Convert savings
                if receipt.savings > 0 {
                    let convertedSavings = await currencyService.convert(
                        receipt.savings,
                        from: receipt.currency,
                        to: targetCurrency
                    )
                    savings += convertedSavings
                }

                if receipt.total_tax > 0 {
                    let convertedTax = await currencyService.convert(
                        receipt.total_tax,
                        from: receipt.currency,
                        to: targetCurrency
                    )
                    convertedDailyTaxTotals[day, default: 0] += convertedTax
                }
                
                // Enhanced chart data collection
                let hour = calendar.component(.hour, from: receipt.purchase_date)
                hourlyTotals[hour, default: 0] += convertedAmount
                hourlyCounts[hour, default: 0] += 1
                
                dailyReceiptCounts[day, default: 0] += 1
                
                // Collect category data per day for stacked chart
                for item in receipt.items {
                    let category = item.category.isEmpty ? "Other" : item.category
                    var dayCats = dailyCategoryTotals[day] ?? [:]
                    dayCats[category, default: 0] += item.price
                    dailyCategoryTotals[day] = dayCats
                }
            }
            
            // Get previous period for comparison
            let previousTotal = await calculatePreviousPeriodTotal(
                receipts: receipts,
                currentRange: selectedRange,
                calendar: calendar,
                now: now,
                targetCurrency: targetCurrency
            )
            
            // Generate chart data
            let chartData = generateSpendingChartData(
                receipts: filteredReceipts,
                startDate: startDate,
                endDate: endDate,
                calendar: calendar,
                dailyTotalsOverride: convertedDailyTotals
            )

            let taxChartData = generateSpendingChartData(
                receipts: filteredReceipts,
                startDate: startDate,
                endDate: endDate,
                calendar: calendar,
                dailyTotalsOverride: convertedDailyTaxTotals
            )
            
            // Generate category breakdown
            let categories = generateCategoryData(from: filteredReceipts)
            
            let stores = storeAggregates.map { name, data in
                StoreSpending(name: name, totalSpent: data.total, visitCount: data.count, receipts: data.receipts)
            }.sorted(by: { $0.totalSpent > $1.totalSpent })
            
            let weekdayData = WeekdaySpending.makeWeek(weekdayTotals: weekdayTotals, weekdayCounts: weekdayCounts)
            let currencyData = currencyCounts.map { code, count in
                CurrencyUsage(code: code, count: count, total: currencyTotals[code] ?? 0)
            }.sorted(by: { $0.count > $1.count })
            let paymentMethodData = paymentCounts.map { method, count in
                PaymentMethodUsage(method: method, count: count)
            }.sorted(by: { $0.count > $1.count })
            
            // Generate enhanced chart data
            let storeBreakdownData = storeAggregates.map { name, data in
                StoreSpendingData(name: name, amount: data.total, visitCount: data.count, receipts: data.receipts)
            }.sorted(by: { $0.amount > $1.amount })
            
            let stackedCategoryData = dailyCategoryTotals.map { date, categories in
                let categoryAmounts = categories.map { CategoryAmount(category: $0.key, amount: $0.value) }
                return StackedBarData(date: date, categories: categoryAmounts.sorted(by: { $0.amount > $1.amount }))
            }.sorted(by: { $0.date < $1.date })
            
            let heatmapData = convertedDailyTotals.map { date, amount in
                HeatmapData(date: date, amount: amount, receiptCount: dailyReceiptCounts[date] ?? 0)
            }.sorted(by: { $0.date < $1.date })
            
            let hourlySpendingData = (0..<24).map { hour in
                HourlySpendingData(hour: hour, amount: hourlyTotals[hour] ?? 0, transactionCount: hourlyCounts[hour] ?? 0)
            }

            await MainActor.run {
                self.allReceipts = receipts
                self.recentReceipts = Array(filteredReceipts.sorted(by: { $0.purchase_date > $1.purchase_date }).prefix(5))
                self.totalSpent = total
                self.totalSavings = savings
                self.spendingChartData = chartData
                self.taxChartData = taxChartData
                self.categoryData = categories
                self.topStores = stores
                self.weekdayData = weekdayData
                self.currencyData = currencyData
                self.paymentMethodData = paymentMethodData
                
                // Enhanced chart data
                self.storeBreakdownData = storeBreakdownData
                self.stackedCategoryData = stackedCategoryData
                self.heatmapData = heatmapData
                self.hourlySpendingData = hourlySpendingData
                
                // Calculate percentage change
                if previousTotal > 0 {
                    self.percentageChange = ((total - previousTotal) / previousTotal) * 100
                } else {
                    self.percentageChange = nil
                }
                
                self.isLoading = false
            }

            await loadAIInsight()
            
        } catch {
            print("Dashboard Load Error: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func getDateRange(for range: TimeRange, calendar: Calendar, now: Date) -> (Date, Date) {
        switch range {
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .month:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (start, now)
        case .threeMonths:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (start, now)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (start, now)
        case .allTime:
            return (Date.distantPast, now)
        }
    }
    
    private func calculatePreviousPeriodTotal(receipts: [Receipt], currentRange: TimeRange, calendar: Calendar, now: Date, targetCurrency: String) async -> Double {
        guard currentRange != .allTime else { return 0 }
        
        let (currentStart, _) = getDateRange(for: currentRange, calendar: calendar, now: now)
        
        var prevStart: Date
        var prevEnd: Date
        
        switch currentRange {
        case .today:
            prevEnd = calendar.startOfDay(for: now).addingTimeInterval(-1)
            prevStart = calendar.startOfDay(for: prevEnd)
        case .week:
            prevEnd = calendar.date(byAdding: .day, value: -7, to: now)!.addingTimeInterval(-1)
            prevStart = calendar.date(byAdding: .day, value: -7, to: prevEnd)!
        case .month:
            if let prevMonthDate = calendar.date(byAdding: .month, value: -1, to: currentStart),
               let interval = calendar.dateInterval(of: .month, for: prevMonthDate) {
                prevStart = interval.start
                prevEnd = interval.end
            } else {
                return 0
            }
        case .threeMonths:
            prevEnd = calendar.date(byAdding: .month, value: -3, to: now)!.addingTimeInterval(-1)
            prevStart = calendar.date(byAdding: .month, value: -3, to: prevEnd)!
        case .year:
            prevEnd = calendar.date(byAdding: .year, value: -1, to: now)!.addingTimeInterval(-1)
            prevStart = calendar.date(byAdding: .year, value: -1, to: prevEnd)!
        case .allTime:
            return 0
        }
        
        let previousReceipts = receipts.filter { $0.purchase_date >= prevStart && $0.purchase_date <= prevEnd }
        var total = 0.0
        let currencyService = CurrencyService.shared
        
        for receipt in previousReceipts {
            total += await currencyService.convert(
                receipt.total_amount,
                from: receipt.currency,
                to: targetCurrency
            )
        }
        
        return total
    }
    
    private func generateSpendingChartData(
        receipts: [Receipt],
        startDate: Date,
        endDate: Date,
        calendar: Calendar,
        dailyTotalsOverride: [Date: Double] = [:]
    ) -> [SpendingDataPoint] {
        // For "All Time", use actual receipt date range (not distant past)
        let effectiveStartDate: Date
        if startDate == Date.distantPast {
            // Find earliest receipt date, or use 30 days ago as fallback
            if let earliest = receipts.map({ $0.purchase_date }).min() {
                effectiveStartDate = calendar.startOfDay(for: earliest)
            } else {
                effectiveStartDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            }
        } else {
            effectiveStartDate = startDate
        }
        
        // Limit chart points to prevent performance issues (max 365 days)
        let maxDays = 365
        let daysBetween = calendar.dateComponents([.day], from: effectiveStartDate, to: endDate).day ?? 0
        let actualStartDate: Date
        if daysBetween > maxDays {
            actualStartDate = calendar.date(byAdding: .day, value: -maxDays, to: endDate) ?? effectiveStartDate
        } else {
            actualStartDate = effectiveStartDate
        }
        
        // Group receipts by day
        var dailyTotals: [Date: Double] = [:]
        var dailyReceipts: [Date: [Receipt]] = [:]
        
        for receipt in receipts {
            let day = calendar.startOfDay(for: receipt.purchase_date)
            if dailyTotalsOverride.isEmpty {
                dailyTotals[day, default: 0] += receipt.total_amount
            }
            dailyReceipts[day, default: []].append(receipt)
        }

        if !dailyTotalsOverride.isEmpty {
            dailyTotals = dailyTotalsOverride
        }
        
        // Create data points for each day in range
        var points: [SpendingDataPoint] = []
        var currentDate = calendar.startOfDay(for: actualStartDate)
        let endDay = calendar.startOfDay(for: endDate)
        
        while currentDate <= endDay {
            let amount = dailyTotals[currentDate] ?? 0
            let dayReceipts = dailyReceipts[currentDate] ?? []
            points.append(SpendingDataPoint(date: currentDate, amount: amount, receipts: dayReceipts))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return points
    }
    
    private func generateCategoryData(from receipts: [Receipt]) -> [CategoryData] {
        // Group items by category
        var categoryTotals: [String: Double] = [:]
        var categoryReceipts: [String: [Receipt]] = [:]
        
        for receipt in receipts {
            for item in receipt.items {
                let category = item.category.isEmpty ? "Other" : item.category
                categoryTotals[category, default: 0] += item.price
                if !categoryReceipts[category, default: []].contains(where: { $0.id == receipt.id }) {
                    categoryReceipts[category, default: []].append(receipt)
                }
            }
        }
        
        return categoryTotals.map { category, amount in
            CategoryData(
                name: category.capitalized,
                amount: amount,
                color: CategoryData.color(for: category),
                receipts: categoryReceipts[category] ?? []
            )
        }.sorted(by: { $0.amount > $1.amount })
    }
    
    private func generateTopStores(from receipts: [Receipt]) -> [StoreSpending] {
        var storeData: [String: (total: Double, count: Int, receipts: [Receipt])] = [:]
        
        for receipt in receipts {
            let store = receipt.store_name.isEmpty ? "Unknown" : receipt.store_name
            var current = storeData[store] ?? (0, 0, [])
            current.total += receipt.total_amount
            current.count += 1
            current.receipts.append(receipt)
            storeData[store] = current
        }
        
        return storeData.map { name, data in
            StoreSpending(name: name, totalSpent: data.total, visitCount: data.count, receipts: data.receipts)
        }.sorted(by: { $0.totalSpent > $1.totalSpent })
    }

    func loadAIInsight() async {
        guard !hasLoadedAIInsight, !isLoadingInsight else { return }
        guard let topCategory = categoryData.first, totalSpent > 0 else { return }

        hasLoadedAIInsight = true
        isLoadingInsight = true
        defer { isLoadingInsight = false }

        let topCategoryPercentage = (topCategory.amount / totalSpent) * 100
        let comparisonNote = insightComparisonNote
        let prompt = """
        Analyze this spending snapshot and return one concise, practical insight.
        Top category: \(topCategory.name)
        Top category amount: \(formatCurrency(topCategory.amount))
        Top category share: \(String(format: "%.1f", topCategoryPercentage))%
        Total spent: \(formatCurrency(totalSpent))
        Comparison: \(comparisonNote)
        """

        do {
            let response = try await AIService.shared.generateContent(
                prompt: prompt,
                systemInstruction: "You are a concise financial advisor. Respond with exactly one short sentence (max 20 words) about the user's spending pattern. Be specific and helpful, not generic. No emojis.",
                config: AIService.GenerationConfig(temperature: 0.3, maxOutputTokens: 50)
            )

            guard let rawText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines), !rawText.isEmpty else {
                return
            }

            let cleanInsight = rawText
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            aiInsight = AIInsightData(
                topCategory: topCategory.name,
                topCategoryAmount: topCategory.amount,
                topCategoryPercentage: max(0, min(topCategoryPercentage, 100)),
                insight: cleanInsight,
                comparisonNote: comparisonNote
            )
        } catch {
            print("AI insight generation failed: \(error.localizedDescription)")
        }
    }

    func refreshAIInsight() async {
        hasLoadedAIInsight = false
        await loadAIInsight()
    }

    // MARK: - Map Preview

    @Published var mapPreviewLocations: [StoreLocation] = []
    @Published var mapPreviewPosition: MapCameraPosition = .automatic
    @Published var isMapPreviewLoading = false

    func loadMapPreview() async {
        guard !isMapPreviewLoading else { return }
        let receipts = allReceipts.filter { !$0.store_address.isEmpty }
        guard !receipts.isEmpty else {
            mapPreviewLocations = []
            return
        }

        isMapPreviewLoading = true
        let limited = Array(receipts.prefix(6))
        let locations = await GeocodingService.shared.geocodeStores(from: limited)
        mapPreviewLocations = locations
        if let region = GeocodingService.shared.regionForLocations(locations) {
            mapPreviewPosition = .region(region)
        }
        isMapPreviewLoading = false
    }

    // MARK: - Computed Helpers

    var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<21: return "Good evening,"
        default: return "Good night,"
        }
    }

    var userEmoji: String {
        UserDefaults.standard.string(forKey: "userEmoji") ?? "😊"
    }

    var currencySymbol: String {
        let currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        return CurrencyService.shared.getSymbol(for: currencyCode)
    }

    var comparisonText: String {
        selectedRange == .month ? "vs last month" : "vs last period"
    }

    var insightComparisonNote: String {
        guard let percentageChange else { return "vs. last period" }
        let magnitude = String(format: "%.1f", abs(percentageChange))
        if percentageChange == 0 {
            return "No change vs. last period"
        }
        return percentageChange > 0
            ? "\(magnitude)% more than last period"
            : "\(magnitude)% less than last period"
    }

    var hasAnyChartData: Bool {
        !spendingChartData.isEmpty
            || !categoryData.isEmpty
            || !weekdayData.isEmpty
            || !currencyData.isEmpty
            || !taxChartData.isEmpty
            || !storeBreakdownData.isEmpty
            || !heatmapData.isEmpty
            || !hourlySpendingData.filter({ $0.amount > 0 }).isEmpty
    }

    var averagePerReceipt: Double {
        let count = allReceipts.filter { $0.purchase_date >= startDate }.count
        return count > 0 ? totalSpent / Double(count) : 0
    }

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch selectedRange {
        case .today: return calendar.startOfDay(for: now)
        case .week: return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month: return calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .year: return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime: return Date.distantPast
        }
    }

    var welcomeName: String {
        if let stored = supabase.profile?.full_name,
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sanitizedName(from: stored)
        }
        if let email = supabase.session?.user.email, !email.isEmpty {
            return sanitizedName(from: email)
        }
        return "back"
    }

    func sanitizedName(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "back" }
        if let atIndex = trimmed.firstIndex(of: "@"), atIndex != trimmed.startIndex {
            return String(trimmed[..<atIndex])
        }
        return trimmed
    }

    func formatCurrency(_ amount: Double) -> String {
        let currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        let formatter = AppFormatters.currency(code: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    var latestReceipt: Receipt? {
        recentReceipts.first
    }

    var topPaymentMethod: PaymentMethodUsage? {
        paymentMethodData.first
    }

    var topCurrency: CurrencyUsage? {
        currencyData.first
    }
}

// MARK: - Store Spending Model

struct StoreSpending: Identifiable {
    let id = UUID()
    let name: String
    let totalSpent: Double
    let visitCount: Int
    let receipts: [Receipt]
    
    var averageSpend: Double {
        visitCount > 0 ? totalSpent / Double(visitCount) : 0
    }
}

// MARK: - Weekday Spending Model

struct WeekdaySpending: Identifiable {
    let id = UUID()
    let weekdayIndex: Int
    let totalAmount: Double
    let receiptCount: Int

    private static let shortWeekdaySymbols: [String] = {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols ?? []
    }()

    var label: String {
        guard weekdayIndex >= 1, weekdayIndex <= 7 else { return "-" }
        guard !Self.shortWeekdaySymbols.isEmpty else { return "-" }
        return Self.shortWeekdaySymbols[weekdayIndex - 1]
    }

    static func makeWeek(weekdayTotals: [Int: Double], weekdayCounts: [Int: Int]) -> [WeekdaySpending] {
        (1...7).map { index in
            WeekdaySpending(
                weekdayIndex: index,
                totalAmount: weekdayTotals[index] ?? 0,
                receiptCount: weekdayCounts[index] ?? 0
            )
        }
    }
}

struct CurrencyUsage: Identifiable {
    let id = UUID()
    let code: String
    let count: Int
    let total: Double
}

struct PaymentMethodUsage: Identifiable {
    let id = UUID()
    let method: String
    let count: Int
}

enum DashboardChart: String, CaseIterable {
    case trend = "Trend"
    case categories = "Categories"
    case weekday = "Weekday"
    case stores = "Stores"
    case heatmap = "Heatmap"
    case timeOfDay = "Time"
    case currency = "Currency"
    case tax = "Tax"
}
