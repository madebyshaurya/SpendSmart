import SwiftUI

// MARK: - Spending Analytics Section

struct SpendingAnalyticsSection: View {
    let selectedRange: TimeRange
    let spendingData: [SpendingDataPoint]
    let weekdayData: [WeekdaySpending]
    @Binding var selectedWeekday: WeekdaySpending?
    var onReceiptsTapped: (([Receipt]) -> Void)? = nil

    private var analyticsTimeLabel: String {
        selectedRange.rawValue
    }
    
    private var selectedDateDisplay: String? {
        guard let selected = selectedWeekday else { return nil }
        let calendar = Calendar.current
        let now = Date()
        
        // For weekly view, show the actual day name
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMM d"
        
        // Calculate the date for this weekday in the current week
        if let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
           let dayDate = calendar.date(byAdding: .day, value: selected.weekdayIndex - 1, to: weekStart) {
            return dayFormatter.string(from: dayDate)
        }
        return selected.label
    }
    
    private var selectedAmount: Double? {
        selectedWeekday?.totalAmount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Spending Analytics")
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)

                Spacer()

                Text(analyticsTimeLabel)
                    .font(.manrope(size: 12, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.brandSurface)
                    )
            }
            
            // Selected value display
            if let dateStr = selectedDateDisplay, let amount = selectedAmount {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateStr)
                        .font(.manrope(size: 13))
                        .foregroundStyle(Color.brandTextSecondary)
                    Text(CurrencyService.shared.formatAmount(amount, currency: CurrencyService.shared.preferredCurrency))
                        .font(.ibmPlexMono(size: 24))
                        .foregroundStyle(Color.brandTextPrimary)
                        .contentTransition(.numericText())
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Chart based on selected range
            switch selectedRange {
            case .today:
                TodaySpendingView(
                    spendingData: spendingData,
                    onTap: { receipts in
                        onReceiptsTapped?(receipts)
                    }
                )
                
            case .week:
                WeeklySpendingChart(
                    data: weekdayData,
                    selectedDay: $selectedWeekday
                )
                .frame(height: 160)
                
            case .month:
                MonthlySpendingChart(
                    spendingData: spendingData,
                    onMonthTapped: { receipts in
                        onReceiptsTapped?(receipts)
                    }
                )
                .frame(height: 160)
                
            case .threeMonths:
                MonthlySpendingChart(
                    spendingData: spendingData,
                    onMonthTapped: { receipts in
                        onReceiptsTapped?(receipts)
                    }
                )
                .frame(height: 160)

            case .year:
                YearlySpendingChart(
                    spendingData: spendingData,
                    onMonthTapped: { receipts in
                        onReceiptsTapped?(receipts)
                    }
                )
                .frame(height: 160)

            case .allTime:
                AllTimeSpendingChart(
                    spendingData: spendingData,
                    onPeriodTapped: { receipts in
                        onReceiptsTapped?(receipts)
                    }
                )
                .frame(height: 160)
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
}

// MARK: - Today Spending View

private struct TodaySpendingView: View {
    let spendingData: [SpendingDataPoint]
    var onTap: (([Receipt]) -> Void)? = nil
    
