import SwiftUI

struct RecentReceiptsSection: View {
    let receipts: [Receipt]
    let hasCloudWriteAccess: Bool
    @StateObject private var haptics = HapticManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Receipts")
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)

                Spacer()

                NavigationLink {
                    ReceiptsView()
                } label: {
                    Text("See All")
                        .font(.manrope(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandVibrantBlue)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        haptics.selection()
                    }
                )
            }

            VStack(spacing: 12) {
                ForEach(receipts.prefix(4)) { receipt in
                    NavigationLink {
                        ReceiptDetailView(
                            receipt: receipt,
                            isLocal: !hasCloudWriteAccess,
                            onDelete: {},
                            onUpdate: { _ in }
                        )
                    } label: {
                        EnhancedReceiptRow(receipt: receipt)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            haptics.selection()
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
}
