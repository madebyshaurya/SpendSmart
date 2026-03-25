import SwiftUI
import SwiftUICharts

/// A chat bubble component that renders interactive charts
/// Supports line, bar, and pie charts with brand styling and haptic feedback
struct ChartBubble: View {
    let chart: ChatChart
    var height: CGFloat = 200
    
    @State private var isAnimated = false
    @StateObject private var haptics = HapticManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chart title
            if let title = chart.title, !title.isEmpty {
                Text(title)
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
            }
            
            // Chart content
            chartContent
                .frame(height: height)
                .opacity(isAnimated ? 1 : 0)
                .scaleEffect(isAnimated ? 1 : 0.95)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .shadow(color: Color.brandDeepNavy.opacity(0.08), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandBorder, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                isAnimated = true
            }
            // Haptic feedback when chart appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                haptics.light()
            }
        }
    }
    
    // MARK: - Chart Content
    
    @ViewBuilder
    private var chartContent: some View {
        switch chart.type {
        case .line:
            lineChartView
        case .bar:
            barChartView
        case .pie:
            pieChartView
        }
    }
    
    // MARK: - Line Chart
    
    private var lineChartView: some View {
        Group {
            if chart.dataPoints.count > 1 {
                LineView(
                    data: chart.dataPoints,
                    title: "",
                    legend: legendText,
                    style: brandLineStyle,
                    valueSpecifier: "%.0f"
                )
            } else {
                emptyChartPlaceholder
            }
        }
    }
    
    // MARK: - Bar Chart
    
    private var barChartView: some View {
        Group {
            if !chart.dataPoints.isEmpty {
                BarChartView(
                    data: barChartData,
                    title: "",
                    legend: legendText,
                    style: brandBarStyle,
                    form: ChartForm.extraLarge,
                    dropShadow: false,
                    cornerImage: Image(systemName: "chart.bar.fill"),
                    valueSpecifier: "%.0f",
                    animatedToBack: true
                )
            } else {
                emptyChartPlaceholder
            }
        }
    }
    
    // MARK: - Pie Chart
    
    private var pieChartView: some View {
        Group {
            if !chart.dataPoints.isEmpty {
                PieChartView(
                    data: chart.dataPoints,
                    title: "",
                    legend: legendText,
                    style: brandPieStyle,
                    form: ChartForm.medium,
                    dropShadow: false,
                    valueSpecifier: "%.0f"
                )
            } else {
                emptyChartPlaceholder
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var emptyChartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(Color.brandTextTertiary)
            Text("No data to display")
                .font(.manrope(size: 14))
                .foregroundStyle(Color.brandTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Chart Data Conversion
    
    private var barChartData: ChartData {
        if let labeledData = chart.labeledData {
            let values = labeledData.map { ($0.label, $0.value) }
            return ChartData(values: values)
        } else if let data = chart.data, let labels = chart.labels {
            let values = zip(labels, data).map { ($0, $1) }
            return ChartData(values: values)
        } else if let data = chart.data {
            let points: [Double] = data
            return ChartData(points: points)
        }
        let emptyPoints: [Double] = []
        return ChartData(points: emptyPoints)
    }
    
    private var legendText: String? {
        guard let labels = chart.labels, !labels.isEmpty else { return nil }
        if labels.count <= 3 {
            return labels.joined(separator: " • ")
        }
        return nil
    }
    
    // MARK: - Brand Styles
    
    private var brandLineStyle: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandSurface,
            accentColor: Color.brandVibrantBlue,
            secondGradientColor: Color.brandSkyBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.clear
        )
    }
    
    private var brandBarStyle: ChartStyle {
        ChartStyle(
            backgroundColor: Color.brandSurface,
            accentColor: Color.brandDeepNavy,
            secondGradientColor: Color.brandVibrantBlue,
            textColor: Color.brandTextPrimary,
            legendTextColor: Color.brandTextSecondary,
            dropShadowColor: Color.clear
        )
    }
    
    private var brandPieStyle: ChartStyle {
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

// MARK: - Compact Chart Bubble (for smaller displays)

/// A more compact version of ChartBubble for inline display
struct CompactChartBubble: View {
    let chart: ChatChart
    var height: CGFloat = 120
    
    @State private var isAnimated = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = chart.title {
                Text(title)
                    .font(.manrope(size: 12, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            
            compactChartContent
                .frame(height: height)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.brandBorder, lineWidth: 1)
        )
        .opacity(isAnimated ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimated = true
            }
        }
    }
    
    @ViewBuilder
    private var compactChartContent: some View {
        switch chart.type {
        case .line:
            // Use sparkline for compact line chart
            SpendSmartSparkline(
                data: chart.dataPoints,
                color: .brandVibrantBlue,
                showGradient: true,
                height: height
            )
        case .bar, .pie:
            // Fall back to regular chart for bar/pie
            ChartBubble(chart: chart, height: height)
        }
    }
}

// MARK: - Chart Form Extension

extension ChartForm {
    /// Extra large form for chat bubbles
    static let extraLarge = CGSize(width: 320, height: 200)
}

// MARK: - Previews

#Preview("Line Chart Bubble") {
    VStack(spacing: 16) {
        ChartBubble(chart: .sampleLine)
        CompactChartBubble(chart: .sampleLine)
    }
    .padding()
    .background(Color.brandBackground)
}

#Preview("Bar Chart Bubble") {
    ChartBubble(chart: .sampleBar)
        .padding()
        .background(Color.brandBackground)
}

#Preview("Pie Chart Bubble") {
    ChartBubble(chart: .samplePie, height: 250)
        .padding()
        .background(Color.brandBackground)
}
