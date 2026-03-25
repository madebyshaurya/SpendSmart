//
//  PeriodComparisonChart.swift
//  SpendSmart
//
//  Advanced chart components for spending analytics.
//  Features: Period comparison.
//

import SwiftUI

// MARK: - Period Comparison Chart

/// Side-by-side bar chart comparing two periods - custom implementation
struct PeriodComparisonChart: View {
    let currentPeriod: [SpendingDataPoint]
    let previousPeriod: [SpendingDataPoint]
    var currentLabel: String = "This Period"
    var previousLabel: String = "Last Period"
    var chartHeight: CGFloat = 200

    @State private var animationProgress: CGFloat = 0
    @StateObject private var haptics = HapticManager.shared

    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = .current
        return formatter
    }()

    private var currentTotal: Double {
        currentPeriod.reduce(0) { $0 + $1.amount }
    }

    private var previousTotal: Double {
        previousPeriod.reduce(0) { $0 + $1.amount }
    }

    private var percentageChange: Double {
        guard previousTotal > 0 else { return 0 }
        return ((currentTotal - previousTotal) / previousTotal) * 100
    }

    private var maxAmount: Double {
        let currentMax = currentPeriod.map { $0.amount }.max() ?? 0
        let previousMax = previousPeriod.map { $0.amount }.max() ?? 0
        return max(currentMax, previousMax, 1)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Summary cards
            HStack(spacing: 12) {
                periodCard(
                    label: currentLabel,
                    amount: currentTotal,
                    color: .brandVibrantBlue,
                    isMain: true
                )

                periodCard(
                    label: previousLabel,
                    amount: previousTotal,
                    color: .brandTextTertiary,
                    isMain: false
                )
            }

            // Change indicator
            HStack(spacing: 6) {
                Image(systemName: percentageChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 12, weight: .bold))

                Text(String(format: "%.1f%%", abs(percentageChange)))
                    .font(.manrope(size: 14, weight: .bold))

                Text(percentageChange >= 0 ? "more than \(previousLabel.lowercased())" : "less than \(previousLabel.lowercased())")
                    .font(.manrope(size: 14))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            .foregroundStyle(percentageChange >= 0 ? Color.brandError : Color.brandSuccess)

            // Custom grouped bar chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(currentPeriod.enumerated()), id: \.offset) { index, currentPoint in
                    let previousPoint = previousPeriod[safe: index]

                    VStack(spacing: 2) {
                        HStack(alignment: .bottom, spacing: 2) {
                            // Current period bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.brandVibrantBlue)
                                .frame(
                                    width: 8,
                                    height: max(4, (chartHeight - 40) * CGFloat(currentPoint.amount / maxAmount) * animationProgress)
                                )

                            // Previous period bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.brandTextTertiary.opacity(0.5))
                                .frame(
                                    width: 8,
                                    height: max(4, (chartHeight - 40) * CGFloat((previousPoint?.amount ?? 0) / maxAmount) * animationProgress)
                                )
                        }

                        // Day label
                        Text(formatDayNumber(currentPoint.date))
                            .font(.manrope(size: 9))
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
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

    private func periodCard(label: String, amount: Double, color: Color, isMain: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.manrope(size: 12, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
            }

            Text(formatAmount(amount))
                .font(.ibmPlexMono(size: isMain ? 24 : 18))
                .foregroundStyle(Color.brandTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isMain ? color.opacity(0.08) : Color.brandSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDayNumber(_ date: Date) -> String {
        Self.dayNumberFormatter.string(from: date)
    }

    private func formatAmount(_ amount: Double) -> String {
        CurrencyService.shared.formatAmount(amount, currency: CurrencyService.shared.preferredCurrency)
    }
}

// Safe array access
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
