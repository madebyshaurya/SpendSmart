import SwiftUI

struct FormSectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
            )
    }
}

struct SolidCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
            )
    }
}

struct FieldContainerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var isFocused: Bool
    var tint: Color = .blue

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? tint : Color.clear, lineWidth: 1)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFocused)
    }
}

extension View {
    func formSection() -> some View {
        modifier(FormSectionModifier())
    }

    func solidCard() -> some View {
        modifier(SolidCardModifier())
    }

    func fieldContainer(isFocused: Bool, tint: Color = .blue) -> some View {
        modifier(FieldContainerModifier(isFocused: isFocused, tint: tint))
    }
}


