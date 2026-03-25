import SwiftUI
import SwiftUICharts

// MARK: - SpendSmart Brand Chart Styles

/// Brand-styled chart configuration for SwiftUICharts (AppPear/ChartView)
/// These wrappers apply SpendSmart brand colors and provide a consistent look

// MARK: - Custom Chart Styles

/// Brand Line Chart Style - Vibrant blue gradient
enum BrandChartStyles {
    /// Line chart style with brand colors
    static var line: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandSurface,
            accentColor: Color.brandVibrantBlue,
            secondGradientColor: Color.brandSkyBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.brandDeepNavy.opacity(0.1)
        )
    }
    
    /// Bar chart style with brand colors
    static var bar: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandSurface,
            accentColor: Color.brandDeepNavy,
            secondGradientColor: Color.brandVibrantBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.brandDeepNavy.opacity(0.1)
        )
    }
    
    /// Pie chart style with brand colors
    static var pie: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandSurface,
            accentColor: Color.brandVibrantBlue,
            secondGradientColor: Color.brandSkyBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.clear
        )
    }
}

// MARK: - Gradient Colors Extension

extension GradientColor {
    /// SpendSmart primary gradient (vibrant blue to deep navy)
    static let brandPrimary = GradientColor(
        start: Color.brandVibrantBlue,
        end: Color.brandDeepNavy
    )
    
    /// SpendSmart accent gradient (sky blue to vibrant blue)
    static let brandAccent = GradientColor(
        start: Color.brandSkyBlue,
        end: Color.brandVibrantBlue
    )
    
    /// SpendSmart soft gradient (ice blue to soft blue)
    static let brandSoft = GradientColor(
        start: Color.brandIceBlue,
        end: Color.brandSoftBlue
    )
    
    /// Success gradient
    static let brandSuccess = GradientColor(
        start: Color.brandSuccess,
        end: Color.brandSuccessDark
    )
    
    /// Warning gradient
    static let brandWarning = GradientColor(
        start: Color.brandWarning,
        end: Color.brandWarningDark
    )
    
    /// Error gradient
    static let brandError = GradientColor(
        start: Color.brandError,
        end: Color.brandErrorDark
    )
}

// MARK: - SpendSmart Line Chart

/// A line chart wrapper using SwiftUICharts with SpendSmart brand styling
struct SpendSmartLineChart: View {
    let data: [Double]
    var title: String = ""
    var legend: String? = nil
    var style: ChartStyle = Styles.lineChartStyleOne
    var form: CGSize = ChartForm.large
    var dropShadow: Bool = true
    var valueSpecifier: String = "%.0f"
    var onTouch: ((Double) -> Void)? = nil
    
    @StateObject private var haptics = HapticManager.shared
    
    var body: some View {
        LineChartView(
            data: data,
            title: title,
            legend: legend,
            style: brandStyle,
            form: form,
            dropShadow: dropShadow,
            valueSpecifier: valueSpecifier
        )
        .onChange(of: data) { _, _ in
            haptics.light()
        }
    }
    
    private var brandStyle: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandSurface,
            accentColor: Color.brandVibrantBlue,
            secondGradientColor: Color.brandSkyBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.brandDeepNavy.opacity(0.15)
        )
    }
}

// MARK: - SpendSmart Bar Chart

/// A bar chart wrapper using SwiftUICharts with SpendSmart brand styling
struct SpendSmartBarChart: View {
    let data: ChartData
    var title: String = ""
    var legend: String? = nil
    var form: CGSize = ChartForm.large
    var dropShadow: Bool = true
    var cornerImage: Image? = nil
    var valueSpecifier: String = "%.0f"
    var animatedToBack: Bool = true
    var onTouch: ((Double) -> Void)? = nil
    
    @StateObject private var haptics = HapticManager.shared
    
    var body: some View {
        BarChartView(
            data: data,
            title: title,
            legend: legend,
            style: brandStyle,
            form: form,
            dropShadow: dropShadow,
            cornerImage: cornerImage ?? Image(systemName: "chart.bar.fill"),
            valueSpecifier: valueSpecifier,
            animatedToBack: animatedToBack
        )
    }
    
    private var brandStyle: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandSurface,
            accentColor: Color.brandDeepNavy,
            secondGradientColor: Color.brandVibrantBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.brandDeepNavy.opacity(0.15)
        )
    }
}

// MARK: - SpendSmart Pie Chart

/// A pie chart wrapper using SwiftUICharts with SpendSmart brand styling
struct SpendSmartPieChart: View {
    let data: [Double]
    var title: String = ""
    var legend: String? = nil
    var form: CGSize = ChartForm.medium
    var dropShadow: Bool = true
    var valueSpecifier: String = "%.0f"
    
    var body: some View {
        PieChartView(
            data: data,
            title: title,
            legend: legend,
            style: brandStyle,
            form: form,
            dropShadow: dropShadow,
            valueSpecifier: valueSpecifier
        )
    }
    
