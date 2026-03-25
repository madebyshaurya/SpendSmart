import SwiftUI
import SwiftUICharts

/// Interactive spending line chart using SwiftUICharts
/// Features: Drag to see values, tap points to navigate, animated entry
struct SpendingLineChart: View {
    let data: [SpendingDataPoint]
    var onPointTapped: ((SpendingDataPoint) -> Void)? = nil
    var showGradient: Bool = true
    var chartHeight: CGFloat = 200
    var animate: Bool = true
    
    @State private var selectedIndex: Int? = nil
    @State private var isAnimated = false
    @StateObject private var haptics = HapticManager.shared
    
    private var chartData: [Double] {
        data.map { isAnimated ? $0.amount : 0 }
    }
    
    private var selectedPoint: SpendingDataPoint? {
        guard let index = selectedIndex, index >= 0, index < data.count else { return nil }
        return data[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected value display
            if let selected = selectedPoint {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected.formattedDate)
                        .font(.manrope(size: 13))
                        .foregroundStyle(Color.brandTextSecondary)
                    Text(CurrencyService.shared.formatAmount(selected.amount, currency: CurrencyService.shared.preferredCurrency))
                        .font(.ibmPlexMono(size: 24))
                        .foregroundStyle(Color.brandTextPrimary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Chart using SpendSmartSparkline with interactive overlay
            ZStack {
                // Background gradient area
                if showGradient {
                    SpendSmartSparkline(
                        data: chartData,
                        color: Color.brandVibrantBlue,
                        showGradient: true,
                        height: chartHeight
                    )
                } else {
                    SpendSmartSparkline(
                        data: chartData,
                        color: Color.brandVibrantBlue,
                        showGradient: false,
                        height: chartHeight
                    )
                }
                
                // Interactive overlay
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let index = Int((value.location.x / geometry.size.width) * CGFloat(data.count))
                                    let clampedIndex = max(0, min(data.count - 1, index))
                                    if selectedIndex != clampedIndex {
                                        selectedIndex = clampedIndex
                                        haptics.light()
                                    }
                                }
                                .onEnded { _ in
                                    // Keep selection visible for tap action
                                }
                        )
                        .onTapGesture { location in
                            let index = Int((location.x / geometry.size.width) * CGFloat(data.count))
                            let clampedIndex = max(0, min(data.count - 1, index))
                            selectedIndex = clampedIndex
                            if let point = data[safe: clampedIndex] {
                                onPointTapped?(point)
                            }
                            haptics.medium()
                        }
                }
                
                // Selection indicator dots
                if let index = selectedIndex {
                    GeometryReader { geometry in
                        let stepX = geometry.size.width / CGFloat(max(1, data.count - 1))
                        let x = CGFloat(index) * stepX
                        let maxValue = data.map { $0.amount }.max() ?? 1
                        let minValue = data.map { $0.amount }.min() ?? 0
                        let range = maxValue - minValue
                        let normalizedY = range > 0 ? (data[index].amount - minValue) / range : 0.5
                        let y = geometry.size.height * (1 - CGFloat(normalizedY))
                        
                        Circle()
                            .fill(Color.brandVibrantBlue)
                            .frame(width: 10, height: 10)
                            .position(x: x, y: y)
                            .shadow(color: Color.brandVibrantBlue.opacity(0.4), radius: 4)
                    }
                }
            }
            .frame(height: chartHeight)
            
            // X-axis labels
            HStack {
                if let first = data.first {
                    Text(formatXAxisLabel(first.date))
                        .font(.manrope(size: 10))
                        .foregroundStyle(Color.brandTextTertiary)
                }
                Spacer()
                if data.count > 2 {
                    Text(formatXAxisLabel(data[data.count / 2].date))
                        .font(.manrope(size: 10))
                        .foregroundStyle(Color.brandTextTertiary)
                }
                Spacer()
                if let last = data.last {
                    Text(formatXAxisLabel(last.date))
                        .font(.manrope(size: 10))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                    isAnimated = true
                }
            } else {
                isAnimated = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private static let xAxisWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = .current
        return formatter
    }()

    private static let xAxisMonthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = .current
        return formatter
    }()

    private static let xAxisMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = .current
        return formatter
    }()
    
    private func formatXAxisLabel(_ date: Date) -> String {
        guard let first = data.first?.date, let last = data.last?.date else {
            return Self.xAxisMonthDayFormatter.string(from: date)
        }
        
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        
        if days <= 7 {
            return Self.xAxisWeekdayFormatter.string(from: date)
        } else if days <= 31 {
            return Self.xAxisMonthDayFormatter.string(from: date)
        } else {
            return Self.xAxisMonthFormatter.string(from: date)
        }
    }
}

// MARK: - Safe Array Access Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

/// Data point for spending chart
struct SpendingDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    var receipts: [Receipt] = []
    
    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.locale = .current
        return formatter
    }()

    var formattedDate: String {
        Self.fullDateFormatter.string(from: date)
    }
}

// MARK: - Mini Sparkline Chart (for compact displays)

