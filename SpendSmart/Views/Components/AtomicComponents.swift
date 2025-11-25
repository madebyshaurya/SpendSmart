//
//  AtomicComponents.swift
//  SpendSmart
//
//  Apple HIG-inspired atomic components for consistent UI
//

import SwiftUI

// MARK: - Buttons
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    let icon: String?
    
    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: DesignTokens.ComponentSize.iconSize, weight: .medium))
                    }
                    
                    Text(title)
                        .font(DesignTokens.Typography.headline())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.ComponentSize.buttonHeight)
            .background(
                Group {
                    if isDisabled {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(DesignTokens.Colors.Fill.tertiary)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.blue.gradient)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
            )
            .foregroundColor(isDisabled ? DesignTokens.Colors.Neutral.tertiary : .white)
            .scaleEffect(isDisabled ? 0.98 : 1.0)
            .animation(DesignTokens.Animation.easeInOut, value: isDisabled)
        }
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "")
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    let isDisabled: Bool
    let icon: String?
    
    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: DesignTokens.ComponentSize.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(DesignTokens.Typography.headline())
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.ComponentSize.buttonHeight)
            .background(DesignTokens.Colors.Background.secondary)
            .foregroundColor(isDisabled ? DesignTokens.Colors.Neutral.tertiary : DesignTokens.Colors.Primary.blue)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .strokeBorder(
                        isDisabled ? DesignTokens.Colors.Fill.tertiary : DesignTokens.Colors.Primary.blue,
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
            .scaleEffect(isDisabled ? 0.98 : 1.0)
            .animation(DesignTokens.Animation.easeInOut, value: isDisabled)
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void
    let size: IconButtonSize
    let style: IconButtonStyle
    
    enum IconButtonSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return DesignTokens.ComponentSize.smallIconSize
            case .medium: return DesignTokens.ComponentSize.iconSize
            case .large: return DesignTokens.ComponentSize.largeIconSize
            }
        }
        
        var buttonSize: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }
    }
    
    enum IconButtonStyle {
        case filled, outlined, plain
    }
    
    init(
        icon: String,
        size: IconButtonSize = .medium,
        style: IconButtonStyle = .filled,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: size.buttonSize, height: size.buttonSize)
                .background(backgroundColor)
                .overlay(overlayContent)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
        }
        .accessibilityLabel(icon)
    }
    
    private var foregroundColor: Color {
        switch style {
        case .filled: return .white
        case .outlined: return DesignTokens.Colors.Primary.blue
        case .plain: return DesignTokens.Colors.Neutral.primary
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .filled: return DesignTokens.Colors.Primary.blue
        case .outlined: return .clear
        case .plain: return DesignTokens.Colors.Fill.secondary
        }
    }
    
    @ViewBuilder
    private var overlayContent: some View {
        if style == .outlined {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                .strokeBorder(DesignTokens.Colors.Primary.blue, lineWidth: 1.5)
        }
    }
}

// MARK: - Cards
struct ContentCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    
    init(padding: CGFloat = DesignTokens.Spacing.cardPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(DesignTokens.Colors.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
            .designSystemShadow(DesignTokens.Shadow.md)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let trend: StatCardTrend?
    
    enum StatCardTrend {
        case up(String), down(String), neutral(String)
        
        var color: Color {
            switch self {
            case .up: return DesignTokens.Colors.Semantic.success
            case .down: return DesignTokens.Colors.Semantic.error
            case .neutral: return DesignTokens.Colors.Neutral.secondary
            }
        }
        
        var text: String {
            switch self {
            case .up(let text), .down(let text), .neutral(let text):
                return text
            }
        }
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
    }
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        iconColor: Color = DesignTokens.Colors.Primary.blue,
        trend: StatCardTrend? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.trend = trend
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.ComponentSize.iconSize))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(DesignTokens.Typography.subheadline())
                    .foregroundColor(DesignTokens.Colors.Neutral.secondary)
                
                Spacer()
                
                if let trend = trend {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: trend.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(trend.text)
                            .font(DesignTokens.Typography.caption1(weight: .medium))
                    }
                    .foregroundColor(trend.color)
                }
            }
            
            Text(value)
                .font(DesignTokens.Typography.dataDisplay(size: 28, weight: .bold))
                .foregroundColor(DesignTokens.Colors.Neutral.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DesignTokens.Typography.caption1())
                    .foregroundColor(DesignTokens.Colors.Neutral.tertiary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.Background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
        .designSystemShadow(DesignTokens.Shadow.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(subtitle ?? "")
    }
}

// MARK: - Form Components
struct DesignSystemTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let errorMessage: String?
    
    init(
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        errorMessage: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.errorMessage = errorMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: DesignTokens.ComponentSize.iconSize))
                        .foregroundColor(DesignTokens.Colors.Neutral.secondary)
                        .frame(width: 24)
                }
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(textContentType)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                }
            }
            .font(DesignTokens.Typography.body())
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.Background.secondary)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .strokeBorder(
                        errorMessage != nil ? DesignTokens.Colors.Semantic.error : DesignTokens.Colors.Fill.tertiary,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(DesignTokens.Typography.caption1())
                    .foregroundColor(DesignTokens.Colors.Semantic.error)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Loading States
struct LoadingCard: View {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.Primary.blue))
                .scaleEffect(1.2)
            
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.headline())
                    .foregroundColor(DesignTokens.Colors.Neutral.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.subheadline())
                        .foregroundColor(DesignTokens.Colors.Neutral.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(DesignTokens.Spacing.xxxl)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.Colors.Background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
        .designSystemShadow(DesignTokens.Shadow.md)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "Loading content")
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignTokens.Colors.Neutral.tertiary)
            
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.title3())
                    .foregroundColor(DesignTokens.Colors.Neutral.primary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(DesignTokens.Typography.subheadline())
                    .foregroundColor(DesignTokens.Colors.Neutral.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                SecondaryButton(actionTitle, action: action)
                    .frame(maxWidth: 200)
            }
        }
        .padding(DesignTokens.Spacing.xxxl)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.Colors.Background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
        .designSystemShadow(DesignTokens.Shadow.md)
    }
}