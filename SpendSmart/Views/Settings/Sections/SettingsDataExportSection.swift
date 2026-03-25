import SwiftUI

struct SettingsDataExportSection: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Binding var showExportSheet: Bool
    let onHaptic: () -> Void

    var body: some View {
        Section {
            Button {
                onHaptic()
                if subscriptionManager.isPlus {
                    showExportSheet = true
                } else {
                    subscriptionManager.presentPaywall(trigger: .featureLocked("Data Export"))
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(subscriptionManager.isPlus ? Color.brandSuccess.opacity(0.15) : Color.brandTextTertiary.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(subscriptionManager.isPlus ? Color.brandSuccess : Color.brandTextTertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Export Data")
                                .font(.manrope(size: 15, weight: .medium))
                                .foregroundStyle(Color.brandTextPrimary)

                            if !subscriptionManager.isPlus {
                                Text("PLUS")
                                    .font(.manrope(size: 9, weight: .bold))
                                    .foregroundStyle(Color.brandVibrantBlue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.brandAccentLight)
                                    )
                            }
                        }

                        Text("Export receipts as CSV or JSON")
                            .font(.manrope(size: 12))
                            .foregroundStyle(Color.brandTextSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        } header: {
            Text("Data")
        } footer: {
            if subscriptionManager.isPlus {
                Text("Export all your receipts for accounting or backup.")
            } else {
                Text("Upgrade to Plus to export your receipt data.")
            }
        }
    }
}
