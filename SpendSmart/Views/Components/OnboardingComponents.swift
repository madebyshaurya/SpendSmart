//
//  OnboardingComponents.swift
//  SpendSmart
//
//  Created by Claude on 2025-01-25.
//  Reusable onboarding UI components
//

import SwiftUI
import Shimmer

// MARK: - Selection Card
struct OnboardingSelectionCard<T: Hashable>: View {
    let item: T
    let isSelected: Bool
    let title: String
    let subtitle: String?
    let icon: String?
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        item: T,
        isSelected: Bool,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
    }
    
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            action()
        }) {
            HStack(spacing: 14) {
                // Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(
                            isSelected ? .primary : .primary.opacity(0.7)
                        )
                        .frame(width: 32, height: 32)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.hierarchyBody(emphasis: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.hierarchyCaption(emphasis: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.25), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(UIColor.systemBackground))
                            )
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.primary : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 12, x: 0, y: 6)
            )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Multi-Selection Card
struct OnboardingMultiSelectionCard<T: Hashable>: View {
    let item: T
    let isSelected: Bool
    let title: String
    let subtitle: String?
    let icon: String?
    let maxSelections: Int?
    let currentSelectionCount: Int
    let action: () -> Void
    
    private var canSelect: Bool {
        isSelected || maxSelections == nil || currentSelectionCount < maxSelections!
    }
    
    var body: some View {
        OnboardingSelectionCard(
            item: item,
            isSelected: isSelected,
            title: title,
            subtitle: subtitle,
            icon: icon
        ) {
            if canSelect {
                action()
            }
        }
        .opacity(canSelect ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: canSelect)
    }
}

// MARK: - Primary Button
struct OnboardingPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }
    
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                HapticFeedbackManager.shared.mediumImpact()
                action()
            }
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(.hierarchyBody(emphasis: .medium))
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                
                if !isLoading {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isEnabled && !isLoading
                        ? (colorScheme == .dark ? Color.white : Color.black)
                        : (colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.12), radius: 12, x: 0, y: 6)
            )
        }
        .scaleEffect(isPressed && isEnabled ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .onTapGesture {
            if isEnabled && !isLoading {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isPressed = false
                    }
                }
            }
        }
    }
}

// MARK: - Welcome Card
struct OnboardingWelcomeCard: View {
    let title: String
    let subtitle: String?
    let features: [OnboardingFeature]
    let showLogo: Bool
    
    init(title: String, subtitle: String?, features: [OnboardingFeature], showLogo: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.features = features
        self.showLogo = showLogo
    }
    
    var body: some View {
        VStack(spacing: showLogo ? 28 : 16) {
            // Optional logo placeholder (hidden by default to reduce top gap)
            if showLogo {
                OnboardingImagePlaceholder(
                    type: .appLogo,
                    size: CGSize(width: 88, height: 88)
                )
            }
            
            // Title and subtitle
            VStack(spacing: 16) {
                // Style brand word "SpendSmart" in Instrument Serif Italic
                if title.contains("SpendSmart") {
                    VStack(spacing: 4) {
                        Text("Welcome to")
                            .font(.hierarchyDisplay(level: 1))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        Text("SpendSmart")
                            .useInstrumentSerifItalic(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.HierarchyDisplay.level1))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .shimmering(
                                active: true,
                                animation: .easeInOut(duration: 1.6).repeatForever(autoreverses: false)
                            )
                    }
                } else {
                    Text(title)
                        .font(.hierarchyDisplay(level: 1))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.hierarchyBody(emphasis: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                }
            }
            
            // Features
            VStack(spacing: 20) {
                ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                    OnboardingFeatureRow(
                        feature: feature,
                        animationDelay: Double(index) * 0.1
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Feature Row
struct OnboardingFeatureRow: View {
    let feature: OnboardingFeature
    let animationDelay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: feature.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(feature.title)
                    .font(.hierarchyBody(emphasis: .medium))
                    .foregroundColor(.primary)
                
                Text(feature.description)
                    .font(.hierarchyCaption(emphasis: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : 20)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8)
            .delay(animationDelay),
            value: isVisible
        )
        .onAppear {
            isVisible = true
        }
    }
}

// MARK: - Image Placeholder
struct OnboardingImagePlaceholder: View {
    let type: PlaceholderType
    let size: CGSize
    
    enum PlaceholderType {
        case appLogo
        case financialGoals
        case budgetVisualization
        case categoryIcons
        case celebration
        
        var icon: String {
            switch self {
            case .appLogo: return "chart.pie.fill"
            case .financialGoals: return "target"
            case .budgetVisualization: return "chart.bar.fill"
            case .categoryIcons: return "square.grid.2x2.fill"
            case .celebration: return "party.popper.fill"
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .appLogo: return Color.white.opacity(0.15)
            case .financialGoals: return Color.white.opacity(0.12)
            case .budgetVisualization: return Color.white.opacity(0.12)
            case .categoryIcons: return Color.white.opacity(0.12)
            case .celebration: return Color.white.opacity(0.15)
            }
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.2, style: .continuous)
                .fill(type.backgroundColor)
                .frame(width: size.width, height: size.height)
            
            Image(systemName: type.icon)
                .font(.system(size: min(size.width, size.height) * 0.4, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Supporting Models
struct OnboardingFeature: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
}

// MARK: - Default Features
extension OnboardingFeature {
    static let defaultFeatures: [OnboardingFeature] = [
        OnboardingFeature(
            title: "Smart Expense Tracking",
            description: "Automatically categorize and analyze your spending patterns",
            icon: "chart.pie.fill"
        ),
        OnboardingFeature(
            title: "Receipt Management",
            description: "Capture, store, and organize all your receipts in one place",
            icon: "doc.text.viewfinder"
        ),
        OnboardingFeature(
            title: "Personalized Insights",
            description: "Get tailored recommendations based on your spending habits",
            icon: "sparkles"
        ),
        OnboardingFeature(
            title: "Budget Goals",
            description: "Set and track progress toward your financial objectives",
            icon: "target"
        )
    ]
}

// MARK: - Preview Providers
#Preview("Selection Card") {
    VStack(spacing: 16) {
        OnboardingSelectionCard(
            item: "test1",
            isSelected: false,
            title: "Track my spending and stick to budgets",
            subtitle: "Perfect for budget-conscious users",
            icon: "chart.pie.fill"
        ) {
            
        }
        
        OnboardingSelectionCard(
            item: "test2",
            isSelected: true,
            title: "Save money for specific goals",
            subtitle: "Ideal for goal-oriented savers",
            icon: "target"
        ) {
            
        }
    }
    .padding(20)
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Welcome Card") {
    OnboardingWelcomeCard(
        title: "Welcome to SpendSmart",
        subtitle: "Track spending, achieve goals, build better habits",
        features: OnboardingFeature.defaultFeatures
    )
    .padding(20)
    .background(
        LinearGradient(
            colors: [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
