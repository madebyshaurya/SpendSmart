import SwiftUI

struct SmartNumberText: View {
    let value: Double
    var currency: String? = nil
    var font: Font = DesignTokens.Typography.dataDisplay(size: 17)
    var color: Color = DesignTokens.Colors.Neutral.primary
    var showCurrency: Bool = true
    var priority: AdaptiveText.TextPriority = .high
    var decimalPlaces: Int = 2
    var minimumIntegerDigits: Int = 1
    
    private var formattedText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        formatter.minimumIntegerDigits = minimumIntegerDigits
        formatter.usesGroupingSeparator = true
        
        let numberString = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        
        if let currency = currency, showCurrency {
            return "\(currency) \(numberString)"
        } else {
            return numberString
        }
    }
    
    var body: some View {
        AdaptiveText(
            text: formattedText,
            font: font,
            minimumScaleFactor: priority.scaleFactor,
            lineLimit: 1,
            multilineTextAlignment: .leading,
            color: color,
            priority: priority
        )
    }
}

struct SmartNumberField: View {
    @Binding var value: String
    var currency: String? = nil
    var placeholder: String = "0.00"
    var font: Font = DesignTokens.Typography.body()
    var showCurrency: Bool = true
    var isValid: Bool = true
    var validationMessage: String? = nil
    
    @FocusState private var isFocused: Bool
    @State private var hasBeenInteracted = false
    
    private var displayText: String {
        if value.isEmpty && !isFocused {
            return ""
        }
        
        if let currency = currency, showCurrency && !value.isEmpty {
            return "\(currency) \(value)"
        }
        
        return value
    }
    
    private var showValidation: Bool {
        hasBeenInteracted && (!isValid || validationMessage != nil)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                if value.isEmpty && !isFocused {
                    HStack {
                        if let currency = currency, showCurrency {
                            Text(currency)
                                .font(font)
                                .foregroundColor(DesignTokens.Colors.Neutral.tertiary)
                        }
                        Text(placeholder)
                            .font(font)
                            .foregroundColor(DesignTokens.Colors.Neutral.tertiary)
                    }
                }
                
                HStack(spacing: 4) {
                    if let currency = currency, showCurrency && (!value.isEmpty || isFocused) {
                        Text(currency)
                            .font(font)
                            .foregroundColor(isFocused ? DesignTokens.Colors.Primary.blue : .secondary)
                            .animation(.spring(response: 0.3), value: isFocused)
                    }
                    
                    TextField("", text: $value)
                        .font(.system(.body, design: .monospaced))
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .onChange(of: isFocused) { _, newValue in
                            if !newValue && !value.isEmpty {
                                hasBeenInteracted = true
                            }
                        }
                        .onChange(of: value) { _, newValue in
                            if !newValue.isEmpty {
                                hasBeenInteracted = true
                            }
                            // Ensure numeric input only
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                value = filtered
                            }
                            // Prevent multiple decimal points
                            let components = filtered.components(separatedBy: ".")
                            if components.count > 2 {
                                value = components[0] + "." + components[1]
                            }
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(DesignTokens.Colors.Fill.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(
                                isFocused 
                                    ? DesignTokens.Colors.Primary.blue 
                                    : (showValidation ? .red : Color.clear),
                                lineWidth: isFocused ? 2 : (showValidation ? 1 : 0)
                            )
                    )
            )
            
            if let validationMessage = validationMessage, showValidation {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    
                    Text(validationMessage)
                        .font(DesignTokens.Typography.caption2(weight: .regular))
                        .foregroundColor(.red)
                }
                .transition(.opacity.combined(with: .offset(y: -5)))
            }
        }
    }
}

struct CurrencyAmountDisplay: View {
    let amount: Double
    let currency: String
    var size: DisplaySize = .medium
    var color: Color = DesignTokens.Colors.Neutral.primary
    var showPositiveSign: Bool = false
    
    enum DisplaySize {
        case small, medium, large, extraLarge
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 17
            case .large: return 24
            case .extraLarge: return 32
            }
        }
        
        var priority: AdaptiveText.TextPriority {
            switch self {
            case .small: return .normal
            case .medium: return .high
            case .large: return .critical
            case .extraLarge: return .critical
            }
        }
    }
    
    
    var body: some View {
        SmartNumberText(
            value: amount,
            currency: currency,
            font: DesignTokens.Typography.dataDisplay(size: size.fontSize),
            color: color,
            priority: size.priority
        )
    }
}

extension SmartNumberText {
    static func currency(_ amount: Double, currency: String, size: CurrencyAmountDisplay.DisplaySize = .medium) -> some View {
        CurrencyAmountDisplay(amount: amount, currency: currency, size: size)
    }
    
    static func percentage(_ value: Double, decimalPlaces: Int = 1) -> SmartNumberText {
        SmartNumberText(
            value: value,
            currency: nil,
            font: DesignTokens.Typography.dataDisplay(size: 17),
            showCurrency: false,
            priority: .high,
            decimalPlaces: decimalPlaces
        )
    }
    
    static func count(_ value: Int) -> SmartNumberText {
        SmartNumberText(
            value: Double(value),
            currency: nil,
            font: DesignTokens.Typography.dataDisplay(size: 17),
            showCurrency: false,
            priority: .high,
            decimalPlaces: 0
        )
    }
}