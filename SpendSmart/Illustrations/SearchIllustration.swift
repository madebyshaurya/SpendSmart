import SwiftUI

struct SearchIllustration: View {
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
                        colors: [Color.brandRoyalBlue.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .scaleEffect(phase1 ? 1.0 : 0.5)

            ForEach(0..<3) { index in
                searchElement(index: index)
                    .offset(searchElementOffset(for: index))
                    .scaleEffect(phase2 ? 1.0 : 0.5)
                    .opacity(phase2 ? 0.8 : 0)
            }

            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.brandVibrantBlue, .brandRoyalBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 8
                    )
                    .frame(width: 70, height: 70)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.brandIceBlue.opacity(0.6), .brandSoftBlue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 62, height: 62)

                Ellipse()
                    .fill(.white.opacity(0.5))
                    .frame(width: 20, height: 10)
                    .offset(x: -12, y: -15)
                    .rotationEffect(.degrees(-30))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.brandVibrantBlue, .brandRoyalBlue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 12, height: 40)
                    .offset(x: 35, y: 35)
                    .rotationEffect(.degrees(45))
            }
            .offset(y: -floatOffset / 2)
            .scaleEffect(phase1 ? 1.0 : 0.3)
            .opacity(phase1 ? 1 : 0)

            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.1), radius: 5)

                Text("?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.brandVibrantBlue)
            }
            .offset(x: 50, y: -40)
            .scaleEffect(phase3 ? 1.0 : 0.5)
            .opacity(phase3 ? 1 : 0)
        }
#else
        EmptyView()
#endif
    }

    private func searchElement(index: Int) -> some View {
        Group {
            if index == 0 {
                Image(systemName: "doc.text")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandVibrantBlue.opacity(0.5))
            } else if index == 1 {
                Image(systemName: "tag")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandSkyBlue.opacity(0.6))
            } else {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandRoyalBlue.opacity(0.5))
            }
        }
    }

    private func searchElementOffset(for index: Int) -> CGSize {
        let offsets: [CGSize] = [
            CGSize(width: -70, height: -40 + floatOffset),
            CGSize(width: 70, height: 30 - floatOffset),
            CGSize(width: -50, height: 60 + floatOffset / 2)
        ]
        return offsets[index]
    }
}

#Preview {
    SearchIllustrationPreviewWrapper()
}

private struct SearchIllustrationPreviewWrapper: View {
    @State private var p1 = true
    @State private var p2 = true
    @State private var p3 = true
    @State private var cr = false
    @State private var fo: CGFloat = 4

    var body: some View {
        SearchIllustration(
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
    static var brandRoyalBlue: Color { .indigo }
    static var brandVibrantBlue: Color { .blue }
    static var brandIceBlue: Color { .white }
    static var brandSoftBlue: Color { .gray }
    static var brandSkyBlue: Color { .cyan }
}
#endif
