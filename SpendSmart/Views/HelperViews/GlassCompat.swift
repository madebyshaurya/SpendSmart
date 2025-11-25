import SwiftUI

/// Compatibility helpers to approximate the new iOS 26 `glassEffect` API on earlier OS versions.
/// These helpers intentionally avoid referencing `glassEffect` so they compile on older SDKs.
extension View {
    /// Applies a glass-like background using ultra-thin material clipped to a rounded rectangle.
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the rounded rectangle.
    ///   - tint: Optional tint color for a subtle outline. Defaults to a faint white outline.
    @ViewBuilder
    func glassBackground(cornerRadius: CGFloat, tint: Color? = nil) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke((tint ?? Color.white).opacity(0.15), lineWidth: 1)
            )
    }

    /// Applies a glass-like background using ultra-thin material clipped to a capsule.
    /// - Parameter tint: Optional tint color for a subtle outline.
    @ViewBuilder
    func glassCapsule(tint: Color? = nil) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke((tint ?? Color.white).opacity(0.15), lineWidth: 1)
            )
    }

    /// Applies a glass-like background using ultra-thin material clipped to a circle.
    /// - Parameter tint: Optional tint color for a subtle outline.
    @ViewBuilder
    func glassCircle(tint: Color? = nil) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke((tint ?? Color.white).opacity(0.15), lineWidth: 1)
            )
    }

    /// Applies the system `glassEffect` when available, otherwise falls back to a manual rounded rectangle glass background.
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the rounded rectangle.
    ///   - tint: Optional tint color to emulate the system tint styling.
    ///   - interactive: When `true`, mirrors the system interactive appearance when available.
    @ViewBuilder
    func glassCompatRect(cornerRadius: CGFloat, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                }
            }
        } else {
            self.glassBackground(cornerRadius: cornerRadius, tint: tint)
        }
    }

    /// Applies the system `glassEffect` capsule style when available, with a graceful fallback.
    /// - Parameters:
    ///   - tint: Optional tint color.
    ///   - interactive: When `true`, mirrors the system interactive appearance when available.
    @ViewBuilder
    func glassCompatCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .capsule)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular, in: .capsule)
                }
            }
        } else {
            self.glassCapsule(tint: tint)
        }
    }

    /// Applies the system `glassEffect` circle style when available, with a graceful fallback.
    /// - Parameters:
    ///   - tint: Optional tint color.
    ///   - interactive: When `true`, mirrors the system interactive appearance when available.
    @ViewBuilder
    func glassCompatCircle(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .circle)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular, in: .circle)
                }
            }
        } else {
            self.glassCircle(tint: tint)
        }
    }
}
