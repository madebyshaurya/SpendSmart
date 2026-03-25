import SwiftUI

struct ChatIllustration: View {
    @Binding var phase1: Bool
    @Binding var phase2: Bool
    @Binding var phase3: Bool
    @Binding var continuousRotation: Bool
    @Binding var floatOffset: CGFloat

    var body: some View {
#if canImport(UIKit)
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.brandPurple.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .scaleEffect(phase1 ? 1.0 : 0.5)

            chatBubble(isAI: false)
                .offset(x: -40, y: -30 + floatOffset / 2)
                .scaleEffect(phase1 ? 1.0 : 0.3)
                .opacity(phase1 ? 1 : 0)

            chatBubble(isAI: true)
                .offset(x: 35, y: 20 - floatOffset / 2)
                .scaleEffect(phase2 ? 1.0 : 0.3)
                .opacity(phase2 ? 1 : 0)

            ForEach(0..<3) { index in
                aiSparkle(index: index)
                    .scaleEffect(phase3 ? 1.0 : 0.3)
                    .opacity(phase3 ? 1 : 0)
            }

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.brandPurple)
                        .frame(width: 6, height: 6)
                        .offset(y: thinkingDotOffset(index: index))
                }
            }
            .offset(x: 35, y: 20)
            .opacity(phase3 ? 1 : 0)
        }
#else
        EmptyView()
#endif
    }

    private func chatBubble(isAI: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isAI ?
                    LinearGradient(
                        colors: [Color.brandVibrantBlue, Color.brandPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [.white, .white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: isAI ? 45 : 40)
                .shadow(
                    color: isAI ? Color.brandPurple.opacity(0.3) : .black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )

            if isAI {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            } else {
                VStack(spacing: 4) {
                    ForEach(0..<2) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.brandBorder)
                            .frame(width: 40, height: 3)
                    }
                }
            }
        }
    }

    private func aiSparkle(index: Int) -> some View {
        let positions: [CGSize] = [
            CGSize(width: 70, height: -20),
            CGSize(width: -55, height: 50),
            CGSize(width: 60, height: 55)
        ]

        return Image(systemName: "sparkle")
            .font(.system(size: 12 + CGFloat(index) * 2))
            .foregroundStyle(
                index == 0 ? Color.brandVibrantBlue :
                index == 1 ? Color.brandPurple :
                Color.brandSkyBlue
            )
            .offset(positions[index])
            .opacity(0.8)
            .scaleEffect(phase3 ? 1.0 : 0.5)
            .animation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.3),
                value: phase3
            )
    }

    private func thinkingDotOffset(index: Int) -> CGFloat {
        let offsets: [CGFloat] = [-3, 0, 3]
        return phase3 ? offsets[(index + 1) % 3] : offsets[index]
    }
}

#Preview {
    ChatIllustrationPreviewWrapper()
}

private struct ChatIllustrationPreviewWrapper: View {
    @State private var p1 = true
    @State private var p2 = true
    @State private var p3 = true
    @State private var cr = false
    @State private var fo: CGFloat = 4

    var body: some View {
        ChatIllustration(
            phase1: $p1,
            phase2: $p2,
            phase3: $p3,
            continuousRotation: $cr,
            floatOffset: $fo
        )
    }
}

#if !canImport(UIKit)
extension Color {
    static var brandPurple: Color { .purple }
    static var brandVibrantBlue: Color { .blue }
    static var brandBorder: Color { .gray }
    static var brandSkyBlue: Color { .cyan }
}
#endif
