import SwiftUI
import SwiftUICharts

/// Category breakdown pie/donut chart with interactive selection
/// Features: Tap segments to select, animated entry, legend with amounts
/// Uses custom drawing for donut chart with full interactivity
struct CategoryPieChart: View {
    let data: [CategoryData]
    var onCategoryTapped: ((CategoryData) -> Void)? = nil
    var showLegend: Bool = true
    var isDonut: Bool = true
    var chartSize: CGFloat = 200
    var animate: Bool = true
    
    @State private var selectedCategory: CategoryData?
    @State private var animationProgress: CGFloat = 0
    @StateObject private var haptics = HapticManager.shared
    
    private var totalAmount: Double {
        data.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Chart with center text
            ZStack {
                // Custom Pie/Donut Chart
                GeometryReader { geometry in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let radius = min(geometry.size.width, geometry.size.height) / 2
                    let innerRadius = isDonut ? radius * 0.6 : 0
                    
                    ZStack {
                        // Draw segments
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                            let (startAngle, endAngle) = segmentAngles(for: index)
                            
                            PieSegment(
                                startAngle: startAngle,
                                endAngle: Angle(degrees: startAngle.degrees + (endAngle.degrees - startAngle.degrees) * animationProgress),
                                innerRadiusRatio: isDonut ? 0.6 : 0
                            )
                            .fill(item.color)
                            .opacity(selectedCategory == nil || selectedCategory?.id == item.id ? 1.0 : 0.4)
                            .scaleEffect(selectedCategory?.id == item.id ? 1.05 : 1.0)
                            .animation(.spring(duration: 0.3), value: selectedCategory?.id)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.3)) {
                                    if selectedCategory?.id == item.id {
                                        selectedCategory = nil
                                    } else {
                                        selectedCategory = item
                                        onCategoryTapped?(item)
                                    }
                                }
                                haptics.light()
                            }
                        }
                    }
                }
                .frame(width: chartSize, height: chartSize)
                
                // Center content (for donut)
                if isDonut {
                    VStack(spacing: 4) {
                        if let selected = selectedCategory {
                            Text(selected.name)
                                .font(.manrope(size: 14, weight: .medium))
                                .foregroundStyle(Color.brandTextSecondary)
                            Text(formatAmount(selected.amount))
                                .font(.ibmPlexMono(size: 20))
                                .foregroundStyle(Color.brandTextPrimary)
                                .contentTransition(.numericText())
                            Text(formatPercentage(selected.amount))
                                .font(.manrope(size: 12))
                                .foregroundStyle(Color.brandTextTertiary)
                        } else {
                            Text("Total")
                                .font(.manrope(size: 14, weight: .medium))
                                .foregroundStyle(Color.brandTextSecondary)
                            Text(formatAmount(totalAmount))
                                .font(.ibmPlexMono(size: 20))
                                .foregroundStyle(Color.brandTextPrimary)
                        }
                    }
                }
            }
            
            // Legend
            if showLegend {
                legendView
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }
    
    private func segmentAngles(for index: Int) -> (start: Angle, end: Angle) {
        var startAngle = -90.0 // Start from top
        for i in 0..<index {
            startAngle += (data[i].amount / totalAmount) * 360
        }
        let endAngle = startAngle + (data[index].amount / totalAmount) * 360
        return (Angle(degrees: startAngle), Angle(degrees: endAngle))
    }
    
    private func formatAmount(_ amount: Double) -> String {
        CurrencyService.shared.formatAmount(amount, currency: CurrencyService.shared.preferredCurrency)
    }
    
    private func formatPercentage(_ amount: Double) -> String {
        let percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0
        return String(format: "%.1f%%", percentage)
    }
    
    private var legendView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(data) { item in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        if selectedCategory?.id == item.id {
                            selectedCategory = nil
                        } else {
                            selectedCategory = item
                            onCategoryTapped?(item)
                        }
                    }
                    haptics.selection()
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.manrope(size: 13, weight: selectedCategory?.id == item.id ? .semibold : .medium))
                                .foregroundStyle(Color.brandTextPrimary)
                                .lineLimit(1)
                            Text(formatAmount(item.amount))
                                .font(.ibmPlexMono(size: 12))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(selectedCategory?.id == item.id ? item.color.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Pie Segment Shape

struct PieSegment: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var innerRadiusRatio: CGFloat = 0
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = Angle(degrees: newValue.first)
            endAngle = Angle(degrees: newValue.second)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * innerRadiusRatio
        
        // Outer arc
        path.addArc(center: center, radius: radius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        
        // Line to inner arc
        let innerStart = CGPoint(
            x: center.x + innerRadius * CGFloat(cos(endAngle.radians)),
            y: center.y + innerRadius * CGFloat(sin(endAngle.radians))
        )
        path.addLine(to: innerStart)
        
        // Inner arc
        path.addArc(center: center, radius: innerRadius,
                    startAngle: endAngle, endAngle: startAngle, clockwise: true)
        
        path.closeSubpath()
        return path
    }
}

