import SwiftUI

struct AnimatedButton: View {
    @State private var isPressed = false
    @State private var shadowRadius: CGFloat = 8
    @State private var shadowY: CGFloat = 4
    
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // Haptic feedback for premium feel
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    // Apple Intelligence gradient
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.5, blue: 1.0),
                            Color(red: 0.4, green: 0.3, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.3),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowY
                )
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(
            .interactiveSpring(
                response: 0.4,
                dampingFraction: 0.6,
                blendDuration: 0.25
            ),
            value: isPressed
        )
        .animation(
            .easeInOut(duration: 0.15),
            value: shadowRadius
        )
        .pressEvents {
            // Press began - immediate feedback
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
                shadowRadius = 4
                shadowY = 2
            }
        } onPressEnded: {
            // Press ended - spring back with overshoot
            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.6)) {
                isPressed = false
                shadowRadius = 8
                shadowY = 4
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to activate")
    }
}

// Custom modifier for press detection
extension View {
    func pressEvents(onPressChanged: @escaping () -> Void, onPressEnded: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    onPressChanged()
                }
                .onEnded { _ in
                    onPressEnded()
                }
        )
    }
}

// Usage Example
struct ButtonDemo: View {
    var body: some View {
        VStack(spacing: 20) {
            AnimatedButton(title: "Get Started") {
                print("Button tapped!")
            }
            
            AnimatedButton(title: "Continue") {
                print("Continue tapped!")
            }
        }
        .padding()
    }
}