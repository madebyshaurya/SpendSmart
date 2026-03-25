//
//  Brand3DButton.swift
//  SpendSmart
//
//  A delightful 3D-style button with press animations, haptic feedback,
//  and mesh gradient backgrounds. Inspired by physical button mechanics.
//

import SwiftUI

// MARK: - Brand 3D Button

struct Brand3DButton: View {
    let title: String
    var icon: String? = nil
    let style: ButtonStyle
    var size: ButtonSize = .regular
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    enum ButtonStyle {
        case primary
        case secondary
        case danger
        case success
        case ghost
    }
    
    enum ButtonSize {
        case small
        case regular
        case large
        
        var height: CGFloat {
            switch self {
            case .small: return 44
            case .regular: return 56
            case .large: return 64
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .regular: return 16
            case .large: return 18
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .regular: return 16
            case .large: return 20
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 12
            case .regular: return 16
            case .large: return 20
            }
        }
        
        var bottomOffset: CGFloat {
            switch self {
            case .small: return 3
            case .regular: return 4
            case .large: return 5
            }
        }
    }
    
    var body: some View {
        Button {
            guard !isDisabled && !isLoading else { return }
            triggerPressAnimation()
            HapticManager.shared.medium()
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.9)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .semibold))
                            .symbolEffect(.bounce, value: isPressed)
                    }
                    Text(title)
                        .font(.manrope(size: size.fontSize, weight: .bold))
                }
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: size == .small ? nil : .infinity)
            .frame(height: size.height)
            .padding(.horizontal, size == .small ? 20 : 0)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
            .background(
                // Bottom shadow layer for 3D effect
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(bottomColor)
                    .offset(y: isPressed ? 0 : size.bottomOffset)
            )
            .offset(y: isPressed ? size.bottomOffset : 0)
            .scaleEffect(isPressed ? 0.97 : 1.0) // "The Golden Rule"
            .shadow(
                color: shadowColor.opacity(isPressed ? 0.15 : 0.3),
                radius: isPressed ? 2 : 8,
                x: 0,
                y: isPressed ? 1 : 4
            )
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(SnappyButtonStyle())
        .disabled(isDisabled || isLoading)
    }
    
    private func triggerPressAnimation() {
        if reduceMotion {
            return
        }
        
        // Quick snap down (Ease Out)
        withAnimation(.brandEaseOut) {
            isPressed = true
        }
        // Quick snap back up (Spring)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.brandSpring) {
                isPressed = false
            }
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .primary:
            MeshGradient.brandButton
        case .secondary:
            Color.brandBackground
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .stroke(Color.brandBorder, lineWidth: 1.5)
                )
        case .danger:
            LinearGradient.brandDangerGradient
        case .success:
            LinearGradient.brandSuccessGradient
        case .ghost:
            Color.clear
        }
    }
    
    private var bottomColor: Color {
        switch style {
        case .primary: return .chartBlue2
        case .secondary: return Color.brandBorder
        case .danger: return .brandErrorDark
        case .success: return .brandSuccessDark
        case .ghost: return Color.clear
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Color.brandTextPrimary
        case .danger: return .white
        case .success: return .white
        case .ghost: return Color.brandVibrantBlue
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary: return Color.brandDeepNavy
        case .secondary: return Color.brandTextSecondary.opacity(0.3)
        case .danger: return Color.brandError
        case .success: return Color.brandSuccess
        case .ghost: return Color.clear
        }
    }
}

// MARK: - Snappy Button Style

/// Clean button style that doesn't interfere with our custom animation
struct SnappyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// MARK: - Icon-Only Button Variant