struct SparklineChart: View {
    let data: [Double]
    var color: Color = .brandVibrantBlue
    var lineWidth: CGFloat = 2
    var showGradient: Bool = true
    
    var body: some View {
        SpendSmartSparkline(
            data: data,
            color: color,
            showGradient: showGradient,
            height: 40
        )
    }
}

// MARK: - Comparison Chart (current vs previous period)

struct ComparisonLineChart: View {
    let currentData: [SpendingDataPoint]
    let previousData: [SpendingDataPoint]
    var chartHeight: CGFloat = 200
    
    @State private var showPrevious = true
    @State private var isAnimated = false
    
    private var currentAmounts: [Double] {
        currentData.map { isAnimated ? $0.amount : 0 }
    }
    
    private var previousAmounts: [Double] {
        previousData.map { isAnimated ? $0.amount : 0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.brandVibrantBlue)
                        .frame(width: 8, height: 8)
                    Text("Current")
                        .font(.manrope(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                }
                
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showPrevious.toggle()
                    }
                    HapticManager.shared.light()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(showPrevious ? Color.brandTextTertiary : Color.brandTextTertiary.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text("Previous")
                            .font(.manrope(size: 12, weight: .medium))
                            .foregroundStyle(showPrevious ? Color.brandTextSecondary : Color.brandTextTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Dual sparklines
            ZStack {
                // Current period line
                SpendSmartSparkline(
                    data: currentAmounts,
                    color: Color.brandVibrantBlue,
                    showGradient: true,
                    height: chartHeight
                )
                
                // Previous period line (dashed effect via opacity)
                if showPrevious {
                    SpendSmartSparkline(
                        data: previousAmounts,
                        color: Color.brandTextTertiary,
                        showGradient: false,
                        height: chartHeight
                    )
                    .opacity(0.6)
                }
            }
            .frame(height: chartHeight)
            
            // X-axis labels
            HStack {
                Text("Day 1")
                    .font(.manrope(size: 10))
                    .foregroundStyle(Color.brandTextTertiary)
                Spacer()
                Text("Day \(currentData.count / 2)")
                    .font(.manrope(size: 10))
                    .foregroundStyle(Color.brandTextTertiary)
                Spacer()
                Text("Day \(currentData.count)")
                    .font(.manrope(size: 10))
                    .foregroundStyle(Color.brandTextTertiary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                isAnimated = true
            }
        }
    }
}

// MARK: - Bar Chart (for daily/weekly comparisons)

struct SpendingBarChart: View {
    let data: [SpendingDataPoint]
    var barColor: Color = .brandVibrantBlue
    var chartHeight: CGFloat = 180
    var onBarTapped: ((SpendingDataPoint) -> Void)? = nil
    
    @State private var selectedBar: SpendingDataPoint?
    @State private var animationProgress: CGFloat = 0

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = .current
        return formatter
    }()
    
    private var maxAmount: Double {
        data.map { $0.amount }.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selected = selectedBar {
                HStack {
                    Text(selected.formattedDate)
                        .font(.manrope(size: 13))
                        .foregroundStyle(Color.brandTextSecondary)
                    Spacer()
                    Text(CurrencyService.shared.formatAmount(selected.amount, currency: CurrencyService.shared.preferredCurrency))
                        .font(.ibmPlexMono(size: 16))
                        .foregroundStyle(Color.brandTextPrimary)
                }
                .padding(.horizontal, 4)
            }
            
            // Custom bar chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                selectedBar?.id == point.id ?
                                barColor :
                                barColor.opacity(0.7)
                            )
                            .frame(
                                height: max(4, (chartHeight - 24) * CGFloat(point.amount / maxAmount) * animationProgress)
                            )
                        
                        // Day label
                        Text(formatDayLabel(point.date))
                            .font(.manrope(size: 10))
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedBar = point
                        onBarTapped?(point)
                        HapticManager.shared.medium()
                    }
                }
            }
            .frame(height: chartHeight)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func formatDayLabel(_ date: Date) -> String {
        Self.dayLabelFormatter.string(from: date)
    }
}

// MARK: - Previews

#Preview("Line Chart") {
    let sampleData: [SpendingDataPoint] = {
        let calendar = Calendar.current
        var points: [SpendingDataPoint] = []
        for i in 0..<14 {
            if let date = calendar.date(byAdding: .day, value: -13 + i, to: Date()) {
                points.append(SpendingDataPoint(date: date, amount: Double.random(in: 20...150)))
            }
        }
        return points
    }()
    
    SpendingLineChart(data: sampleData)
        .padding()
}

#Preview("Bar Chart") {
    let sampleData: [SpendingDataPoint] = {
        let calendar = Calendar.current
        var points: [SpendingDataPoint] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -6 + i, to: Date()) {
                points.append(SpendingDataPoint(date: date, amount: Double.random(in: 30...200)))
            }
        }
        return points
    }()
    
    SpendingBarChart(data: sampleData)
        .padding()
}

#Preview("Sparkline") {
    SparklineChart(data: [10, 25, 18, 35, 28, 42, 38, 55, 48])
        .frame(width: 100, height: 40)
        .padding()
}
