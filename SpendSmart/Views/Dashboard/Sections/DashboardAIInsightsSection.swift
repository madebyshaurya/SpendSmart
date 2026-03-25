import SwiftUI

struct DashboardAIInsightsSection: View {
    let topCategory: String
    let topCategoryAmount: Double
    let topCategoryPercentage: Double
    let insightText: String
    let comparisonNote: String
    let isLoading: Bool
    let onRefresh: () -> Void

    private var clampedPercentage: Double {
        max(0, min(topCategoryPercentage, 100))
    }

    private var progressValue: Double {
        clampedPercentage / 100
    }

    private var formattedAmount: String {
        CurrencyService.shared.formatAmount(topCategoryAmount, currency: CurrencyService.shared.preferredCurrency)
    }

    private var percentageLabel: String {
        "\(Int(clampedPercentage.rounded()))% of total"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.min")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTextSecondary)

                Text("AI Insight")
                    .font(.manrope(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTextSecondary)

                Spacer()

                Button {
                    HapticManager.shared.light()
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandTextSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.brandSurfaceElevated)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(topCategory)
                        .font(.manrope(size: 15, weight: .semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(formattedAmount)
                        .font(.ibmPlexMono(size: 18))
                        .foregroundStyle(Color.brandTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(percentageLabel)
                        .font(.manrope(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.brandSurfaceElevated)
                        )
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.brandBorder)
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.brandVibrantBlue)
                            .frame(width: geometry.size.width * progressValue, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Text(insightText)
                .font(.instrumentSerifItalic(size: 15))
                .foregroundStyle(Color.brandTextSecondary)
                .lineLimit(2)

            Text(comparisonNote)
                .font(.manrope(size: 12, weight: .regular))
                .foregroundStyle(Color.brandTextTertiary)
                .lineLimit(1)
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
        .redacted(reason: isLoading ? .placeholder : [])
    }
}
