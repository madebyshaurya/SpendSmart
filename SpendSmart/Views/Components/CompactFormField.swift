import SwiftUI

struct CompactFormField: View {
    var label: String
    @Binding var text: String
    var placeholder: String = ""
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var isRequired: Bool = false
    var validationMessage: String? = nil
    var maxLength: Int? = nil
    
    @FocusState private var isFocused: Bool
    @State private var hasBeenInteracted = false
    
    private var isValid: Bool {
        if isRequired {
            return !text.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }
    
    private var showValidation: Bool {
        hasBeenInteracted && (!isValid || validationMessage != nil)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Icon and label in compact row
                HStack(spacing: 6) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundColor(isFocused ? DesignTokens.Colors.Primary.blue : .secondary)
                            .frame(width: 16)
                    }
                    
                    AdaptiveText(
                        text: label + (isRequired ? " *" : ""),
                        font: DesignTokens.Typography.caption1(weight: .medium),
                        color: showValidation ? .red : .secondary,
                        priority: .normal
                    )
                    
                    Spacer()
                    
                    // Validation indicator
                    if hasBeenInteracted && !text.isEmpty {
                        Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isValid ? .green : .red)
                    }
                }
                .frame(height: 20)
                
                // Input field
                TextField(placeholder, text: $text)
                    .font(DesignTokens.Typography.body(weight: .regular))
                    .keyboardType(keyboardType)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                            .fill(DesignTokens.Colors.Fill.secondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                                    .stroke(
                                        isFocused 
                                            ? DesignTokens.Colors.Primary.blue 
                                            : (showValidation ? .red : Color.clear),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .frame(minWidth: 100)
                    .onChange(of: isFocused) { _, newValue in
                        if !newValue && !text.isEmpty {
                            hasBeenInteracted = true
                        }
                    }
                    .onChange(of: text) { _, newValue in
                        if !newValue.isEmpty {
                            hasBeenInteracted = true
                        }
                        if let maxLength = maxLength, newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            }
            
            // Validation message
            if let validationMessage = validationMessage, showValidation {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    
                    AdaptiveText(
                        text: validationMessage,
                        font: DesignTokens.Typography.caption2(weight: .regular),
                        color: .red,
                        priority: .low
                    )
                }
                .transition(.opacity)
            }
        }
    }
}

struct InlineAmountField: View {
    @Binding var amount: String
    @Binding var currency: String
    var currencies: [String]
    var label: String = "Amount"
    var isRequired: Bool = true
    
    @State private var showCurrencyPicker = false
    @FocusState private var isFocused: Bool
    @State private var hasBeenInteracted = false
    
    private var isValid: Bool {
        guard !amount.isEmpty else { return !isRequired }
        guard let value = Double(amount) else { return false }
        return value > 0
    }
    
    private var showValidation: Bool {
        hasBeenInteracted && !isValid
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Label
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 14))
                        .foregroundColor(isFocused ? DesignTokens.Colors.Primary.blue : .secondary)
                        .frame(width: 16)
                    
                    AdaptiveText(
                        text: label + (isRequired ? " *" : ""),
                        font: DesignTokens.Typography.caption1(weight: .medium),
                        color: showValidation ? .red : .secondary,
                        priority: .normal
                    )
                    
                    Spacer()
                }
                .frame(height: 20)
                
                // Currency selector
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showCurrencyPicker.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currency)
                            .font(DesignTokens.Typography.caption1(weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(showCurrencyPicker ? 180 : 0))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Colors.Fill.tertiary)
                    )
                }
                .buttonStyle(.plain)
                
                // Amount input
                TextField("0.00", text: $amount)
                    .font(.system(.body, design: .monospaced))
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                            .fill(DesignTokens.Colors.Fill.secondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                                    .stroke(
                                        isFocused 
                                            ? DesignTokens.Colors.Primary.blue 
                                            : (showValidation ? .red : Color.clear),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .frame(width: 80)
                    .onChange(of: isFocused) { _, newValue in
                        if !newValue && !amount.isEmpty {
                            hasBeenInteracted = true
                        }
                    }
                    .onChange(of: amount) { _, newValue in
                        if !newValue.isEmpty {
                            hasBeenInteracted = true
                        }
                        // Filter to only allow numbers and decimal point
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if filtered != newValue {
                            amount = filtered
                        }
                        // Prevent multiple decimal points
                        let components = filtered.components(separatedBy: ".")
                        if components.count > 2 {
                            amount = components[0] + "." + components[1]
                        }
                    }
                
                // Validation indicator
                if hasBeenInteracted && !amount.isEmpty {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isValid ? .green : .red)
                }
            }
            
            // Currency picker
            if showCurrencyPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(currencies.prefix(8), id: \.self) { curr in
                            Button(curr) {
                                currency = curr
                                withAnimation(.spring(response: 0.3)) {
                                    showCurrencyPicker = false
                                }
                            }
                            .font(DesignTokens.Typography.caption2(weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(currency == curr 
                                        ? DesignTokens.Colors.Primary.blue.opacity(0.2) 
                                        : DesignTokens.Colors.Fill.tertiary)
                            )
                            .foregroundColor(currency == curr ? DesignTokens.Colors.Primary.blue : .secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 32)
                .transition(.opacity.combined(with: .offset(y: -10)))
            }
            
            // Validation message
            if showValidation {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    
                    AdaptiveText(
                        text: "Please enter a valid amount",
                        font: DesignTokens.Typography.caption2(weight: .regular),
                        color: .red,
                        priority: .low
                    )
                }
                .transition(.opacity)
            }
        }
    }
}

struct ToggleChip: View {
    var label: String
    var systemImage: String
    @Binding var isOn: Bool
    var tint: Color = DesignTokens.Colors.Primary.blue
    var description: String? = nil
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(isOn ? .white : tint)
                
                VStack(alignment: .leading, spacing: 1) {
                    AdaptiveText(
                        text: label,
                        font: DesignTokens.Typography.caption1(weight: .medium),
                        color: isOn ? .white : .primary,
                        priority: .normal
                    )
                    
                    if let description = description {
                        AdaptiveText(
                            text: description,
                            font: DesignTokens.Typography.caption2(weight: .regular),
                            color: isOn ? .white.opacity(0.8) : .secondary,
                            priority: .low
                        )
                    }
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isOn ? .white : tint.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(isOn ? tint : DesignTokens.Colors.Fill.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(isOn ? Color.clear : tint.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct CompactDatePicker: View {
    var label: String
    @Binding var date: Date
    var minDate: Date? = nil
    var maxDate: Date? = nil
    var icon: String = "calendar"
    
    @State private var showDatePicker = false
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showDatePicker.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    
                    AdaptiveText(
                        text: label,
                        font: DesignTokens.Typography.caption1(weight: .medium),
                        color: .secondary,
                        priority: .normal
                    )
                    
                    Spacer()
                    
                    AdaptiveText(
                        text: formattedDate,
                        font: DesignTokens.Typography.body(weight: .regular),
                        color: .primary,
                        priority: .normal
                    )
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                        .fill(DesignTokens.Colors.Fill.secondary)
                )
            }
            .buttonStyle(.plain)
            
            if showDatePicker {
                DatePicker("", selection: $date, in: (minDate ?? Date.distantPast)...(maxDate ?? Date.distantFuture), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .transition(.opacity.combined(with: .offset(y: -10)))
            }
        }
    }
}