//
//  StackedCategoryBarChart.swift
//  SpendSmart
//
//  Advanced chart components for spending analytics.
//  Features: Stacked categories.
//

import SwiftUI

// MARK: - Stacked Category Bar Chart

/// Daily bars stacked by category - using custom drawing
struct StackedCategoryBarChart: View {
    let data: [StackedBarData]
    var chartHeight: CGFloat = 220
    var onDayTapped: ((StackedBarData) -> Void)? = nil

    @State private var selectedDay: StackedBarData?
    @State private var animationProgress: CGFloat = 0
    @StateObject private var haptics = HapticManager.shared

    private var maxTotal: Double {
        data.map { $0.totalAmount }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(allCategories, id: \.self) { category in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CategoryData.color(for: category))
                                .frame(width: 8, height: 8)
                            Text(category)
                                .font(.manrope(size: 11, weight: .medium))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                    }
                }
            }

            // Stacked Bar Chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data) { day in
                    VStack(spacing: 0) {
                        // Stacked bars
                        VStack(spacing: 0) {
                            ForEach(day.categories.reversed(), id: \.category) { categoryAmount in
                                let barHeight = (chartHeight - 30) * CGFloat(categoryAmount.amount / maxTotal) * animationProgress

                                Rectangle()
                                    .fill(CategoryData.color(for: categoryAmount.category))
                                    .frame(height: max(0, barHeight))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .frame(height: chartHeight - 30)

                        // Day label
                        Text(formatDayLabel(day.date))
                            .font(.manrope(size: 10))
                            .foregroundStyle(Color.brandTextTertiary)
                            .frame(height: 20)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        selectedDay?.id == day.id ?
                            Color.brandVibrantBlue.opacity(0.1) :
                            Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDay = day
                        onDayTapped?(day)
                        haptics.medium()
                    }
                }
            }
            .frame(height: chartHeight)

            // Selected day details
            if let selected = selectedDay {
                VStack(alignment: .leading, spacing: 8) {
                    Text(formatFullDate(selected.date))
                        .font(.manrope(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandTextPrimary)

                    ForEach(selected.categories.sorted(by: { $0.amount > $1.amount }), id: \.category) { cat in
                        HStack {
                            Circle()
                                .fill(CategoryData.color(for: cat.category))
                                .frame(width: 8, height: 8)
                            Text(cat.category)
                                .font(.manrope(size: 12))
                                .foregroundStyle(Color.brandTextSecondary)
                            Spacer()
                            Text(formatAmount(cat.amount))
                                .font(.ibmPlexMono(size: 12))
                                .foregroundStyle(Color.brandTextPrimary)
                        }
                    }
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

    private var allCategories: [String] {
        var categories = Set<String>()
        for day in data {
            for cat in day.categories {
                categories.insert(cat.category)
            }
        }
        return Array(categories).sorted()
    }

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = .current
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.locale = .current
        return formatter
    }()

    private func formatDayLabel(_ date: Date) -> String {
        Self.dayLabelFormatter.string(from: date)
    }

    private func formatFullDate(_ date: Date) -> String {
        Self.fullDateFormatter.string(from: date)
    }

    private func formatAmount(_ amount: Double) -> String {
        CurrencyService.shared.formatAmount(amount, currency: CurrencyService.shared.preferredCurrency)
    }
}

/// Stacked bar data model
struct StackedBarData: Identifiable {
    let id = UUID()
    let date: Date
    let categories: [CategoryAmount]

    var totalAmount: Double {
        categories.reduce(0) { $0 + $1.amount }
    }
}

struct CategoryAmount {
    let category: String
    let amount: Double
}
