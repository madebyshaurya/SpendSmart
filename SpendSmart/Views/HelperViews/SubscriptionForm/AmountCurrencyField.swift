import SwiftUI

struct AmountCurrencyField: View {
    @Binding var amount: String
    @Binding var currency: String
    var allCurrencies: [String]
    var tint: Color = .blue

    @State private var showCurrencyPicker = false

    var body: some View {
        HStack(spacing: 12) {
            SubscriptionAnimatedTextField(
                title: "Amount",
                text: $amount,
                placeholder: "0.00",
                systemImage: "dollarsign.circle",
                keyboardType: .decimalPad,
                tint: tint,
                isRequired: true,
                validationMessage: validateAmount(amount),
                isValid: isValidAmount(amount),
                maxLength: 10
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Currency")
                    .font(.instrumentSans(size: 13))
                    .foregroundColor(.secondary)
                Button(action: {
                    withAnimation(.spring()) { showCurrencyPicker.toggle() }
                }) {
                    HStack {
                        Image(systemName: "coloncurrencysign.circle")
                            .foregroundColor(.secondary)
                        Text(currency)
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(showCurrencyPicker ? 180 : 0))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                }

                if showCurrencyPicker {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(allCurrencies, id: \.self) { curr in
                                Button(action: {
                                    currency = curr
                                    withAnimation(.spring()) { showCurrencyPicker = false }
                                }) {
                                    Text(curr)
                                        .font(.instrumentSans(size: 14, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule().fill(currency == curr ? tint.opacity(0.18) : Color.white.opacity(0.06))
                                        )
                                        .overlay(
                                            Capsule().stroke(currency == curr ? tint.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                        .foregroundColor(currency == curr ? tint : .primary)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
    
    // MARK: - Validation Helper Functions
    private func validateAmount(_ amount: String) -> String? {
        let trimmed = amount.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            return "Amount is required"
        }
        
        guard let value = Double(trimmed) else {
            return "Please enter a valid amount"
        }
        
        if value <= 0 {
            return "Amount must be greater than 0"
        }
        
        if value > 999999.99 {
            return "Amount cannot exceed $999,999.99"
        }
        
        return nil
    }
    
    private func isValidAmount(_ amount: String) -> Bool {
        let trimmed = amount.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        guard let value = Double(trimmed) else { return false }
        return value > 0 && value <= 999999.99
    }
}


