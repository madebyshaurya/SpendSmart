import SwiftUI

struct HeroSummarySection: View {
    @Binding var selectedRange: TimeRange
    let totalSpent: Double
    let currencySymbol: String
    let percentageChange: Double?
    let comparisonText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Total Spent \(selectedRange.rawValue)")
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)

                Spacer()

                TimeRangeMenu(selection: $selectedRange)
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                let formatted = String(format: "%.2f", totalSpent)
                let components = formatted.components(separatedBy: ".")

                Text(currencySymbol)
                    .font(.manrope(size: 28, weight: .bold))
                    .foregroundStyle(Color.brandTextSecondary)
                    .baselineOffset(16)

                Text(components[0])
                    .font(.ibmPlexMono(size: 48))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(Color.brandTextPrimary)
                    .kerning(-2)
                    .contentTransition(.numericText())
                    .animation(.brandSnappy, value: totalSpent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if components.count > 1 {
                    Text("." + components[1])
                        .font(.ibmPlexMono(size: 24))
                        .monospacedDigit()
                        .foregroundStyle(Color.brandTextTertiary)
                        .contentTransition(.numericText())
                        .animation(.brandSnappy, value: totalSpent)
                        .padding(.leading, 2)
                }

                Spacer()
            }

            if let change = percentageChange {
                percentageChangePill(change: change)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.brandSurfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }

    private func percentageChangePill(change: Double) -> some View {
        let isDecrease = change < 0
        let pillColor = isDecrease ? Color.brandSuccess : Color.brandError
        let arrowIcon = isDecrease ? "arrow.down.right" : "arrow.up.right"

        return HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: arrowIcon)
                    .font(.system(size: 11, weight: .bold))
                Text(String(format: "%+.1f%%", change))
                    .font(.ibmPlexMono(size: 13))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(pillColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(pillColor.opacity(0.12))
            .clipShape(Capsule())

            Text(comparisonText)
                .font(.manrope(size: 12, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)
        }
    }
}
