import SwiftUI
import Charts

struct CategoryDonutChartView: View {
	var costByCategory: [(category: String, total: Double)]
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var selectedCategory: String?
	
	private var totalAmount: Double {
		costByCategory.reduce(0) { $0 + $1.total }
	}
	
	private var filteredCategories: [(category: String, total: Double)] {
		costByCategory.filter { $0.total > 0 }
	}

	var body: some View {
		if filteredCategories.isEmpty {
			emptyStateView
		} else {
			mainContentView
		}
	}
	
	private var emptyStateView: some View {
		EmptyStateCard(
			icon: "chart.pie",
			title: "No Categories Yet",
			subtitle: "Add some expenses to see your spending breakdown by category"
		)
	}
	
	private var mainContentView: some View {
		VStack(spacing: DesignTokens.Spacing.lg) {
			headerView
			chartView
			categoryListView
		}
		.padding(DesignTokens.Spacing.lg)
		.background(DesignTokens.Colors.Background.secondary)
		.clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
		.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
		.padding(.horizontal, DesignTokens.Spacing.lg)
	}
	
	private var headerView: some View {
		HStack {
			Text("Category Breakdown")
				.font(DesignTokens.Typography.title2())
				.foregroundColor(DesignTokens.Colors.Neutral.primary)
			
			Spacer()
			
			Text("\(filteredCategories.count) categories")
				.font(DesignTokens.Typography.caption1())
				.foregroundColor(DesignTokens.Colors.Neutral.secondary)
				.padding(.horizontal, DesignTokens.Spacing.sm)
				.padding(.vertical, DesignTokens.Spacing.xs)
				.background(
					Capsule()
						.fill(DesignTokens.Colors.Fill.secondary)
				)
		}
	}

	private var chartView: some View {
		VStack(spacing: DesignTokens.Spacing.md) {
			chartContent
			centerValueDisplay
		}
	}
	
	private var chartContent: some View {
		Chart(filteredCategories, id: \.category) { item in
			SectorMark(
				angle: .value("Total", item.total),
				innerRadius: .ratio(0.65),
				angularInset: reduceMotion ? 0 : 2.0
			)
			.cornerRadius(reduceMotion ? 0 : 8)
			.foregroundStyle(by: .value("Category", item.category))
			.opacity(selectedCategory == nil || selectedCategory == item.category ? 1.0 : 0.6)
		}
		.chartLegend(.visible)
		.chartLegend(position: .bottom, alignment: .center)
		.frame(height: 220)
		.scaleEffect(selectedCategory != nil ? 1.05 : 1.0)
		.animation(DesignTokens.Animation.easeInOut, value: selectedCategory)
		.accessibilityElement(children: .combine)
		.accessibilityLabel(accessibilityChartDescription)
		.accessibilityHint("Double tap for detailed breakdown")
		.onTapGesture {
			withAnimation(DesignTokens.Animation.easeInOut) {
				if selectedCategory != nil {
					selectedCategory = nil
				}
			}
		}
	}
	
	private var centerValueDisplay: some View {
		Group {
			if let selected = selectedCategory,
			   let selectedItem = filteredCategories.first(where: { $0.category == selected }) {
				VStack(spacing: DesignTokens.Spacing.xs) {
					Text(selected)
						.font(DesignTokens.Typography.caption1())
						.foregroundColor(DesignTokens.Colors.Neutral.secondary)
					Text(CurrencyManager.shared.formatAmount(selectedItem.total, currencyCode: CurrencyManager.shared.preferredCurrency))
						.font(DesignTokens.Typography.dataDisplay(size: 20))
						.foregroundColor(DesignTokens.Colors.Primary.blue)
				}
				.transition(.opacity)
			} else {
				VStack(spacing: DesignTokens.Spacing.xs) {
					Text("Total")
						.font(DesignTokens.Typography.caption1())
						.foregroundColor(DesignTokens.Colors.Neutral.secondary)
					Text(CurrencyManager.shared.formatAmount(totalAmount, currencyCode: CurrencyManager.shared.preferredCurrency))
						.font(DesignTokens.Typography.dataDisplay(size: 20))
						.foregroundColor(DesignTokens.Colors.Neutral.primary)
				}
				.transition(.opacity)
			}
		}
	}
	
