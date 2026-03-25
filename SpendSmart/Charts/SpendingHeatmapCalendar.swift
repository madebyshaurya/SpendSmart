//
//  SpendingHeatmapCalendar.swift
//  SpendSmart
//
//  Advanced chart components for spending analytics.
//  Features: Heatmap calendar.
//

import SwiftUI

// MARK: - Spending Heatmap Calendar

/// Calendar view with spending intensity colors
struct SpendingHeatmapCalendar: View {
    let data: [HeatmapData]
    var month: Date = Date()
    var onDayTapped: ((HeatmapData?) -> Void)? = nil

    @State private var selectedDay: HeatmapData?
    @StateObject private var haptics = HapticManager.shared

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = .current
        return formatter
    }()

    private static let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        formatter.locale = .current
        return formatter
    }()

    private var maxAmount: Double {
        data.map { $0.amount }.max() ?? 1
    }

    var body: some View {
        VStack(spacing: 16) {
            // Month header
            HStack {
                Text(monthYearString)
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)

                Spacer()

                // Legend
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.manrope(size: 10))
                        .foregroundStyle(Color.brandTextTertiary)

                    ForEach(0..<5) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(intensityColor(for: Double(i) / 4.0))
                            .frame(width: 12, height: 12)
                    }

                    Text("More")
                        .font(.manrope(size: 10))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }

            // Weekday headers
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.manrope(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)
                        .frame(height: 20)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                // Empty cells for offset
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(height: 36)
                }

                // Days
                ForEach(daysInMonth, id: \.self) { day in
                    let dayData = dataForDay(day)
                    let intensity = dayData.map { $0.amount / maxAmount } ?? 0

                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            selectedDay = dayData
                            onDayTapped?(dayData)
                        }
                        haptics.light()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(intensityColor(for: intensity))

                            Text("\(calendar.component(.day, from: day))")
                                .font(.manrope(size: 12, weight: selectedDay?.date == day ? .bold : .medium))
                                .foregroundStyle(intensity > 0.5 ? .white : Color.brandTextPrimary)
                        }
                        .frame(height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedDay?.date == day ? Color.brandVibrantBlue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Selected day details
            if let selected = selectedDay {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDayDate(selected.date))
                            .font(.manrope(size: 14, weight: .semibold))
                            .foregroundStyle(Color.brandTextPrimary)
                        Text("\(selected.receiptCount) receipt\(selected.receiptCount == 1 ? "" : "s")")
                            .font(.manrope(size: 12))
                            .foregroundStyle(Color.brandTextSecondary)
                    }

                    Spacer()

                    Text(formatAmount(selected.amount))
                        .font(.ibmPlexMono(size: 20))
                        .foregroundStyle(Color.brandTextPrimary)
                }
                .padding(12)
                .background(Color.brandSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var monthYearString: String {
        Self.monthYearFormatter.string(from: month)
    }

    private var firstWeekdayOffset: Int {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private var daysInMonth: [Date] {
        let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<31
        let components = calendar.dateComponents([.year, .month], from: month)

        return range.compactMap { day -> Date? in
            var dayComponents = components
            dayComponents.day = day
            return calendar.date(from: dayComponents)
        }
    }

    private func dataForDay(_ date: Date) -> HeatmapData? {
        data.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func intensityColor(for intensity: Double) -> Color {
        if intensity <= 0 {
            return Color.brandSurface
        }

        // Gradient from light to dark blue
        return Color.brandVibrantBlue.opacity(0.2 + (intensity * 0.8))
    }

    private func formatDayDate(_ date: Date) -> String {
        Self.dayDateFormatter.string(from: date)
    }

    private func formatAmount(_ amount: Double) -> String {
        CurrencyService.shared.formatAmount(amount, currency: CurrencyService.shared.preferredCurrency)
    }
}

/// Heatmap data model
struct HeatmapData: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let receiptCount: Int
}

private func generateHeatmapSampleData() -> [HeatmapData] {
    let calendar = Calendar.current
    let today = Date()
    var sampleData: [HeatmapData] = []

    for i in 0..<30 {
        if let date = calendar.date(byAdding: .day, value: -i, to: today) {
            let amount = Double.random(in: 0...200)
            let count = Int.random(in: 0...5)
            if amount > 20 {
                sampleData.append(HeatmapData(date: date, amount: amount, receiptCount: count))
            }
        }
    }

    return sampleData
}

#Preview("Spending Heatmap") {
    SpendingHeatmapCalendar(data: generateHeatmapSampleData(), month: Date())
        .padding()
}
