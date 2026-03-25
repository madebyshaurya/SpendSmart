import SwiftUI

struct MapIllustration: View {
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
                        colors: [Color.brandSuccess.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .scaleEffect(phase1 ? 1.0 : 0.5)

            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.brandIceBlue, .brandSoftBlue.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 100)
                .overlay(
                    ZStack {
                        ForEach(0..<3) { i in
                            Rectangle()
                                .fill(Color.brandBorder.opacity(0.5))
                                .frame(height: 1)
                                .offset(y: CGFloat(i - 1) * 30)
                        }

                        ForEach(0..<4) { i in
                            Rectangle()
                                .fill(Color.brandBorder.opacity(0.5))
                                .frame(width: 1)
                                .offset(x: CGFloat(i - 1) * 35)
                        }

                        Path { path in
                            path.move(to: CGPoint(x: -70, y: 20))
                            path.addCurve(
                                to: CGPoint(x: 70, y: -20),
                                control1: CGPoint(x: -20, y: 40),
                                control2: CGPoint(x: 30, y: -40)
                            )
                        }
                        .stroke(Color.brandVibrantBlue.opacity(0.4), lineWidth: 4)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .scaleEffect(phase1 ? 1.0 : 0.6)
                .opacity(phase1 ? 1 : 0)

            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 20, height: 8)
                    .offset(y: 22)

                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brandSuccess)
                    .shadow(color: Color.brandSuccess.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .offset(y: -floatOffset - 10)
            .scaleEffect(phase2 ? 1.0 : 0.3)
            .opacity(phase2 ? 1 : 0)

            ForEach(0..<2) { index in
                Circle()
                    .stroke(Color.brandSuccess.opacity(0.3), lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .scaleEffect(phase3 ? 2.5 : 1)
                    .opacity(phase3 ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.5),
                        value: phase3
                    )
                    .offset(y: -10)
            }

            ForEach(0..<2) { index in
                Image(systemName: "building.2.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brandRoyalBlue.opacity(0.5))
                    .offset(
                        x: index == 0 ? -50 : 45,
                        y: index == 0 ? 25 : -30
                    )
                    .scaleEffect(phase3 ? 1.0 : 0.5)
                    .opacity(phase3 ? 0.7 : 0)
            }
        }
#else
        EmptyView()
#endif
    }
}

#Preview {
    MapIllustrationPreviewWrapper()
}

private struct MapIllustrationPreviewWrapper: View {
    @State private var p1 = true
    @State private var p2 = true
    @State private var p3 = true
    @State private var cr = false
    @State private var fo: CGFloat = 4

    var body: some View {
        MapIllustration(
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
    static var brandSuccess: Color { .green }
    static var brandIceBlue: Color { .white }
    static var brandSoftBlue: Color { .gray }
    static var brandBorder: Color { .gray }
    static var brandVibrantBlue: Color { .blue }
    static var brandRoyalBlue: Color { .indigo }
}
#endif
