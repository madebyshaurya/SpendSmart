//
//  TimeOfDayChart.swift
//  SpendSmart
//
//  Advanced chart components for spending analytics.
//  Features: Time of day.
//

import SwiftUI

// MARK: - Time of Day Chart

/// Bar chart showing spending by hour of day - custom implementation
struct TimeOfDayChart: View {
    let data: [HourlySpendingData]
    var chartHeight: CGFloat = 200

    @State private var selectedHour: HourlySpendingData?
    @State private var animationProgress: CGFloat = 0
    @StateObject private var haptics = HapticManager.shared

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        formatter.locale = .current
        return formatter
    }()

    private var maxAmount: Double {
        data.map { $0.amount }.max() ?? 1
    }

    private var peakHour: HourlySpendingData? {
        data.max(by: { $0.amount < $1.amount })
    }

    var body: some View {
        VStack(spacing: 16) {
            // Peak time insight
            if let peak = peakHour, peak.amount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brandVibrantBlue)

                    Text("You spend most around \(formatHour(peak.hour))")
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.brandIceBlue)
                .clipShape(Capsule())
            }

            // Custom bar chart
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(data) { hourData in
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(for: hourData))
                            .frame(
                                height: max(2, (chartHeight - 40) * CGFloat(hourData.amount / maxAmount) * animationProgress)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedHour = hourData
                        haptics.light()
                    }
                }
            }
            .frame(height: chartHeight - 40)

            // X-axis labels
            HStack {
                Text("12a")
                    .font(.manrope(size: 10))
                    .foregroundStyle(Color.brandTextTertiary)
                Spacer()
                Text("6a")
                    .font(.manrope(size: 10))
                    .foregroundStyle(Color.brandTextTertiary)
                Spacer()
                Text("12p")
                    .font(.manrope(size: 10))
                    .foregroundStyle(Color.brandTextTertiary)
                Spacer()
                Text("6p")
                    .font(.manrope(size: 10))
                    .foregroundStyle(Color.brandTextTertiary)
                Spacer()
                Text("11p")
                    .font(.manrope(size: 10))
                    .foregroundStyle(Color.brandTextTertiary)
            }

            // Time period labels
            HStack {
                timeLabel("Morning", range: "6am-12pm")
                Spacer()
                timeLabel("Afternoon", range: "12pm-6pm")
                Spacer()
                timeLabel("Evening", range: "6pm-12am")
            }
            .padding(.horizontal, 8)

            // Selected hour details
            if let selected = selectedHour, selected.amount > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatHour(selected.hour))
                            .font(.manrope(size: 14, weight: .semibold))
                            .foregroundStyle(Color.brandTextPrimary)
                        Text("\(selected.transactionCount) transaction\(selected.transactionCount == 1 ? "" : "s")")
                            .font(.manrope(size: 12))
                            .foregroundStyle(Color.brandTextSecondary)
                    }

                    Spacer()

                    Text(formatAmount(selected.amount))
                        .font(.ibmPlexMono(size: 18))
                        .foregroundStyle(Color.brandTextPrimary)
                }
                .padding(12)
                .background(Color.brandSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animationProgress = 1.0
            }
        }
    }

    private func barColor(for hourData: HourlySpendingData) -> Color {
        let intensity = maxAmount > 0 ? hourData.amount / maxAmount : 0

        // Time-based gradient: morning = lighter, evening = darker
        if hourData.hour < 6 {
            return Color.brandDeepNavy.opacity(0.6 + intensity * 0.4)
        } else if hourData.hour < 12 {
            return Color.brandSkyBlue.opacity(0.4 + intensity * 0.6)
        } else if hourData.hour < 18 {
            return Color.brandVibrantBlue.opacity(0.5 + intensity * 0.5)
        } else {
            return Color.brandRoyalBlue.opacity(0.5 + intensity * 0.5)
        }
    }

    private func timeLabel(_ title: String, range: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.manrope(size: 11, weight: .medium))
                .foregroundStyle(Color.brandTextSecondary)
            Text(range)
                .font(.manrope(size: 10))
                .foregroundStyle(Color.brandTextTertiary)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour

        if let date = Calendar.current.date(from: components) {
            return Self.hourFormatter.string(from: date)
        }
        return "\(hour):00"
    }

    private func formatAmount(_ amount: Double) -> String {
        CurrencyService.shared.formatAmount(amount, currency: CurrencyService.shared.preferredCurrency)
    }
}

/// Hourly spending data model
struct HourlySpendingData: Identifiable {
    let id = UUID()
    let hour: Int // 0-23
    let amount: Double
    let transactionCount: Int
}

private func generateHourlySampleData() -> [HourlySpendingData] {
    var sampleData: [HourlySpendingData] = []

    for hour in 0..<24 {
        // Simulate typical spending patterns
        var baseAmount: Double = 0
        if hour >= 7 && hour <= 9 { baseAmount = Double.random(in: 10...40) }
        else if hour >= 11 && hour <= 13 { baseAmount = Double.random(in: 30...80) }
        else if hour >= 17 && hour <= 20 { baseAmount = Double.random(in: 50...150) }
        else if hour >= 6 && hour <= 22 { baseAmount = Double.random(in: 0...30) }

        sampleData.append(HourlySpendingData(hour: hour, amount: baseAmount, transactionCount: Int(baseAmount / 20)))
    }

    return sampleData
}

#Preview("Time of Day") {
    TimeOfDayChart(data: generateHourlySampleData())
        .padding()
}
