import SwiftUI

struct SplashView: View {
    @State private var pulse = false
    @State private var glow = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: scenePhase != .active)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                MeshGradient(width: 3, height: 3, points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5],
                    [Float(0.5 + 0.08 * cos(time * 0.3)), Float(0.5 + 0.06 * sin(time * 0.4))],
                    [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ], colors: [
                    .brandDeepNavy, .brandDeepNavy.opacity(0.9), .brandDeepNavy,
                    .brandDarkNavy, .brandVibrantBlue.opacity(0.4), .brandMidnightBlue,
                    .brandDeepNavy, .brandDarkNavy, .brandDeepNavy
                ])
                .drawingGroup()
            }
            .ignoresSafeArea()

            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.brandSkyBlue.opacity(0.6),
                                Color.brandVibrantBlue.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(pulse ? 1.06 : 0.94)
                    .opacity(pulse ? 0.25 : 0.7)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.brandVibrantBlue.opacity(0.5),
                                Color.brandSkyBlue.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 210, height: 210)
                    .scaleEffect(glow ? 1.08 : 0.9)
                    .opacity(glow ? 0.2 : 0.6)
            }

            FloatingReceipt(
                size: CGSize(width: 130, height: 170),
                baseOffset: CGSize(width: -140, height: -120),
                rotation: -12,
                delay: 0.2
            )

            FloatingReceipt(
                size: CGSize(width: 110, height: 150),
                baseOffset: CGSize(width: 160, height: -80),
                rotation: 14,
                delay: 0.6
            )

            FloatingReceipt(
                size: CGSize(width: 120, height: 160),
                baseOffset: CGSize(width: 130, height: 160),
                rotation: -8,
                delay: 0.4
            )

            VStack(spacing: 18) {
                Text("SpendSmart")
                    .font(.instrumentSerifItalic(size: 52))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 8)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandSkyBlue))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

private struct FloatingReceipt: View {
    let size: CGSize
    let baseOffset: CGSize
    let rotation: Double
    let delay: Double

    @State private var float = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.brandSurface.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.brandBorder.opacity(0.6), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brandVibrantBlue.opacity(0.5))
                    .frame(width: size.width * 0.5, height: 8)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brandBorder)
                    .frame(width: size.width * 0.7, height: 6)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brandBorder)
                    .frame(width: size.width * 0.6, height: 6)

                Spacer()

                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.brandSkyBlue.opacity(0.7))
                        .frame(width: size.width * 0.35, height: 10)

                    Spacer()
                }
            }
            .padding(14)
        }
        .frame(width: size.width, height: size.height)
        .rotationEffect(.degrees(rotation + (float ? 3 : -3)))
        .offset(
            x: baseOffset.width + (float ? 10 : -10),
            y: baseOffset.height + (float ? -12 : 12)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.4).delay(delay).repeatForever(autoreverses: true)) {
                float = true
            }
        }
    }
}

#Preview {
    SplashView()
}
