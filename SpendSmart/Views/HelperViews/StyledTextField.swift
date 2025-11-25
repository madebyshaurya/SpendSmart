import SwiftUI

struct StyledTextField: View {
    var title: String
    @Binding var text: String
    var placeholder: String
    var systemImage: String
    var keyboardType: UIKeyboardType = .default
    var errorMessage: String? = nil
    var isSecure: Bool = false
    var textContentType: UITextContentType? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    var onSubmit: (() -> Void)? = nil

    @State private var isFocused = false
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var fieldIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Enhanced field with better design system integration
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                if !title.isEmpty {
                    Text(title)
                        .textHierarchy(.metadata, color: isFocused ? DesignTokens.Colors.Primary.blue : DesignTokens.Colors.Neutral.secondary)
                        .animation(DesignTokens.Animation.easeInOut, value: isFocused)
                }
                
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.system(size: DesignTokens.ComponentSize.iconSize, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: DesignTokens.ComponentSize.iconSize)
                        .accessibilityHidden(true)

                    if isSecure {
                        SecureField(placeholder, text: $text)
                            .textContentType(textContentType)
                            .focused($fieldIsFocused)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .textContentType(textContentType)
                            .focused($fieldIsFocused)
                    }
                }
                .font(DesignTokens.Typography.body())
                .padding(DesignTokens.Spacing.md)
                .background(backgroundColor)
                .overlay(borderOverlay)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                .animation(DesignTokens.Animation.easeInOut, value: isFocused)
                .animation(DesignTokens.Animation.easeInOut, value: errorMessage != nil)
                .onChange(of: fieldIsFocused) { _, newValue in
                    isFocused = newValue
                    onEditingChanged?(newValue)
                }
                .onSubmit {
                    onSubmit?()
                }
            }
            
            // Error message with proper accessibility
            if let errorMessage = errorMessage {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.Semantic.error)
                        .accessibilityHidden(true)
                    
                    Text(errorMessage)
                        .textHierarchy(.caption, color: DesignTokens.Colors.Semantic.error)
                }
                .transition(.opacity)
                .animation(DesignTokens.Animation.easeInOut, value: errorMessage)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    private var iconColor: Color {
        if let _ = errorMessage {
            return DesignTokens.Colors.Semantic.error
        } else if isFocused {
            return DesignTokens.Colors.Primary.blue
        } else {
            return DesignTokens.Colors.Neutral.secondary
        }
    }
    
    private var backgroundColor: Color {
        if let _ = errorMessage {
            return DesignTokens.Colors.Semantic.error.opacity(0.05)
        } else if isFocused {
            return DesignTokens.Colors.Background.secondary
        } else {
            return DesignTokens.Colors.Background.secondary
        }
    }
    
    @ViewBuilder
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }
    
    private var borderColor: Color {
        if let _ = errorMessage {
            return DesignTokens.Colors.Semantic.error
        } else if isFocused {
            return DesignTokens.Colors.Primary.blue
        } else {
            return DesignTokens.Colors.Fill.tertiary
        }
    }
    
    private var borderWidth: CGFloat {
        isFocused ? 2 : 1
    }
    
    private var accessibilityLabel: String {
        var label = title.isEmpty ? placeholder : title
        if let errorMessage = errorMessage {
            label += ", Error: \(errorMessage)"
        }
        return label
    }
    
    private var accessibilityHint: String {
        if isSecure {
            return "Secure text field. Enter your password."
        } else {
            return "Text field. Enter \(title.lowercased())."
        }
    }
}

// MARK: - Enhanced Form Components
struct EnhancedFormSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content
    
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .textHierarchy(.sectionTitle)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .textHierarchy(.caption)
                }
            }
            .semanticDivider(.subtle)
            
            content
        }
        .semanticSpacing(.section)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
    }
}

struct SmartFormContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.sectionSpacing) {
                Text(title)
                    .textHierarchy(.pageTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                
                content
            }
            .semanticSpacing(.page)
        }
        .background(DesignTokens.Colors.Background.grouped)
        .navigationBarTitleDisplayMode(.inline)
    }
}
