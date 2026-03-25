//
//  BrandCard.swift
//  SpendSmart
//
//  Reusable card components with consistent styling, animations,
//  and optional interactive states.
//

import SwiftUI

// MARK: - Brand Card

struct BrandCard<Content: View>: View {
    let content: Content
    var style: CardStyle = .elevated
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16
    var isInteractive: Bool = false
    var onTap: (() -> Void)? = nil
    
    @State private var isPressed = false
    
    init(
        style: CardStyle = .elevated,
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
        isInteractive: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isInteractive = isInteractive
        self.onTap = onTap
        self.content = content()
    }
    
    enum CardStyle {
        case flat
        case elevated
        case outlined
        case glass
        case gradient
        
        var backgroundColor: Color {
            switch self {
            case .flat: return .brandSurface
            case .elevated: return .brandSurface
            case .outlined: return .brandBackground
            case .glass: return .brandSurface.opacity(0.8)
            case .gradient: return .clear
            }
        }
        
        var shadowOpacity: Double {
            switch self {
            case .flat: return 0
            case .elevated: return 0.08
            case .outlined: return 0
            case .glass: return 0.05
            case .gradient: return 0.1
            }
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .flat: return 0
            case .elevated: return 12
            case .outlined: return 0
            case .glass: return 8
            case .gradient: return 16
            }
        }
    }
    
    var body: some View {
        Group {
            if isInteractive {
                Button {
                    HapticManager.shared.light()
                    onTap?()
                } label: {
                    cardContent
                }
                .buttonStyle(CardButtonStyle())
            } else {
                cardContent
            }
        }
    }
    
    private var cardContent: some View {
        content
            .padding(padding)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(cardOverlay)
            .modifier(CardGlassModifier(isGlass: style == .glass || style == .elevated, cornerRadius: cornerRadius))
            .shadow(
                color: Color.black.opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                y: style == .elevated ? 4 : 2
            )
    }

    @ViewBuilder
    private var cardBackground: some View {
        switch style {
        case .glass, .elevated:
            Color.clear
        case .gradient:
            MeshGradient.brandSoft
        default:
            style.backgroundColor
        }
    }

    @ViewBuilder
    private var cardOverlay: some View {
        switch style {
        case .outlined:
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.brandBorder, lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

// Card button style
private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.brandSnappy, value: configuration.isPressed)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .brandVibrantBlue
    var trend: Trend? = nil
    var isLoading: Bool = false
    
    enum Trend {
        case up(String)
        case down(String)
        case neutral(String)
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "arrow.right"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .brandSuccess
            case .down: return .brandError
            case .neutral: return .brandTextSecondary
            }
        }
        
        var text: String {
            switch self {
            case .up(let text), .down(let text), .neutral(let text):
                return text
            }
        }
    }
    
    var body: some View {
        BrandCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    if let icon = icon {
                        ZStack {
                            Circle()
                                .fill(iconColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(iconColor)
                        }
                    }
                    
                    Text(title)
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                    
                    Spacer()
                    
                    if let trend = trend {
                        HStack(spacing: 4) {
                            Image(systemName: trend.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(trend.text)
                                .font(.manrope(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(trend.color)
                    }
                }
                
                // Value
                if isLoading {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.brandBorder)
                        .frame(width: 100, height: 28)
                        .shimmer()
                } else {
                    Text(value)
                        .font(.manrope(size: 28, weight: .bold))
                        .foregroundStyle(Color.brandTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                // Subtitle
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.manrope(size: 13))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
        }
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let title: String
    let description: String
    let icon: String
    var iconColor: Color = .brandVibrantBlue
    var actionLabel: String = "View"
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.manrope(size: 16, weight: .semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    Text(description)
                        .font(.manrope(size: 13))
                        .foregroundStyle(Color.brandTextSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .padding(16)
            .background(Color.brandSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandBorder.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Feature Card (for upgrade prompts)

struct FeatureCard: View {
    let title: String
    let description: String
    let icon: String
    var isPro: Bool = true
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                if isPro {
                    LinearGradient(
                        colors: [Color.brandVibrantBlue, Color.brandRoyalBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.brandAccentLight
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isPro ? .white : Color.brandVibrantBlue)
            )
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.manrope(size: 15, weight: .semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    if isPro {
                        Text("PRO")
                            .font(.manrope(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brandVibrantBlue)
                            .clipShape(Capsule())
                    }
                }
                
                Text(description)
                    .font(.manrope(size: 13))
                    .foregroundStyle(Color.brandTextSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color.brandSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isPro ? Color.brandVibrantBlue.opacity(0.2) : Color.brandBorder, lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Card Styles") {
    ScrollView {
        VStack(spacing: 16) {
            BrandCard(style: .elevated) {
                Text("Elevated Card")
                    .font(.manrope(size: 16, weight: .medium))
            }
            
            BrandCard(style: .outlined) {
                Text("Outlined Card")
                    .font(.manrope(size: 16, weight: .medium))
            }
            
            BrandCard(style: .flat) {
                Text("Flat Card")
                    .font(.manrope(size: 16, weight: .medium))
            }
            
            BrandCard(style: .glass) {
                Text("Glass Card")
                    .font(.manrope(size: 16, weight: .medium))
            }
        }
        .padding()
    }
    .background(Color.brandBackground)
}

#Preview("Stat Cards") {
    VStack(spacing: 16) {
        StatCard(
            title: "Total Spent",
            value: "$1,234.56",
            subtitle: "This month",
            icon: "dollarsign.circle.fill",
            trend: .up("12%")
        )
        
        StatCard(
            title: "Receipts",
            value: "47",
            icon: "doc.text.fill",
            iconColor: .brandSuccess
        )
        
        StatCard(
            title: "Loading State",
            value: "",
            isLoading: true
        )
    }
    .padding()
    .background(Color.brandBackground)
}

#Preview("Action Card") {
    ActionCard(
        title: "Upgrade to Plus",
        description: "Unlock unlimited scans and cloud backup",
        icon: "star.fill",
        iconColor: .brandWarning
    ) {
        print("Tapped")
    }
    .padding()
}

#Preview("Feature Card") {
    VStack(spacing: 12) {
        FeatureCard(
            title: "Cloud Sync",
            description: "Access your receipts anywhere",
            icon: "icloud.fill",
            isPro: true
        )
        
        FeatureCard(
            title: "Basic Scanning",
            description: "Scan up to 5 receipts per week",
            icon: "camera.fill",
            isPro: false
        )
    }
    .padding()
}

// MARK: - Glass Effect Modifier for Cards

private struct CardGlassModifier: ViewModifier {
    let isGlass: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        // Liquid Glass deferred to iOS 26 adoption
        content
    }
}
