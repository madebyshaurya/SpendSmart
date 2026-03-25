import SwiftUI

struct ReceiptsIllustration: View {
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
                        colors: [Color.brandVibrantBlue.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .scaleEffect(phase1 ? 1.0 : 0.5)
                .opacity(phase1 ? 1 : 0)

            ForEach(0..<3) { index in
                receiptCard(index: index)
                    .offset(receiptOffset(for: index))
                    .rotationEffect(.degrees(Double(index - 1) * 8))
                    .scaleEffect(phase2 ? 1.0 : 0.6)
                    .opacity(phase2 ? 1 : 0)
            }

            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.brandVibrantBlue, .brandSkyBlue, .brandVibrantBlue],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(continuousRotation ? 360 : 0))

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.brandVibrantBlue, .brandRoyalBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .brandVibrantBlue.opacity(0.4), radius: 15, x: 0, y: 8)

                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .offset(y: -floatOffset / 2)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.8), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 50, height: 2)
                    .offset(y: phase3 ? 15 : -15)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: phase3)
            }
            .scaleEffect(phase1 ? 1.0 : 0.3)
            .opacity(phase1 ? 1 : 0)

            ForEach(0..<4) { index in
                sparkle(at: sparklePosition(index: index))
                    .opacity(phase3 ? 1 : 0)
            }
        }
#else
        EmptyView()
#endif
    }

    private func receiptCard(index: Int) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.white)
            .frame(width: 45, height: 60)
            .overlay(
                VStack(spacing: 4) {
                    ForEach(0..<4) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.brandBorder)
                            .frame(height: 3)
                    }
                }
                .padding(8)
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
    }

    private func receiptOffset(for index: Int) -> CGSize {
        let baseOffsets: [CGSize] = [
            CGSize(width: -60, height: -30 + floatOffset),
            CGSize(width: 65, height: -20 - floatOffset / 2),
            CGSize(width: 50, height: 50 + floatOffset / 3)
        ]
        return baseOffsets[index]
    }

    private func sparkle(at position: CGSize) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: 10))
            .foregroundStyle(Color.brandSkyBlue)
            .offset(position)
            .scaleEffect(phase3 ? 1.2 : 0.8)
            .opacity(phase3 ? 0.8 : 0.4)
            .animation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
                value: phase3
            )
    }

    private func sparklePosition(index: Int) -> CGSize {
        let positions: [CGSize] = [
            CGSize(width: -80, height: -50),
            CGSize(width: 85, height: -35),
            CGSize(width: -75, height: 60),
            CGSize(width: 80, height: 55)
        ]
        return positions[index]
    }
}

#Preview {
    ReceiptsIllustrationPreviewWrapper()
}

private struct ReceiptsIllustrationPreviewWrapper: View {
    @State private var p1 = true
    @State private var p2 = true
    @State private var p3 = true
    @State private var cr = false
    @State private var fo: CGFloat = 4

    var body: some View {
        ReceiptsIllustration(
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
    static var brandVibrantBlue: Color { .blue }
    static var brandSkyBlue: Color { .cyan }
    static var brandRoyalBlue: Color { .indigo }
    static var brandBorder: Color { .gray }
}
#endif
