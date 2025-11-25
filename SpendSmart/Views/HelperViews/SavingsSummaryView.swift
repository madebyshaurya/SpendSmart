import SwiftUI

struct SavingsSummaryView: View {
	var totalExpense: Double
	var totalTax: Double
	var totalSavings: Double
	var receiptCount: Int
	@Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var currencyManager = CurrencyManager.shared

	var body: some View {
		VStack(spacing: DesignTokens.Spacing.lg) {
			// Header with improved typography hierarchy
			HStack {
				Text("Overview")
					.textHierarchy(.sectionTitle)

				Spacer()

				Text(receiptCount == 1 ? "1 receipt" : "\(receiptCount) receipts")
					.textHierarchy(.metadata)
					.padding(.horizontal, DesignTokens.Spacing.md)
					.padding(.vertical, DesignTokens.Spacing.xs)
					.background(
						Capsule()
							.fill(DesignTokens.Colors.Fill.secondary)
					)
			}

			// Enhanced stat cards with better visual hierarchy
			if UIDevice.current.userInterfaceIdiom == .phone && UIScreen.main.bounds.width < 400 {
				// Vertical layout for smaller screens
				VStack(spacing: DesignTokens.Spacing.md) {
					enhancedStatCard(
						title: "Total Spent",
						amount: totalExpense,
						icon: "creditcard.fill",
						color: DesignTokens.Colors.Primary.blue,
						backgroundColor: DesignTokens.Colors.Primary.blue.opacity(0.1)
					)
					
					if totalSavings > 0 {
						enhancedStatCard(
							title: "Savings",
							amount: totalSavings,
							icon: "tag.fill",
							color: DesignTokens.Colors.Semantic.savings,
							backgroundColor: DesignTokens.Colors.Semantic.savings.opacity(0.1)
						)
					}
				}
			} else {
				// Horizontal layout for larger screens
				HStack(spacing: DesignTokens.Spacing.md) {
					enhancedStatCard(
						title: "Total Spent",
						amount: totalExpense,
						icon: "creditcard.fill",
						color: DesignTokens.Colors.Primary.blue,
						backgroundColor: DesignTokens.Colors.Primary.blue.opacity(0.1)
					)

					if totalSavings > 0 {
						enhancedStatCard(
							title: "Savings",
							amount: totalSavings,
							icon: "tag.fill",
							color: DesignTokens.Colors.Semantic.savings,
							backgroundColor: DesignTokens.Colors.Semantic.savings.opacity(0.1)
						)
					}
				}
			}
		}
		.semanticSpacing(.cardInner)
		.contentContainer(level: .primary)
		.semanticSpacing(.cardOuter)
		.accessibilityElement(children: .combine)
		.accessibilityLabel("Overview: \(receiptCount) receipts, total spent \(FinancialAccessibilityHelper.formatCurrencyForAccessibility(totalExpense, currency: currencyManager.preferredCurrency))")
		.accessibilityHint(totalSavings > 0 ? "Total savings \(FinancialAccessibilityHelper.formatCurrencyForAccessibility(totalSavings, currency: currencyManager.preferredCurrency))" : "")
		.respectMotionPreferences()
	}
	
	@ViewBuilder
	private func enhancedStatCard(
		title: String,
		amount: Double,
		icon: String,
		color: Color,
		backgroundColor: Color
	) -> some View {
		VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
			HStack {
				Image(systemName: icon)
					.font(.system(size: DesignTokens.ComponentSize.iconSize, weight: .medium))
					.foregroundColor(color)
					.accessibilityHidden(true)

				Text(title)
					.textHierarchy(.metadata)
				
				Spacer()
			}

			Text(currencyManager.formatAmount(amount, currencyCode: currencyManager.preferredCurrency))
				.textHierarchy(.dataValue, color: DesignTokens.Colors.Neutral.primary)
				.accessibilityLabel(FinancialAccessibilityHelper.formatCurrencyForAccessibility(amount, currency: currencyManager.preferredCurrency))
		}
		.semanticSpacing(.cardInner)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
				.fill(backgroundColor)
		)
		.overlay(
			RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
				.strokeBorder(color.opacity(0.2), lineWidth: 1)
		)
		.accessibilityElement(children: .combine)
		.accessibilityLabel("\(title): \(FinancialAccessibilityHelper.formatCurrencyForAccessibility(amount, currency: currencyManager.preferredCurrency))")
	}
}

struct SummaryItemView: View {
	let title: String
	let amount: Double
	@Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var currencyManager = CurrencyManager.shared

	var body: some View {
		VStack {
			Text(title)
				.font(.instrumentSans(size: 14))
				.foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
			Text(currencyManager.formatAmount(amount, currencyCode: currencyManager.preferredCurrency))
				.font(.spaceGrotesk(size: 20, weight: .semibold))
				.foregroundColor(colorScheme == .dark ? .white : .black)
		}
		.frame(maxWidth: .infinity)
	}
}


