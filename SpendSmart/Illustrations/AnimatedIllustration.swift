import SwiftUI

struct AnimatedIllustration: View {
    let type: IllustrationType

    @State private var phase1 = false
    @State private var phase2 = false
    @State private var phase3 = false
    @State private var continuousRotation = false
    @State private var floatOffset: CGFloat = 0

    enum IllustrationType: Hashable {
        case receipts
        case receiptsSearch
        case dashboard
        case map
        case chat
    }

    var body: some View {
        Group {
#if canImport(UIKit)
            switch type {
            case .receipts:
                ReceiptsIllustration(phase1: $phase1, phase2: $phase2, phase3: $phase3, continuousRotation: $continuousRotation, floatOffset: $floatOffset)
            case .receiptsSearch:
                SearchIllustration(phase1: $phase1, phase2: $phase2, phase3: $phase3, continuousRotation: $continuousRotation, floatOffset: $floatOffset)
            case .dashboard:
                DashboardIllustration(phase1: $phase1, phase2: $phase2, phase3: $phase3, continuousRotation: $continuousRotation, floatOffset: $floatOffset)
            case .map:
                MapIllustration(phase1: $phase1, phase2: $phase2, phase3: $phase3, continuousRotation: $continuousRotation, floatOffset: $floatOffset)
            case .chat:
                ChatIllustration(phase1: $phase1, phase2: $phase2, phase3: $phase3, continuousRotation: $continuousRotation, floatOffset: $floatOffset)
            }
#else
            EmptyView()
#endif
        }
        .frame(width: 200, height: 200)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            phase1 = true
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            phase2 = true
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            phase3 = true
        }

        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            continuousRotation = true
        }

        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            floatOffset = 8
        }
    }
}

#Preview("Receipts") {
    AnimatedIllustration(type: .receipts)
        .padding()
}

#Preview("Search") {
    AnimatedIllustration(type: .receiptsSearch)
        .padding()
}

#Preview("Dashboard") {
    AnimatedIllustration(type: .dashboard)
        .padding()
}

#Preview("Map") {
    AnimatedIllustration(type: .map)
        .padding()
}

#Preview("Chat") {
    AnimatedIllustration(type: .chat)
        .padding()
}

#Preview("All Illustrations") {
    ScrollView {
        VStack(spacing: 40) {
            ForEach([
                AnimatedIllustration.IllustrationType.receipts,
                .receiptsSearch,
                .dashboard,
                .map,
                .chat
            ], id: \.self) { type in
                VStack {
                    AnimatedIllustration(type: type)
                    Text("\(String(describing: type))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
