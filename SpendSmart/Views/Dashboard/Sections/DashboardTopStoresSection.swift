import SwiftUI

struct DashboardTopStoresSection: View {
    let stores: [StoreSpending]
    @Binding var showAllStores: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Stores")
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)

                Spacer()

                if stores.count > 5 {
                    Button(action: onToggle) {
                        Text(showAllStores ? "Show Less" : "See All")
                            .font(.manrope(size: 13, weight: .medium))
                            .foregroundStyle(Color.brandVibrantBlue)
                    }
                }
            }

            let displayStores = showAllStores ? stores : Array(stores.prefix(5))

            VStack(spacing: 8) {
                ForEach(Array(displayStores.enumerated()), id: \.element.id) { index, store in
                    TopStoreRow(store: store, rank: index + 1)
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

private struct TopStoreRow: View {
    let store: StoreSpending
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            BrandLogoView(storeName: store.name, logoSearchTerm: store.name)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("\(rank)")
                .font(.ibmPlexMono(size: 12))
                .fontWeight(.bold)
                .foregroundStyle(rank <= 3 ? Color.brandVibrantBlue : Color.brandTextTertiary)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(rank <= 3 ? Color.brandAccentLight : Color.brandSurface)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(store.name)
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .lineLimit(1)

                Text("\(store.visitCount) visit\(store.visitCount == 1 ? "" : "s")")
                    .font(.manrope(size: 12, weight: .regular))
                    .foregroundStyle(Color.brandTextTertiary)
            }

            Spacer()

            Text(formatCurrency(store.totalSpent))
                .font(.ibmPlexMono(size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(Color.brandTextPrimary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brandBackground)
        )
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: CurrencyService.shared.preferredCurrency)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
