import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct FlipCard<Front: View, Back: View>: View {
    @State private var isFlipped = false
    @State private var flipDegrees = 0.0
    
    let front: Front
    let back: Back
    
    init(@ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.front = front()
        self.back = back()
    }
    
    var body: some View {
        ZStack {
            // Front side
            front
                .rotation3DEffect(
                    .degrees(flipDegrees),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(flipDegrees < 90 ? 1 : 0)
            
            // Back side
            back
                .rotation3DEffect(
                    .degrees(flipDegrees - 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(flipDegrees < 90 ? 0 : 1)
        }
        .onTapGesture {
            flip()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Card")
        .accessibilityHint("Double tap to flip card")
    }
    
    private func flip() {
        // Haptic feedback
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        #endif
        
        withAnimation(.interactiveSpring(response: 0.8, dampingFraction: 0.8)) {
            isFlipped.toggle()
            flipDegrees = isFlipped ? 180 : 0
        }
    }
}

// Premium card with Apple Intelligence styling
struct PremiumCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.5, blue: 1.0),
                            Color(red: 0.4, green: 0.3, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 200, height: 160)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(
                    color: .black.opacity(0.1),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
    }
}

// Usage Example
struct FlipCardDemo: View {
    var body: some View {
        VStack(spacing: 30) {
            FlipCard {
                PremiumCard(
                    title: "Analytics",
                    subtitle: "View your spending insights",
                    systemImage: "chart.bar.fill"
                )
            } back: {
                PremiumCard(
                    title: "Details",
                    subtitle: "Monthly spending: $2,450\nTop category: Dining",
                    systemImage: "info.circle.fill"
                )
            }
            
            Text("Tap to flip")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}