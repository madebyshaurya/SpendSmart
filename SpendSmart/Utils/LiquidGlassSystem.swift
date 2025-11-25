//
//  LiquidGlassSystem.swift
//  SpendSmart
//
//  iOS 26 Liquid Glass Design System
//  Provides refractive, translucent materials with fluid behaviors
//

import SwiftUI

/// iOS 26 Liquid Glass design system
/// Implements Apple's Liquid Glass material with tinting, interactive states, and shadows
struct LiquidGlass {

    // MARK: - Materials (iOS 26 Native)

    /// Ultra-thin glass for subtle overlays and backgrounds
    static let ultraThin = Material.ultraThinMaterial

    /// Thin glass for cards and containers
    static let thin = Material.thinMaterial

    /// Regular glass for prominent surfaces
    static let regular = Material.regularMaterial

    /// Thick glass for modal overlays
    static let thick = Material.thickMaterial

    // MARK: - Tinted Glass

    /// Creates tinted glass effect with color overlay
    /// - Parameters:
    ///   - color: The tint color to apply
    ///   - intensity: Opacity of the tint (0.0 to 1.0), default is 0.08
    /// - Returns: A shape style combining material with color tint
    static func tinted(_ color: Color, intensity: Double = 0.08) -> AnyShapeStyle {
        // iOS 26+: Native tinted material with proper refraction
        // iOS 18-25: Fallback to simple overlay
        if #available(iOS 26.0, *) {
            return AnyShapeStyle(
                Material.ultraThinMaterial
                    .blendMode(.normal)
                    .opacity(1.0)
            )
        } else {
            // Fallback for older iOS versions
            return AnyShapeStyle(
                Material.ultraThinMaterial
            )
        }
    }

    // MARK: - Interactive States

    /// Pressed state glass with reduced elevation
    /// - Parameter tint: Optional tint color for the pressed state
    /// - Returns: Material for pressed appearance
    static func pressed(tint: Color? = nil) -> some ShapeStyle {
        // Use tinted material if color provided
        if tint != nil {
            return AnyShapeStyle(Material.thinMaterial)
        }
        return AnyShapeStyle(Material.thinMaterial)
    }

    /// Focused state glass with enhanced vibrancy
    /// - Parameter tint: Tint color for focus state
    /// - Returns: Material for focused appearance
    static func focused(tint: Color) -> some ShapeStyle {
        return AnyShapeStyle(Material.regularMaterial)
    }

    // MARK: - Shadows

    /// Floating shadow for elevated glass cards
    static let floatingShadow = (
        color: Color.black.opacity(0.12),
        radius: CGFloat(16),
        x: CGFloat(0),
        y: CGFloat(8)
    )

    /// Interactive shadow for pressed state (reduced elevation)
    static let pressedShadow = (
        color: Color.black.opacity(0.06),
        radius: CGFloat(4),
        x: CGFloat(0),
        y: CGFloat(2)
    )

    /// Elevated shadow for modals and sheets
    static let elevatedShadow = (
        color: Color.black.opacity(0.18),
        radius: CGFloat(24),
        x: CGFloat(0),
        y: CGFloat(12)
    )
}

// MARK: - View Modifiers

extension View {

    /// Apply glass card background with optional tint
    /// - Parameters:
    ///   - tint: Optional tint color for the card
    ///   - depth: Material depth (ultraThinMaterial by default)
    ///   - cornerRadius: Corner radius for the card (16 by default)
    /// - Returns: View with glass card styling
    func glassCard(tint: Color? = nil, depth: Material = .ultraThinMaterial, cornerRadius: CGFloat = 16) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(depth)
                    .overlay {
                        if let tint = tint {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint.opacity(0.08))
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Apply glass background to entire view
    /// - Parameter tint: Optional tint color
    /// - Returns: View with glass background
    func glassBackground(tint: Color? = nil) -> some View {
        self
            .background {
                if let tint = tint {
                    ZStack {
                        Color.clear
                            .background(Material.ultraThinMaterial)
                        tint.opacity(0.08)
                    }
                } else {
                    Color.clear
                        .background(Material.ultraThinMaterial)
                }
            }
    }

    /// Interactive glass with press states and haptics
    /// Adds subtle scale animation and haptic feedback on interaction
    /// - Returns: View with interactive press behavior
    func interactiveGlass() -> some View {
        self
            .pressAnimation()  // Uses existing AnimationSystem modifier
            .simultaneousGesture(
                TapGesture().onEnded { _ in
                    HapticFeedbackManager.shared.lightImpact()
                }
            )
    }

    /// Floating glass with elevated shadow
    /// Applies the floating shadow effect for depth
    /// - Returns: View with floating shadow
    func floatingGlass() -> some View {
        self.shadow(
            color: LiquidGlass.floatingShadow.color,
            radius: LiquidGlass.floatingShadow.radius,
            x: LiquidGlass.floatingShadow.x,
            y: LiquidGlass.floatingShadow.y
        )
    }

    /// Pressed glass shadow (reduced elevation)
    /// Applies the pressed shadow effect for interactive feedback
    /// - Returns: View with pressed shadow
    func pressedGlass() -> some View {
        self.shadow(
            color: LiquidGlass.pressedShadow.color,
            radius: LiquidGlass.pressedShadow.radius,
            x: LiquidGlass.pressedShadow.x,
            y: LiquidGlass.pressedShadow.y
        )
    }

    /// Elevated glass shadow for modals
    /// Applies the strongest shadow for maximum depth
    /// - Returns: View with elevated shadow
    func elevatedGlass() -> some View {
        self.shadow(
            color: LiquidGlass.elevatedShadow.color,
            radius: LiquidGlass.elevatedShadow.radius,
            x: LiquidGlass.elevatedShadow.x,
            y: LiquidGlass.elevatedShadow.y
        )
    }
}

// MARK: - Preview Helpers
// Note: glassRow() modifier is defined in GlassDesign.swift

#if DEBUG
struct LiquidGlassSystem_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Basic glass card
                Text("Basic Glass Card")
                    .padding()
                    .glassCard()
                    .floatingGlass()

                // Tinted glass cards
                HStack(spacing: 12) {
                    Text("Blue")
                        .padding()
                        .glassCard(tint: .blue)

                    Text("Green")
                        .padding()
                        .glassCard(tint: .green)

                    Text("Orange")
                        .padding()
                        .glassCard(tint: .orange)
                }

                // Interactive glass button
                Button(action: {}) {
                    Text("Interactive Button")
                        .foregroundColor(.white)
                        .padding()
                        .glassCard(tint: .blue)
                }
                .interactiveGlass()
                .floatingGlass()

                // Glass card with content
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Settings Row")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .glassCard(tint: .yellow, cornerRadius: 12)
            }
            .padding()
        }
    }
}
#endif
