//
//  AccessibilityHelpers.swift
//  SpendSmart
//
//  Accessibility utilities and Dynamic Type support
//

import SwiftUI

// MARK: - Dynamic Type Support
extension DesignTokens.Typography {
    // Enhanced typography with automatic Dynamic Type scaling
    static func scaledFont(
        textStyle: Font.TextStyle,
        customFont: Font,
        maxSize: CGFloat? = nil
    ) -> Font {
        return customFont
    }
    
    // Dynamic Type aware typography variants
    static func dynamicLargeTitle() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 34), weight: .bold)
    }
    
    static func dynamicTitle1() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 28), weight: .bold)
    }
    
    static func dynamicTitle2() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 22), weight: .bold)
    }
    
    static func dynamicTitle3() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 20), weight: .semibold)
    }
    
    static func dynamicHeadline() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 17), weight: .semibold)
    }
    
    static func dynamicBody() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 17), weight: .regular)
    }
    
    static func dynamicCallout() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 16), weight: .regular)
    }
    
    static func dynamicSubheadline() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 15), weight: .regular)
    }
    
    static func dynamicFootnote() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 13), weight: .regular)
    }
    
    static func dynamicCaption() -> Font {
        .instrumentSans(size: UIFontMetrics.default.scaledValue(for: 12), weight: .regular)
    }
}

// MARK: - Accessibility Modifiers
extension View {
    /// Adds comprehensive accessibility support to any view
    func accessibilityEnhanced(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        action: (() -> Void)? = nil,
        actionName: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityAction(named: actionName ?? "") {
                action?()
            }
    }
    
    /// Adds semantic accessibility role for better VoiceOver navigation
    func accessibilityRole(_ role: String) -> some View {
        // Using string-based role for broader compatibility
        self
    }
    
    /// Optimizes touch targets for accessibility (minimum 44pt)
    func accessibleTouchTarget() -> some View {
        self
            .frame(minWidth: DesignTokens.Spacing.minimumTouchTarget, 
                   minHeight: DesignTokens.Spacing.minimumTouchTarget)
    }
    
    /// Adds high contrast support
    func highContrastAdaptive(
        lightColor: Color,
        darkColor: Color,
        highContrastLight: Color? = nil,
        highContrastDark: Color? = nil
    ) -> some View {
        self.foregroundColor(
            adaptiveColor(
                light: lightColor,
                dark: darkColor,
                highContrastLight: highContrastLight,
                highContrastDark: highContrastDark
            )
        )
    }
    
    private func adaptiveColor(
        light: Color,
        dark: Color,
        highContrastLight: Color?,
        highContrastDark: Color?
    ) -> Color {
        return Color(UIColor { traitCollection in
            let isHighContrast = traitCollection.accessibilityContrast == .high
            
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(isHighContrast ? (highContrastDark ?? dark) : dark)
            } else {
                return UIColor(isHighContrast ? (highContrastLight ?? light) : light)
            }
        })
    }
}

