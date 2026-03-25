import SwiftUI

struct DashboardIllustration: View {
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
                        colors: [Color.brandDeepNavy.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .scaleEffect(phase1 ? 1.0 : 0.5)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<5) { index in
                    chartBar(index: index)
                }
            }
            .offset(y: 20)

            ZStack {
                Circle()
                    .trim(from: 0, to: 0.35)
                    .stroke(Color.brandVibrantBlue, lineWidth: 12)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0.35, to: 0.65)
                    .stroke(Color.brandSkyBlue, lineWidth: 12)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0.65, to: 1.0)
                    .stroke(Color.brandRoyalBlue, lineWidth: 12)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
            }
            .offset(x: -55, y: -50 - floatOffset)
            .scaleEffect(phase2 ? 1.0 : 0.5)
            .opacity(phase2 ? 1 : 0)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.brandSuccess)
                .offset(x: 60, y: -60 + floatOffset / 2)
                .scaleEffect(phase3 ? 1.0 : 0.3)
                .opacity(phase3 ? 1 : 0)

            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.1), radius: 5)

                Text("$")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.brandVibrantBlue)
            }
            .offset(x: 50, y: 40 - floatOffset / 3)
            .scaleEffect(phase3 ? 1.0 : 0.5)
            .opacity(phase3 ? 1 : 0)
        }
#else
        EmptyView()
#endif
    }

    private func chartBar(index: Int) -> some View {
        let heights: [CGFloat] = [40, 65, 50, 80, 55]
        let delays: [Double] = [0.1, 0.2, 0.15, 0.25, 0.3]
        let colors: [Color] = [.brandSkyBlue, .brandVibrantBlue, .brandRoyalBlue, .brandVibrantBlue, .brandSkyBlue]

        return RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [colors[index], colors[index].opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 16, height: phase1 ? heights[index] : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(delays[index]), value: phase1)
    }
}

#Preview {
    DashboardIllustrationPreviewWrapper()
}

private struct DashboardIllustrationPreviewWrapper: View {
    @State private var p1 = true
    @State private var p2 = true
    @State private var p3 = true
    @State private var cr = false
    @State private var fo: CGFloat = 4

    var body: some View {
        DashboardIllustration(
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
    static var brandDeepNavy: Color { .blue }
    static var brandVibrantBlue: Color { .blue }
    static var brandSkyBlue: Color { .cyan }
    static var brandRoyalBlue: Color { .indigo }
    static var brandSuccess: Color { .green }
}
#endif
