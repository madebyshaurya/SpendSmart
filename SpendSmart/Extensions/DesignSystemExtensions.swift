import SwiftUI

// MARK: - Design System Extensions

extension View {
    /// Applies consistent form section styling
    func formSectionStyle() -> some View {
        self
            .padding(DesignTokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.05),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
    }
    
    /// Applies consistent card styling
    func cardStyle(level: CardLevel = .primary) -> some View {
        self.modifier(CardStyleModifier(level: level))
    }
    
    /// Applies consistent field container styling
    func fieldContainerStyle(isFocused: Bool = false, tint: Color = .blue, hasError: Bool = false) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                hasError ? .red : (isFocused ? tint : Color.clear),
                                lineWidth: hasError ? 2 : (isFocused ? 2 : 0)
                            )
                    )
            )
    }
    
    /// Applies consistent button styling
    func buttonStyle(style: ButtonStyleType, size: ButtonSize = .medium) -> some View {
        self.modifier(ButtonStyleModifier(style: style, size: size))
    }
    
    /// Applies consistent validation styling
    func validationStyle(isValid: Bool, hasBeenInteracted: Bool = false) -> some View {
        self.modifier(ValidationStyleModifier(isValid: isValid, hasBeenInteracted: hasBeenInteracted))
    }
    
    /// Applies semantic spacing
    func semanticSpacing(type: SpacingType) -> some View {
        self.modifier(SemanticSpacingModifier(type: type))
    }
}

// MARK: - Supporting Types

enum CardLevel {
    case primary
    case secondary
    case tertiary
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return Color(.systemBackground)
        case .secondary:
            return Color(.secondarySystemBackground)
        case .tertiary:
            return Color(.tertiarySystemBackground)
        }
    }
    
    var shadowOpacity: Double {
        switch self {
        case .primary: return 0.1
        case .secondary: return 0.05
        case .tertiary: return 0.03
        }
    }
}

enum ButtonStyleType {
    case primary
    case secondary
    case tertiary
    case destructive
    
    var backgroundColor: Color {
        switch self {
        case .primary: return .blue
        case .secondary: return Color(.systemGray5)
        case .tertiary: return Color.clear
        case .destructive: return .red
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary, .destructive: return .white
        case .secondary, .tertiary: return .primary
        }
    }
}

enum ButtonSize {
    case small
    case medium
    case large
    
    var padding: EdgeInsets {
        switch self {
        case .small: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        case .medium: return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        case .large: return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        }
    }
}

enum SpacingType {
    case field
    case section
    case page
    
    var value: CGFloat {
        switch self {
        case .field: return DesignTokens.Spacing.sm
        case .section: return DesignTokens.Spacing.lg
        case .page: return DesignTokens.Spacing.xl
        }
    }
}

// MARK: - Style Modifiers

struct CardStyleModifier: ViewModifier {
    let level: CardLevel
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(level.backgroundColor)
                    .shadow(
                        color: Color.black.opacity(level.shadowOpacity),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
            )
    }
}

struct ButtonStyleModifier: ViewModifier {
    let style: ButtonStyleType
    let size: ButtonSize
    
    func body(content: Content) -> some View {
        content
            .font(.instrumentSans(size: size.fontSize, weight: .semibold))
            .foregroundColor(style.foregroundColor)
            .padding(size.padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(style.backgroundColor)
            )
            .pressAnimation()
    }
}

struct ValidationStyleModifier: ViewModifier {
    let isValid: Bool
    let hasBeenInteracted: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // Validation border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        hasBeenInteracted ? (isValid ? .green : .red) : Color.clear,
                        lineWidth: hasBeenInteracted ? 2 : 0
                    )
            )
    }
}

struct SemanticSpacingModifier: ViewModifier {
    let type: SpacingType
    
    func body(content: Content) -> some View {
        content
            .padding(.vertical, type.value)
    }
}

// MARK: - Design Tokens Helper

extension DesignTokens {
    struct FormValidation {
        static let errorColor = Color.red
        static let successColor = Color.green
        static let warningColor = Color.orange
        
        static let errorBackground = Color.red.opacity(0.1)
        static let successBackground = Color.green.opacity(0.1)
        static let warningBackground = Color.orange.opacity(0.1)
    }
    
    struct Interaction {
        static let pressScale: CGFloat = 0.95
        static let hoverOpacity: Double = 0.8
        static let disabledOpacity: Double = 0.5
    }
    
    struct AnimationTimings {
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
    }
}

// MARK: - Utility Extensions

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}