/// Category data model
struct CategoryData: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let amount: Double
    let color: Color
    var receipts: [Receipt] = []
    
    static func == (lhs: CategoryData, rhs: CategoryData) -> Bool {
        lhs.id == rhs.id
    }
    
    // Predefined category colors
    static func color(for category: String) -> Color {
        switch category.lowercased() {
        case "groceries", "grocery": return .chartBlue1
        case "food", "dining", "restaurant", "restaurants": return .chartBlue2
        case "transport", "transportation", "travel": return .chartBlue3
        case "shopping", "retail": return .chartBlue4
        case "entertainment", "fun": return .chartBlue5
        case "health", "medical", "pharmacy": return .brandSuccess
        case "utilities", "bills": return .brandWarning
        case "other", "miscellaneous": return .brandTextTertiary
        default: return .brandVibrantBlue.opacity(0.7)
        }
    }
}

// MARK: - Horizontal Bar Chart (Alternative category view)

struct CategoryBarChart: View {
    let data: [CategoryData]
    var onCategoryTapped: ((CategoryData) -> Void)? = nil
    var chartHeight: CGFloat = 250
    
    @State private var selectedCategory: CategoryData?
    @State private var animationProgress: CGFloat = 0
    
    private var maxAmount: Double {
        data.map { $0.amount }.max() ?? 1
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(data.sorted(by: { $0.amount > $1.amount })) { item in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        if selectedCategory?.id == item.id {
                            selectedCategory = nil
                        } else {
                            selectedCategory = item
                            onCategoryTapped?(item)
                        }
                    }
                    HapticManager.shared.selection()
                } label: {
                    VStack(spacing: 6) {
                        HStack {
                            Text(item.name)
                                .font(.manrope(size: 14, weight: .medium))
                                .foregroundStyle(Color.brandTextPrimary)
                            
                            Spacer()
                            
                            Text(CurrencyService.shared.formatAmount(item.amount, currency: CurrencyService.shared.preferredCurrency))
                                .font(.ibmPlexMono(size: 14))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.brandSurface)
                                    .frame(height: 8)
                                
                                // Progress bar
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.color)
                                    .frame(
                                        width: geometry.size.width * CGFloat(item.amount / maxAmount) * animationProgress,
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(selectedCategory?.id == item.id ? item.color.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Compact Category Summary (for cards)

struct CategorySummaryRow: View {
    let category: CategoryData
    let total: Double
    var onTap: (() -> Void)? = nil
    
    private var percentage: Double {
        total > 0 ? (category.amount / total) * 100 : 0
    }
    
    var body: some View {
        Button {
            onTap?()
            HapticManager.shared.light()
        } label: {
            HStack(spacing: 12) {
                // Color indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(category.color)
                    .frame(width: 4, height: 36)
                
                // Category info
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(Color.brandTextPrimary)
                    Text("\(Int(percentage))% of total")
                        .font(.manrope(size: 12))
                        .foregroundStyle(Color.brandTextTertiary)
                }
                
                Spacer()
                
                // Amount
                    Text(CurrencyService.shared.formatAmount(category.amount, currency: CurrencyService.shared.preferredCurrency))
                    .font(.ibmPlexMono(size: 15))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .padding(12)
            .background(Color.brandSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Icon Helper

struct CategoryIcon: View {
    let category: String
    var size: CGFloat = 32
    
    var body: some View {
        ZStack {
            Circle()
                .fill(CategoryData.color(for: category).opacity(0.15))
            
            Image(systemName: iconName)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(CategoryData.color(for: category))
        }
        .frame(width: size, height: size)
    }
    
    private var iconName: String {
        switch category.lowercased() {
        case "groceries", "grocery": return "cart.fill"
        case "food", "dining", "restaurant", "restaurants": return "fork.knife"
        case "transport", "transportation": return "car.fill"
        case "travel": return "airplane"
        case "shopping", "retail": return "bag.fill"
        case "entertainment", "fun": return "film.fill"
        case "health", "medical": return "heart.fill"
        case "pharmacy": return "pills.fill"
        case "utilities", "bills": return "bolt.fill"
        case "gas", "fuel": return "fuelpump.fill"
        default: return "tag.fill"
        }
    }
}

// MARK: - Previews

#Preview("Pie Chart") {
    let sampleData: [CategoryData] = [
        CategoryData(name: "Groceries", amount: 450, color: .chartBlue1),
        CategoryData(name: "Dining", amount: 280, color: .chartBlue2),
        CategoryData(name: "Transport", amount: 150, color: .chartBlue3),
        CategoryData(name: "Shopping", amount: 320, color: .chartBlue4),
        CategoryData(name: "Entertainment", amount: 90, color: .chartBlue5)
    ]
    
    CategoryPieChart(data: sampleData)
        .padding()
}

#Preview("Bar Chart") {
    let sampleData: [CategoryData] = [
        CategoryData(name: "Groceries", amount: 450, color: .chartBlue1),
        CategoryData(name: "Dining", amount: 280, color: .chartBlue2),
        CategoryData(name: "Transport", amount: 150, color: .chartBlue3),
        CategoryData(name: "Shopping", amount: 320, color: .chartBlue4),
        CategoryData(name: "Entertainment", amount: 90, color: .chartBlue5)
    ]
    
    CategoryBarChart(data: sampleData)
        .padding()
}

#Preview("Category Icon") {
    HStack(spacing: 16) {
        CategoryIcon(category: "Groceries")
        CategoryIcon(category: "Food")
        CategoryIcon(category: "Transport")
        CategoryIcon(category: "Shopping")
        CategoryIcon(category: "Entertainment")
    }
    .padding()
}
