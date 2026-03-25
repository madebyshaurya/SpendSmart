import SwiftUI

struct ReceiptShareCard: View {
    let receipt: Receipt

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            itemsSection

            Divider()
                .overlay(Color.brandBorder)

            totalsSection

            if receipt.savings > 0 {
                savingsPill
            }

            brandingSection
        }
        .padding(20)
        .frame(width: 390, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.brandSurface.opacity(0.2))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandBorder, lineWidth: 1)
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(receipt.store_name.isEmpty ? "Unknown Store" : receipt.store_name)
                .font(.manrope(size: 22, weight: .bold))
                .foregroundStyle(Color.brandTextPrimary)

            Text(receipt.purchase_date.formatted(date: .long, time: .omitted))
                .font(.manrope(size: 14))
                .foregroundStyle(Color.brandTextSecondary)

            Divider()
                .overlay(Color.brandBorder)
        }
    }

    private var itemsSection: some View {
        VStack(spacing: 10) {
            ForEach(receipt.items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.name)
                        .font(.manrope(size: 14))
                        .foregroundStyle(Color.brandTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(priceText(for: item))
                            .font(.ibmPlexMono(size: 14))
                            .foregroundStyle(item.isDiscount ? Color.brandSuccess : Color.brandTextPrimary)

                        if let originalPrice = item.originalPrice, originalPrice > abs(item.price) {
                            Text(formatAmount(originalPrice))
                                .font(.ibmPlexMono(size: 12))
                                .foregroundStyle(Color.brandTextTertiary)
                                .strikethrough()
                        }
                    }
                }
            }
        }
    }

    private var totalsSection: some View {
        VStack(spacing: 8) {
            totalsRow(title: "Subtotal", value: formatAmount(receipt.total_amount - receipt.total_tax))
            totalsRow(title: "Tax", value: formatAmount(receipt.total_tax))

            HStack {
                Text("Total")
                    .font(.manrope(size: 16, weight: .bold))
                    .foregroundStyle(Color.brandTextPrimary)

                Spacer()

                Text(formatAmount(receipt.total_amount))
                    .font(.ibmPlexMono(size: 24))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandTextPrimary)
            }
        }
    }

    private var savingsPill: some View {
        Text("You saved \(formatAmount(receipt.savings))")
            .font(.manrope(size: 13, weight: .semibold))
            .foregroundStyle(Color.brandSuccess)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.brandSuccess.opacity(0.12))
            )
    }

    private var brandingSection: some View {
        HStack(spacing: 6) {
            Text("Tracked with SpendSmart")
                .font(.manrope(size: 11, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)

            Spacer()

            Text("SpendSmart")
                .font(.manrope(size: 11, weight: .bold))
                .foregroundStyle(Color.brandVibrantBlue)
        }
        .padding(.top, 2)
    }

    private func totalsRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.manrope(size: 14))
                .foregroundStyle(Color.brandTextSecondary)

            Spacer()

            Text(value)
                .font(.ibmPlexMono(size: 14))
                .foregroundStyle(Color.brandTextPrimary)
        }
    }

    private func priceText(for item: ReceiptItem) -> String {
        if item.isDiscount {
            return "-\(formatAmount(abs(item.price)))"
        }
        return formatAmount(item.price)
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = receipt.currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}
