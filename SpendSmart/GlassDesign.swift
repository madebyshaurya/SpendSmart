import SwiftUI

// Compatibility glass effect for iOS versions prior to 26
private enum _GlassShape {
    case rect(CGFloat)
    case capsule
    case circle
}

private struct _GlassCompat: ViewModifier {
    var tint: Color?
    var interactive: Bool = false
    var shape: _GlassShape

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch shape {
            case .rect(let radius):
                if let tint {
                    content.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: radius))
                } else {
                    content.glassEffect(.regular, in: .rect(cornerRadius: radius))
                }
            case .capsule:
                if let tint {
                    content.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    content.glassEffect(.regular, in: .capsule)
                }
            case .circle:
                if let tint {
                    content.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                } else {
                    content.glassEffect(.regular, in: .circle)
                }
            }
        } else {
            // Fallback for earlier iOS: material background with appropriate shape
            switch shape {
            case .rect(let radius):
                content
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            case .capsule:
                content
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            case .circle:
                content
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            }
        }
    }
}

private extension View {
    func _glassCompat(tint: Color? = nil, interactive: Bool = false, shape: _GlassShape) -> some View {
        modifier(_GlassCompat(tint: tint, interactive: interactive, shape: shape))
    }
}

// Shared Liquid Glass button styles and row helpers
// Usage:
// Button("Action") { ... }.buttonStyle(.glass)
// Button("Primary") { ... }.buttonStyle(.glassProminent)
// RowView().glassRow(tint: .blue)

public struct GlassButtonStyle: ButtonStyle {
    public var cornerRadius: CGFloat = 16
    public init(cornerRadius: CGFloat = 16) { self.cornerRadius = cornerRadius }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            ._glassCompat(tint: nil, interactive: true, shape: .rect(cornerRadius))
    }
}

public struct GlassProminentButtonStyle: ButtonStyle {
    public var tint: Color = .blue
    public var cornerRadius: CGFloat = 16
    public init(tint: Color = .blue, cornerRadius: CGFloat = 16) {
        self.tint = tint
        self.cornerRadius = cornerRadius
    }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            ._glassCompat(tint: tint, interactive: true, shape: .rect(cornerRadius))
    }
}

public extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
}

public extension ButtonStyle where Self == GlassProminentButtonStyle {
    static var glassProminent: GlassProminentButtonStyle { GlassProminentButtonStyle() }
}

public struct GlassRowModifier: ViewModifier {
    public var cornerRadius: CGFloat = 12
    public var tint: Color? = nil
    public func body(content: Content) -> some View {
        content
            .padding(12)
            ._glassCompat(tint: tint, interactive: tint != nil, shape: .rect(cornerRadius))
    }
}

public extension View {
    func glassRow(tint: Color? = nil, cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassRowModifier(cornerRadius: cornerRadius, tint: tint))
    }
}
