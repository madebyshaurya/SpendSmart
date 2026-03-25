import SwiftUI

/// Dashboard section showing AI spending insights (Plus-only).
struct InsightsSection: View {
    @ObservedObject var insightsEngine: InsightsEngine
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var haptics = HapticManager.shared

    @AppStorage("totalScanCount") private var totalScanCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.brandVibrantBlue)
                Text("Smart Insights")
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundColor(.brandTextPrimary)

                Spacer()

                if subscriptionManager.isPlus {
                    Text("Plus")
                        .font(.manrope(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(LinearGradient.brandPremium)
                        )
                }
            }

            if !subscriptionManager.isPlus {
                // Free user: upsell
                insightsUpsellCard
            } else if insightsEngine.insights.isEmpty {
                // Plus user but no insights yet
                insightsEmptyState
            } else {
                // Plus user with insights
                insightCards
            }
        }
    }

    // MARK: - Insight Cards

    private var insightCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(insightsEngine.insights.prefix(5).enumerated()), id: \.element.id) { index, insight in
                    insightCard(insight)
                        .animateEntrance(index: index)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func insightCard(_ insight: InsightsEngine.Insight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName(for: insight.type))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.brandVibrantBlue)
                Spacer()
                if !insight.isRead {
                    Circle()
                        .fill(Color.brandVibrantBlue)
                        .frame(width: 6, height: 6)
                }
            }

            Text(insight.title)
                .font(.manrope(size: 14, weight: .bold))
                .foregroundColor(.brandTextPrimary)

            Text(insight.message)
                .font(.manrope(size: 12, weight: .regular))
                .foregroundColor(.brandTextSecondary)
                .lineLimit(3)

            if let amount = insight.amount {
                Text("$\(amount, specifier: "%.0f")")
                    .font(.ibmPlexMono(size: 18))
                    .foregroundColor(.brandVibrantBlue)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .padding(16)
        .frame(width: 200, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
        .onTapGesture {
            haptics.selection()
            insightsEngine.markAsRead(insight)
        }
        .scaleEffect(insight.isRead ? 1.0 : 1.0)
    }

    // MARK: - Empty State

    private var insightsEmptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundColor(.brandVibrantBlue.opacity(0.5))

            VStack(alignment: .leading, spacing: 4) {
                Text("Insights are warming up")
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundColor(.brandTextPrimary)
                Text("Scan \(max(0, 5 - totalScanCount)) more receipts to unlock your first insight.")
                    .font(.manrope(size: 12, weight: .regular))
                    .foregroundColor(.brandTextSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandVibrantBlue.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandVibrantBlue.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Upsell Card

    private var insightsUpsellCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20))
                .foregroundColor(.brandVibrantBlue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Unlock Smart Insights")
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundColor(.brandTextPrimary)
                Text("Get AI-powered spending alerts and weekly summaries.")
                    .font(.manrope(size: 12, weight: .regular))
                    .foregroundColor(.brandTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.brandVibrantBlue)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient.brandPremium.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandVibrantBlue.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture {
            haptics.buttonPress()
            subscriptionManager.presentPaywall(trigger: .settingsUpgrade)
        }
    }

    // MARK: - Helpers

    private func iconName(for type: InsightsEngine.Insight.InsightType) -> String {
        switch type {
        case .weeklySummary: return "calendar"
        case .spendingSpike: return "arrow.up.right"
        case .categoryMilestone: return "flag.fill"
        }
    }
}
