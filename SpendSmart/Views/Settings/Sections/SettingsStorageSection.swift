import SwiftUI

struct SettingsStorageSection: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var localStorage: LocalReceiptStorage

    @Binding var showSyncConfirmation: Bool

    let onHaptic: () -> Void
    let onUpgradeTapped: (() -> Void)?

    var body: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brandWarning.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "iphone")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.brandWarning)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Receipts")
                        .font(.manrope(size: 15, weight: .medium))
                        .foregroundStyle(Color.brandTextPrimary)

                    Text("On this device only")
                        .font(.manrope(size: 12))
                        .foregroundStyle(Color.brandTextSecondary)
                }

                Spacer()

                Text("\(localStorage.localReceipts.count)")
                    .font(.manrope(size: 18, weight: .bold))
                    .foregroundStyle(localStorage.localReceipts.count > 0 ? Color.brandWarning : Color.brandTextTertiary)
            }
            .padding(.vertical, 4)

            if !subscriptionManager.isPlus && localStorage.localReceipts.count > 0 {
                Button {
                    onHaptic()
                    if let onUpgradeTapped {
                        onUpgradeTapped()
                    } else {
                        subscriptionManager.presentPaywall(trigger: .featureLocked("Cloud Sync"))
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath.cloud")
                            .font(.system(size: 15, weight: .medium))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync to Cloud")
                                .font(.manrope(size: 14, weight: .semibold))

                            Text(
                                "Upgrade to backup \(localStorage.localReceipts.count) receipt\(localStorage.localReceipts.count == 1 ? "" : "s")"
                            )
                            .font(.manrope(size: 11))
                            .foregroundStyle(Color.brandTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(Color.brandVibrantBlue)
                }
            }

            if subscriptionManager.isPlus && localStorage.localReceipts.count > 0 {
                Button {
                    onHaptic()
                    showSyncConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath.cloud.fill")
                            .font(.system(size: 15, weight: .medium))

                        Text(
                            "Sync \(localStorage.localReceipts.count) Receipt\(localStorage.localReceipts.count == 1 ? "" : "s") Now"
                        )
                        .font(.manrope(size: 14, weight: .semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(Color.brandVibrantBlue)
                }
            }
        } header: {
            Text("Receipt Storage")
        } footer: {
            if subscriptionManager.isPlus {
                Text("New receipts are automatically synced to the cloud.")
            } else {
                Text("Free users: new receipts are saved locally. Upgrade to Plus for cloud backup.")
            }
        }
        .fullScreenCover(isPresented: $showSyncConfirmation) {
            SyncConfirmationView {
                // Caller refreshes data if needed
            }
        }
    }
}
