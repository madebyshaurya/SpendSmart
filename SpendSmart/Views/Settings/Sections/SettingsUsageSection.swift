import SwiftUI

struct SettingsUsageSection: View {
    @ObservedObject var subscriptionManager: SubscriptionManager

    private var usageColor: Color {
        let remaining = subscriptionManager.scansRemaining ?? 0
        if remaining == 0 {
            return Color.brandError
        } else if remaining <= 2 {
            return Color.brandWarning
        } else {
            return Color.brandVibrantBlue
        }
    }

    private var nextResetText: String {
        let calendar = Calendar.current
        let today = Date()

        let nextMonday = calendar.nextDate(
            after: today,
            matching: DateComponents(weekday: 2),
            matchingPolicy: .nextTime
        ) ?? today

        let days = calendar.dateComponents([.day], from: today, to: nextMonday).day ?? 0

        if days == 0 {
            return "today"
        } else if days == 1 {
            return "tomorrow"
        } else {
            return "in \(days) days"
        }
    }

    var body: some View {
        Section {
            VStack(spacing: 20) {
                HStack(spacing: 24) {
                    UsageRingView(
                        used: subscriptionManager.scanUsage.scansThisWeek,
                        limit: subscriptionManager.isPlus ? nil : 5
                    )
                    .frame(width: 100, height: 100)

                    VStack(alignment: .leading, spacing: 12) {
                        if subscriptionManager.isPlus {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unlimited")
                                    .font(.manrope(size: 24, weight: .bold))
                                    .foregroundStyle(Color.brandTextPrimary)
                                Text("scans available")
                                    .font(.manrope(size: 14))
                                    .foregroundStyle(Color.brandTextSecondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(subscriptionManager.scansRemaining ?? 0)")
                                        .font(.manrope(size: 32, weight: .bold))
                                        .foregroundStyle(usageColor)
                                    Text("/ 5")
                                        .font(.manrope(size: 18, weight: .medium))
                                        .foregroundStyle(Color.brandTextTertiary)
                                }
                                Text("scans remaining")
                                    .font(.manrope(size: 14))
                                    .foregroundStyle(Color.brandTextSecondary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Resets \(nextResetText)")
                                    .font(.manrope(size: 12))
                            }
                            .foregroundStyle(Color.brandTextTertiary)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 8)

                if !subscriptionManager.isPlus {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.brandVibrantBlue)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Free Plan Limits")
                                    .font(.manrope(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.brandTextPrimary)

                                Text(
                                    "You can scan up to 5 receipts per week on the free plan. Your limit resets every Monday. Upgrade to Plus for unlimited scans."
                                )
                                .font(.manrope(size: 13))
                                .foregroundStyle(Color.brandTextSecondary)
                                .lineSpacing(2)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Weekly Usage")
        }
    }
}