    private var brandStyle: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandSurface,
            accentColor: Color.brandVibrantBlue,
            secondGradientColor: Color.brandSkyBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.brandDeepNavy.opacity(0.15)
        )
    }
}

// MARK: - SpendSmart Multi-Line Chart

/// A multi-line chart wrapper using SwiftUICharts with SpendSmart brand styling
struct SpendSmartMultiLineChart: View {
    let data: [([Double], GradientColor)]
    var title: String = ""
    var form: CGSize = ChartForm.large
    var dropShadow: Bool = true
    var valueSpecifier: String = "%.0f"
    
    var body: some View {
        MultiLineChartView(
            data: data,
            title: title,
            style: brandStyle,
            form: form,
            dropShadow: dropShadow,
            valueSpecifier: valueSpecifier
        )
    }
    
    private var brandStyle: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandSurface,
            accentColor: Color.brandVibrantBlue,
            secondGradientColor: Color.brandSkyBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.brandDeepNavy.opacity(0.15)
        )
    }
}

// MARK: - SpendSmart Full-Screen Line View

/// A full-screen interactive line chart with touch-to-reveal values
struct SpendSmartLineView: View {
    let data: [Double]
    var title: String = ""
    var legend: String? = nil
    var valueSpecifier: String = "%.0f"
    
    @StateObject private var haptics = HapticManager.shared
    
    var body: some View {
        LineView(
            data: data,
            title: title,
            legend: legend,
            style: brandStyle,
            valueSpecifier: valueSpecifier
        )
    }
    
    private var brandStyle: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandBackground,
            accentColor: Color.brandVibrantBlue,
            secondGradientColor: Color.brandSkyBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.brandDeepNavy.opacity(0.15)
        )
    }
}

// MARK: - Chart Data Conversion Helpers

extension ChartData {
    /// Create ChartData from SpendingDataPoint array
    static func fromSpendingData(_ data: [SpendingDataPoint]) -> ChartData {
        let values = data.map { ($0.formattedDate, $0.amount) }
        return ChartData(values: values)
    }
    
    /// Create ChartData from CategoryData array
    static func fromCategoryData(_ data: [CategoryData]) -> ChartData {
        let values = data.map { ($0.name, $0.amount) }
        return ChartData(values: values)
    }
    
    /// Create ChartData from simple label-value pairs
    static func fromLabeledValues(_ values: [(String, Double)]) -> ChartData {
        return ChartData(values: values)
    }
}

// MARK: - Compact Inline Charts

/// A compact inline line chart for use in cards and lists
struct SpendSmartSparkline: View {
    let data: [Double]
    var color: Color = .brandVibrantBlue
    var showGradient: Bool = true
    var height: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showGradient {
                    // Gradient fill area
                    Path { path in
                        guard data.count > 1 else { return }
                        let maxValue = data.max() ?? 1
                        let minValue = data.min() ?? 0
                        let range = maxValue - minValue
                        
                        let stepX = geometry.size.width / CGFloat(data.count - 1)
                        
                        path.move(to: CGPoint(x: 0, y: geometry.size.height))
                        
                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalizedY = range > 0 ? (value - minValue) / range : 0.5
                            let y = geometry.size.height * (1 - CGFloat(normalizedY))
                            
                            if index == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Line
                Path { path in
                    guard data.count > 1 else { return }
                    let maxValue = data.max() ?? 1
                    let minValue = data.min() ?? 0
                    let range = maxValue - minValue
                    
                    let stepX = geometry.size.width / CGFloat(data.count - 1)
                    
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = range > 0 ? (value - minValue) / range : 0.5
                        let y = geometry.size.height * (1 - CGFloat(normalizedY))
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Animated Chart Container

/// Wrapper that adds entrance animation to any chart
struct AnimatedChartContainer<Content: View>: View {
    let content: Content
    var delay: Double = 0.2
    var duration: Double = 0.8
    
    @State private var isVisible = false
    @StateObject private var haptics = HapticManager.shared
    
    init(delay: Double = 0.2, duration: Double = 0.8, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.delay = delay
        self.duration = duration
    }
    
    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    isVisible = true
                }
                // Haptic on chart appearance
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    haptics.light()
                }
            }
    }
}

// MARK: - Previews

#Preview("Line Chart") {
    VStack(spacing: 20) {
        SpendSmartLineChart(
            data: [8, 23, 54, 32, 12, 37, 7, 23, 43],
            title: "Spending Trend",
            legend: "Last 9 days"
        )
        
        SpendSmartSparkline(data: [10, 25, 18, 35, 28, 42, 38, 55, 48])
            .frame(width: 150)
    }
    .padding()
}

#Preview("Bar Chart") {
    SpendSmartBarChart(
        data: ChartData(values: [
            ("Food", 450),
            ("Transport", 280),
            ("Shopping", 320),
            ("Entertainment", 150)
        ]),
        title: "Categories",
        legend: "This month"
    )
    .padding()
}

#Preview("Pie Chart") {
    SpendSmartPieChart(
        data: [35, 28, 20, 12, 5],
        title: "Breakdown",
        legend: "By category"
    )
    .padding()
}