	private var categoryListView: some View {
		Group {
			if !filteredCategories.isEmpty {
				AccessibleCategoryList(categories: filteredCategories, selectedCategory: $selectedCategory)
					.accessibilityElement(children: .contain)
					.accessibilityLabel("Category spending details")
			}
		}
	}
	
	private var accessibilityChartDescription: String {
		let descriptions = filteredCategories.prefix(3).map { category in
			let percentage = (category.total / totalAmount) * 100
			return "\(category.category): \(String(format: "%.1f", percentage))%"
		}
		
		let summary = descriptions.joined(separator: ", ")
		return "Spending breakdown chart. Top categories: \(summary)"
	}
}

struct AccessibleCategoryList: View {
	let categories: [(category: String, total: Double)]
	@Binding var selectedCategory: String?
	
	private var totalAmount: Double {
		categories.reduce(0) { $0 + $1.total }
	}
	
	var body: some View {
		VStack(spacing: DesignTokens.Spacing.xs) {
			ForEach(categories.sorted { $0.total > $1.total }, id: \.category) { category in
				AccessibleCategoryRow(
					category: category,
					totalAmount: totalAmount,
					isSelected: selectedCategory == category.category
				) {
					withAnimation(DesignTokens.Animation.easeInOut) {
						selectedCategory = selectedCategory == category.category ? nil : category.category
					}
				}
			}
		}
		.accessibilityElement(children: .contain)
	}
}

struct AccessibleCategoryRow: View {
	let category: (category: String, total: Double)
	let totalAmount: Double
	let isSelected: Bool
	let onTap: () -> Void
	
	private var percentage: Double {
		totalAmount > 0 ? (category.total / totalAmount) * 100 : 0
	}
	
	var body: some View {
		Button(action: onTap) {
			HStack(spacing: DesignTokens.Spacing.md) {
				Circle()
					.fill(categoryColor(for: category.category))
					.frame(width: 12, height: 12)
					.accessibilityHidden(true)
				
				Text(category.category)
					.font(DesignTokens.Typography.body())
					.foregroundColor(DesignTokens.Colors.Neutral.primary)
					.frame(maxWidth: .infinity, alignment: .leading)
				
				VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
					Text(CurrencyManager.shared.formatAmount(category.total, currencyCode: CurrencyManager.shared.preferredCurrency))
						.font(DesignTokens.Typography.caption1())
						.foregroundColor(DesignTokens.Colors.Neutral.primary)
					
					Text("\(String(format: "%.1f", percentage))%")
						.font(DesignTokens.Typography.caption2())
						.foregroundColor(DesignTokens.Colors.Neutral.secondary)
				}
			}
			.padding(.vertical, DesignTokens.Spacing.sm)
			.padding(.horizontal, DesignTokens.Spacing.md)
			.background(
				RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
					.fill(isSelected ? DesignTokens.Colors.Primary.blue.opacity(0.1) : Color.clear)
			)
		}
		.buttonStyle(PlainButtonStyle())
		.accessibilityLabel("\(category.category): \(CurrencyManager.shared.formatAmount(category.total, currencyCode: CurrencyManager.shared.preferredCurrency)), \(String(format: "%.1f", percentage))% of total spending")
		.accessibilityHint("Tap to highlight this category in the chart")
	}
	
	private func categoryColor(for category: String) -> Color {
		let hash = category.hashValue
		let colors: [Color] = [
			DesignTokens.Colors.Primary.blue,
			DesignTokens.Colors.Primary.teal,
			DesignTokens.Colors.Primary.mint,
			DesignTokens.Colors.Primary.green,
			DesignTokens.Colors.Primary.orange,
			DesignTokens.Colors.Primary.purple,
			DesignTokens.Colors.Primary.indigo
		]
		return colors[abs(hash) % colors.count]
	}
}