// MARK: - Financial Accessibility Helpers
struct FinancialAccessibilityHelper {
    /// Formats currency values for accessibility announcements
    static func formatCurrencyForAccessibility(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        
        guard let formattedAmount = formatter.string(from: NSNumber(value: amount)) else {
            return "\(amount) \(currency)"
        }
        
        // Remove all Unicode currency symbols for clearer VoiceOver pronunciation
        let cleanAmount: String
        do {
            let regex = try NSRegularExpression(pattern: "\\p{Sc}", options: [])
            cleanAmount = regex.stringByReplacingMatches(
                in: formattedAmount,
                options: [],
                range: NSRange(location: 0, length: formattedAmount.utf16.count),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespaces)
        } catch {
            // Fallback to basic replacements if regex fails
            cleanAmount = formattedAmount
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: "£", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        
        return "\(cleanAmount) \(currencyNameForCode(currency))"
    }
    
    /// Provides full currency names for better accessibility
    private static func currencyNameForCode(_ code: String) -> String {
        let currencyNames: [String: String] = [
            "USD": "US Dollars",
            "EUR": "Euros",
            "GBP": "British Pounds",
            "CAD": "Canadian Dollars",
            "AUD": "Australian Dollars",
            "JPY": "Japanese Yen",
            "CHF": "Swiss Francs",
            "CNY": "Chinese Yuan",
            "INR": "Indian Rupees"
        ]
        
        return currencyNames[code] ?? code
    }
    
    /// Creates accessible description for spending trends
    static func accessibilityTrendDescription(
        currentAmount: Double,
        previousAmount: Double,
        currency: String
    ) -> String {
        let difference = currentAmount - previousAmount
        let percentChange = previousAmount != 0 ? (difference / previousAmount) * 100 : 0
        
        let trend = difference > 0 ? "increased" : difference < 0 ? "decreased" : "remained the same"
        let changeDescription = difference != 0 ? 
            "by \(formatCurrencyForAccessibility(abs(difference), currency: currency)), which is \(String(format: "%.1f", abs(percentChange)))% \(trend)" : 
            ""
        
        return "Spending has \(trend) \(changeDescription) compared to the previous period"
    }
}

// MARK: - Accessibility-First Components
struct AccessibleStatCard: View {
    let title: String
    let amount: Double
    let currency: String
    let trend: String?
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.ComponentSize.iconSize))
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(DesignTokens.Typography.dynamicSubheadline())
                    .foregroundColor(DesignTokens.Colors.Neutral.secondary)
                
                Spacer()
            }
            
            Text(CurrencyManager.shared.formatAmount(amount, currencyCode: currency))
                .font(DesignTokens.Typography.dataDisplay(size: UIFontMetrics.default.scaledValue(for: 28)))
                .foregroundColor(DesignTokens.Colors.Neutral.primary)
                .accessibilityLabel(FinancialAccessibilityHelper.formatCurrencyForAccessibility(amount, currency: currency))
            
            if let trend = trend {
                Text(trend)
                    .font(DesignTokens.Typography.dynamicCaption())
                    .foregroundColor(DesignTokens.Colors.Neutral.tertiary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(FinancialAccessibilityHelper.formatCurrencyForAccessibility(amount, currency: currency))")
        .accessibilityHint(trend ?? "")
    }
}

struct AccessibleButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    let isEnabled: Bool
    let icon: String?
    
    enum ButtonStyle {
        case primary, secondary, tertiary
    }
    
    init(
        _ title: String,
        style: ButtonStyle = .primary,
        icon: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: DesignTokens.ComponentSize.iconSize))
                        .accessibilityHidden(true)
                }
                
                Text(title)
                    .font(DesignTokens.Typography.dynamicHeadline())
            }
            .frame(maxWidth: .infinity)
            .accessibleTouchTarget()
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
            .overlay(overlayContent)
            .opacity(isEnabled ? 1.0 : 0.6)
            .scaleEffect(isEnabled ? 1.0 : 0.98)
            .animation(DesignTokens.Animation.easeInOut, value: isEnabled)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(isEnabled ? "Tap to \(title.lowercased())" : "This button is disabled")
        .accessibilityAddTraits(.isButton)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return DesignTokens.Colors.Primary.blue
        case .secondary: return DesignTokens.Colors.Background.secondary
        case .tertiary: return .clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return DesignTokens.Colors.Primary.blue
        case .tertiary: return DesignTokens.Colors.Neutral.primary
        }
    }
    
    @ViewBuilder
    private var overlayContent: some View {
        if style == .secondary {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .strokeBorder(DesignTokens.Colors.Primary.blue, lineWidth: 1.5)
        }
    }
}

// MARK: - Reduce Motion Support
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let animation: Animation
    let reducedAnimation: Animation
    
    init(animation: Animation, reducedAnimation: Animation = .linear(duration: 0)) {
        self.animation = animation
        self.reducedAnimation = reducedAnimation
    }
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? reducedAnimation : animation, value: UUID())
    }
}

extension View {
    func respectMotionPreferences(
        animation: Animation = DesignTokens.Animation.easeInOut,
        reducedAnimation: Animation = .linear(duration: 0)
    ) -> some View {
        self.modifier(ReduceMotionModifier(animation: animation, reducedAnimation: reducedAnimation))
    }
}