//
//  StoreBreakdownChart.swift
//  SpendSmart
//
//  Advanced chart components for spending analytics.
//  Features: Store breakdown.
//

import SwiftUI

// MARK: - Store Breakdown Chart

/// Horizontal bar chart showing top stores by spending amount
struct StoreBreakdownChart: View {
    let data: [StoreSpendingData]
    var maxStores: Int = 10
    var onStoreTapped: ((StoreSpendingData) -> Void)? = nil

    @State private var selectedStore: StoreSpendingData?
    @State private var animationProgress: CGFloat = 0
    @StateObject private var haptics = HapticManager.shared

    private var sortedData: [StoreSpendingData] {
        Array(data.sorted(by: { $0.amount > $1.amount }).prefix(maxStores))
    }

    private var maxAmount: Double {
        sortedData.map { $0.amount }.max() ?? 1
    }

    private var totalAmount: Double {
        data.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(sortedData.enumerated()), id: \.element.id) { index, store in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        if selectedStore?.id == store.id {
                            selectedStore = nil
                        } else {
                            selectedStore = store
                            onStoreTapped?(store)
                        }
                    }
                    haptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        // Rank
                        Text("\(index + 1)")
                            .font(.manrope(size: 12, weight: .bold))
                            .foregroundStyle(Color.brandTextTertiary)
                            .frame(width: 20)

                        // Store logo placeholder
                        BrandLogoView(storeName: store.name, logoSearchTerm: store.name)
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(store.name)
                                    .font(.manrope(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.brandTextPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Text(formatAmount(store.amount))
                                    .font(.ibmPlexMono(size: 14))
                                    .foregroundStyle(Color.brandTextPrimary)
                            }

                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.brandSurface)
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(storeColor(for: index))
                                        .frame(
                                            width: geometry.size.width * CGFloat(store.amount / maxAmount) * animationProgress,
                                            height: 6
                                        )
                                }
                            }
                            .frame(height: 6)

                            // Visits and percentage
                            HStack {
                                Text("\(store.visitCount) visit\(store.visitCount == 1 ? "" : "s")")
                                    .font(.manrope(size: 11))
                                    .foregroundStyle(Color.brandTextTertiary)

                                Spacer()

                                Text(formatPercentage(store.amount))
                                    .font(.manrope(size: 11))
                                    .foregroundStyle(Color.brandTextTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedStore?.id == store.id ? storeColor(for: index).opacity(0.08) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .opacity(animationProgress)
                .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05), value: animationProgress)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animationProgress = 1.0
            }
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        CurrencyService.shared.formatAmount(amount, currency: CurrencyService.shared.preferredCurrency)
    }

    private func formatPercentage(_ amount: Double) -> String {
        let percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0
        return String(format: "%.1f%%", percentage)
    }

    private func storeColor(for index: Int) -> Color {
        let colors: [Color] = [
            .chartBlue1, .chartBlue2, .chartBlue3, .chartBlue4, .chartBlue5,
            .brandSuccess, .brandWarning, .brandPurple,
            .brandError, .brandIndigo
        ]
        return colors[index % colors.count]
    }
}

/// Store spending data model
struct StoreSpendingData: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let visitCount: Int
    var receipts: [Receipt] = []
}

#Preview("Store Breakdown") {
    let sampleData = [
        StoreSpendingData(name: "Whole Foods", amount: 456.78, visitCount: 12),
        StoreSpendingData(name: "Target", amount: 321.45, visitCount: 8),
        StoreSpendingData(name: "Costco", amount: 289.99, visitCount: 3),
        StoreSpendingData(name: "Trader Joe's", amount: 234.56, visitCount: 15),
        StoreSpendingData(name: "CVS Pharmacy", amount: 123.45, visitCount: 6)
    ]

    ScrollView {
        StoreBreakdownChart(data: sampleData)
            .padding()
    }
}