    private var todayData: SpendingDataPoint? {
        let today = Calendar.current.startOfDay(for: Date())
        return spendingData.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if let today = todayData {
                // Today's total
                VStack(spacing: 8) {
                    Text("Today's Spending")
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                    
                    Text(CurrencyService.shared.formatAmount(today.amount, currency: CurrencyService.shared.preferredCurrency))
                        .font(.ibmPlexMono(size: 36))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    if !today.receipts.isEmpty {
                        Button {
                            onTap?(today.receipts)
                            HapticManager.shared.medium()
                        } label: {
                            Text("\(today.receipts.count) receipt\(today.receipts.count == 1 ? "" : "s")")
                                .font(.manrope(size: 13, weight: .medium))
                                .foregroundStyle(Color.brandVibrantBlue)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // No spending today
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.brandSuccess)
                    
                    Text("No spending today")
                        .font(.manrope(size: 16, weight: .semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    Text("Keep it up!")
                        .font(.manrope(size: 13))
                        .foregroundStyle(Color.brandTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }
}

// MARK: - Monthly Spending Chart (shows days of current month)

private struct MonthlySpendingChart: View {
    let spendingData: [SpendingDataPoint]
    var onMonthTapped: (([Receipt]) -> Void)? = nil
    
    @State private var animationProgress: CGFloat = 0
    @State private var selectedBar: Int? = nil
    
    private var dailyData: [(day: Int, amount: Double, receipts: [Receipt])] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return [] }
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        var result: [(day: Int, amount: Double, receipts: [Receipt])] = []
        
        for day in 1...daysInMonth {
            if let date = calendar.date(bySetting: .day, value: day, of: monthInterval.start) {
                let dayStart = calendar.startOfDay(for: date)
                let matchingPoints = spendingData.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
                let total = matchingPoints.reduce(0) { $0 + $1.amount }
                let receipts = matchingPoints.flatMap { $0.receipts }
                result.append((day: day, amount: total, receipts: receipts))
            }
        }
        return result
    }
    
    private var maxAmount: Double {
        dailyData.map { $0.amount }.max() ?? 1
    }
    
    private var todayDay: Int {
        Calendar.current.component(.day, from: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected info
            if let selected = selectedBar, selected < dailyData.count {
                let data = dailyData[selected]
                HStack {
                    Text("Day \(data.day)")
                        .font(.manrope(size: 12))
                        .foregroundStyle(Color.brandTextSecondary)
                    Spacer()
                    Text(CurrencyService.shared.formatAmount(data.amount, currency: CurrencyService.shared.preferredCurrency))
                        .font(.ibmPlexMono(size: 14))
                        .foregroundStyle(Color.brandTextPrimary)
                }
            }
            
            // Scrollable bar chart for days
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(dailyData.enumerated()), id: \.offset) { index, data in
                        VStack(spacing: 4) {
                            // Bar
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor(for: data.day, isSelected: selectedBar == index))
                                .frame(width: 20, height: barHeight(for: data.amount))
                            
                            // Day label (show every 5 days + first and last)
                            if data.day == 1 || data.day % 5 == 0 || data.day == dailyData.count {
                                Text("\(data.day)")
                                    .font(.manrope(size: 9))
                                    .foregroundStyle(data.day == todayDay ? Color.brandTextPrimary : Color.brandTextTertiary)
                            } else {
                                Text("")
                                    .font(.manrope(size: 9))
                            }
                        }
                        .onTapGesture {
                            selectedBar = index
                            if !data.receipts.isEmpty {
                                onMonthTapped?(data.receipts)
                            }
                            HapticManager.shared.selection()
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func barHeight(for amount: Double) -> CGFloat {
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 100
        guard maxAmount > 0 else { return minHeight }
        return max(minHeight, (maxHeight * CGFloat(amount / maxAmount) * animationProgress))
    }
    
    private func barColor(for day: Int, isSelected: Bool) -> Color {
        if isSelected {
            return Color.brandVibrantBlue
        } else if day == todayDay {
            return Color.brandVibrantBlue.opacity(0.8)
        } else if day > todayDay {
            return Color.brandBorder
        } else {
            return Color.brandSkyBlue
        }
    }
}

// MARK: - Yearly Spending Chart (shows 12 months)

private struct YearlySpendingChart: View {
    let spendingData: [SpendingDataPoint]
    var onMonthTapped: (([Receipt]) -> Void)? = nil
    
    @State private var animationProgress: CGFloat = 0
    @State private var selectedMonth: Int? = nil
    
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
    
    private var monthlyData: [(month: Int, label: String, amount: Double, receipts: [Receipt])] {
        let calendar = Calendar.current
        var result: [(month: Int, label: String, amount: Double, receipts: [Receipt])] = []
        
        for month in 1...12 {
            var components = DateComponents()
            components.year = calendar.component(.year, from: Date())
            components.month = month
            components.day = 1
            
            guard let monthDate = calendar.date(from: components),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else { continue }
            
            let monthPoints = spendingData.filter { $0.date >= monthInterval.start && $0.date < monthInterval.end }
            let total = monthPoints.reduce(0) { $0 + $1.amount }
            let receipts = monthPoints.flatMap { $0.receipts }
            let label = Self.monthFormatter.string(from: monthDate)
            
            result.append((month: month, label: label, amount: total, receipts: receipts))
        }
        return result
    }
    
    private var maxAmount: Double {
        monthlyData.map { $0.amount }.max() ?? 1
    }
    
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected info
            if let selected = selectedMonth, let data = monthlyData.first(where: { $0.month == selected }) {
                HStack {
                    Text(data.label)
                        .font(.manrope(size: 12))
                        .foregroundStyle(Color.brandTextSecondary)
                    Spacer()
                    Text(CurrencyService.shared.formatAmount(data.amount, currency: CurrencyService.shared.preferredCurrency))
                        .font(.ibmPlexMono(size: 14))
                        .foregroundStyle(Color.brandTextPrimary)
                }
            }
            
            // Bar chart for months
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(monthlyData, id: \.month) { data in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(monthBarColor(for: data.month, isSelected: selectedMonth == data.month))
                            .frame(height: barHeight(for: data.amount))
                        
                        // Month label
                        Text(data.label)
                            .font(.manrope(size: 10, weight: data.month == currentMonth ? .bold : .regular))
                            .foregroundStyle(data.month == currentMonth ? Color.brandTextPrimary : Color.brandTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        selectedMonth = data.month
                        if !data.receipts.isEmpty {
                            onMonthTapped?(data.receipts)
                        }
                        HapticManager.shared.selection()
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func barHeight(for amount: Double) -> CGFloat {
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 110
        guard maxAmount > 0 else { return minHeight }
        return max(minHeight, (maxHeight * CGFloat(amount / maxAmount) * animationProgress))
    }
    
    private func monthBarColor(for month: Int, isSelected: Bool) -> Color {
        if isSelected {
            return Color.brandVibrantBlue
        } else if month == currentMonth {
            return Color.brandVibrantBlue.opacity(0.8)
        } else if month > currentMonth {
            return Color.brandBorder
        } else {
            return Color.brandSkyBlue
        }
    }
}

// MARK: - All Time Spending Chart

private struct AllTimeSpendingChart: View {
    let spendingData: [SpendingDataPoint]
    var onPeriodTapped: (([Receipt]) -> Void)? = nil
    
    @State private var animationProgress: CGFloat = 0
    
    private var totalAmount: Double {
        spendingData.reduce(0) { $0 + $1.amount }
    }
    
    private var totalReceipts: [Receipt] {
        spendingData.flatMap { $0.receipts }
    }
    
    private var dateRange: String {
        guard let first = spendingData.first?.date, let last = spendingData.last?.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Total Spending")
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
                
                Text(CurrencyService.shared.formatAmount(totalAmount, currency: CurrencyService.shared.preferredCurrency))
                    .font(.ibmPlexMono(size: 36))
                    .foregroundStyle(Color.brandTextPrimary)
                
                if !dateRange.isEmpty {
                    Text(dateRange)
                        .font(.manrope(size: 12))
                        .foregroundStyle(Color.brandTextTertiary)
                }
                
                if !totalReceipts.isEmpty {
                    Button {
                        onPeriodTapped?(totalReceipts)
                        HapticManager.shared.medium()
                    } label: {
                        Text("\(totalReceipts.count) receipts total")
                            .font(.manrope(size: 13, weight: .medium))
                            .foregroundStyle(Color.brandVibrantBlue)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Weekly Spending Chart (moved from DashboardView)

struct WeeklySpendingChart: View {
    let data: [WeekdaySpending]
    @Binding var selectedDay: WeekdaySpending?
    
    @State private var animatedValues: [Int: Double] = [:]
    @State private var hasAnimated = false
    
    private var maxAmount: Double {
        data.map { $0.totalAmount }.max() ?? 1
    }
    
    private var todayWeekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(data) { item in
                VStack(spacing: 8) {
                    // Bar
                    RoundedRectangle(cornerRadius: 8)
                        .fill(barGradient(for: item))
                        .frame(width: 36, height: barHeight(for: item))
                        .overlay(alignment: .top) {
                            // Dot indicator for today
                            if item.weekdayIndex == todayWeekday {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 6, height: 6)
                                    .offset(y: 6)
                            }
                        }
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) {
                                selectedDay = item
                            }
                            HapticManager.shared.selection()
                        }
                    
                    // Day label
                    Text(item.label)
                        .font(.manrope(size: 12, weight: item.weekdayIndex == todayWeekday ? .bold : .medium))
                        .foregroundStyle(item.weekdayIndex == todayWeekday ? Color.brandTextPrimary : Color.brandTextTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            
            // Animate bars sequentially
            for (index, item) in data.enumerated() {
                withAnimation(.spring(duration: 0.5).delay(Double(index) * 0.05)) {
                    animatedValues[item.weekdayIndex] = item.totalAmount
                }
            }
        }
    }
    
    private func barHeight(for item: WeekdaySpending) -> CGFloat {
        let value = animatedValues[item.weekdayIndex] ?? 0
        let minHeight: CGFloat = 20
        let maxHeight: CGFloat = 120
        
        guard maxAmount > 0 else { return minHeight }
        
        let normalizedHeight = CGFloat(value / maxAmount) * maxHeight
        return max(normalizedHeight, minHeight)
    }
    
    private func barGradient(for item: WeekdaySpending) -> LinearGradient {
        let isToday = item.weekdayIndex == todayWeekday
        let isSelected = selectedDay?.weekdayIndex == item.weekdayIndex
        
        if isToday || isSelected {
            return LinearGradient(
                colors: [Color.brandVibrantBlue, Color.brandSkyBlue],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color.brandSkyBlue.opacity(0.6), Color.brandSkyBlue.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