struct Brand3DIconButton: View {
    let icon: String
    let style: Brand3DButton.ButtonStyle
    var size: CGFloat = 48
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        Button {
            triggerPressAnimation()
            HapticManager.shared.light()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(width: size, height: size)
                .background(buttonBackground)
                .clipShape(Circle())
                .background(
                    Circle()
                        .fill(bottomColor)
                        .offset(y: isPressed ? 0 : 3)
                )
                .offset(y: isPressed ? 3 : 0)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .shadow(
                    color: shadowColor.opacity(isPressed ? 0.1 : 0.25),
                    radius: isPressed ? 2 : 6,
                    y: isPressed ? 1 : 3
                )
        }
        .buttonStyle(SnappyButtonStyle())
    }
    
    private func triggerPressAnimation() {
        if reduceMotion { return }
        
        withAnimation(.brandEaseOut) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.brandSpring) {
                isPressed = false
            }
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .primary:
            MeshGradient.brandButton
        case .secondary:
            Color.brandSurface
        case .danger:
            Color.brandErrorLight
        case .success:
            Color.brandSuccessLight
        case .ghost:
            Color.clear
        }
    }
    
    private var bottomColor: Color {
        switch style {
        case .primary: return .chartBlue2
        case .secondary: return Color.brandBorder
        case .danger: return Color.brandError.opacity(0.3)
        case .success: return Color.brandSuccess.opacity(0.3)
        case .ghost: return Color.clear
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Color.brandTextPrimary
        case .danger: return Color.brandError
        case .success: return Color.brandSuccess
        case .ghost: return Color.brandVibrantBlue
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary: return Color.brandDeepNavy
        case .secondary: return Color.brandTextSecondary.opacity(0.3)
        case .danger: return Color.brandError
        case .success: return Color.brandSuccess
        case .ghost: return Color.clear
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    var badge: Int? = nil
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isPulsing = false
    
    var body: some View {
        Button {
            withAnimation(.brandEaseOut) { isPressed = true }
            HapticManager.shared.buttonPress()
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.brandSpring) { isPressed = false }
            }
        } label: {
            ZStack {
                // Pulsing ring (optional attention grab)
                if isPulsing {
                    Circle()
                        .stroke(Color.brandVibrantBlue.opacity(0.3), lineWidth: 2)
                        .frame(width: 72, height: 72)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }
                
                // Main button
                Group {
                    MeshGradient.brandButton
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white)
                )
                .shadow(color: Color.brandVibrantBlue.opacity(0.4), radius: 12, y: 6)
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .offset(y: isPressed ? 2 : 0)
                
                // Badge
                if let badge = badge, badge > 0 {
                    Text("\(min(badge, 99))")
                        .font(.manrope(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandError)
                        .clipShape(Capsule())
                        .offset(x: 22, y: -22)
                }
            }
        }
        .buttonStyle(SnappyButtonStyle())
    }
    
    func withPulse(_ enabled: Bool = true) -> FloatingActionButton {
        var copy = self
        copy.isPulsing = enabled
        return copy
    }
}

// MARK: - Previews

#Preview("Button Styles") {
    VStack(spacing: 16) {
        Brand3DButton(title: "Primary Action", icon: "sparkles", style: .primary) {}
        Brand3DButton(title: "Secondary", icon: "arrow.right", style: .secondary) {}
        Brand3DButton(title: "Danger Zone", icon: "trash", style: .danger) {}
        Brand3DButton(title: "Success!", icon: "checkmark", style: .success) {}
        Brand3DButton(title: "Ghost", style: .ghost) {}
        
        HStack(spacing: 12) {
            Brand3DButton(title: "Small", style: .primary, size: .small) {}
            Brand3DButton(title: "Loading", style: .primary, size: .small, isLoading: true) {}
        }
    }
    .padding()
}

#Preview("Icon Buttons") {
    HStack(spacing: 16) {
        Brand3DIconButton(icon: "plus", style: .primary) {}
        Brand3DIconButton(icon: "heart.fill", style: .danger) {}
        Brand3DIconButton(icon: "checkmark", style: .success) {}
        Brand3DIconButton(icon: "gear", style: .secondary) {}
    }
    .padding()
}

#Preview("FAB") {
    ZStack {
        Color.brandBackground.ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingActionButton(icon: "camera.fill", badge: 3) {}
                    .padding(24)
            }
        }
    }
}
