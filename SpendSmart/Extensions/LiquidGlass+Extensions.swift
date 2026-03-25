import SwiftUI

extension View {
    /// Apply Liquid Glass on iOS 26+, fall back to ultraThinMaterial on older iOS.
    @ViewBuilder
    func glassBackground(in shape: some Shape = .rect(cornerRadius: 16)) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Interactive glass for buttons (iOS 26+), plain style fallback.
    @ViewBuilder
    func glassButton(in shape: some Shape = .capsule) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self
                .background(Color.brandSurface)
                .clipShape(shape)
        }
    }

    /// Tinted glass for accent elements
    @ViewBuilder
    func tintedGlass(_ color: Color, in shape: some Shape = .rect(cornerRadius: 12)) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.tint(color), in: shape)
        } else {
            self
                .background(color.opacity(0.1))
                .clipShape(shape)
        }
    }
}
