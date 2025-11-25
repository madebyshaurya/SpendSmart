import SwiftUI

struct SubscriptionSummaryView: View {
    @StateObject private var currencyManager = CurrencyManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.colorScheme) private var colorScheme
    var onManageTap: (() -> Void)?

    var body: some View {
        let monthly = subscriptionService.monthlyCost(inPreferredCurrency: currencyManager.preferredCurrency, converter: currencyManager.convertAmountSync)
        let yearly = subscriptionService.yearlyCost(inPreferredCurrency: currencyManager.preferredCurrency, converter: currencyManager.convertAmountSync)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Subscriptions", systemImage: "rectangle.stack.badge.person.crop")
                    .font(.instrumentSans(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                if let onManageTap = onManageTap {
                    Button(action: onManageTap) {
                        Text("Manage")
                            .font(.instrumentSans(size: 14, weight: .semibold))
                    }
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Monthly")
                        .font(.instrumentSans(size: 12))
                        .foregroundColor(.secondary)
                    Text(currencyManager.formatAmount(monthly, currencyCode: currencyManager.preferredCurrency))
                        .font(.spaceGrotesk(size: 22, weight: .bold))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(colorScheme == .dark ? Color.purple.opacity(0.18) : Color.purple.opacity(0.12)))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Yearly")
                        .font(.instrumentSans(size: 12))
                        .foregroundColor(.secondary)
                    Text(currencyManager.formatAmount(yearly, currencyCode: currencyManager.preferredCurrency))
                        .font(.spaceGrotesk(size: 22, weight: .bold))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(colorScheme == .dark ? Color.teal.opacity(0.18) : Color.teal.opacity(0.12)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}


