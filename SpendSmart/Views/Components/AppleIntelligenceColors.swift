import SwiftUI

// Apple Intelligence inspired gradient colors and effects
extension Color {
    // Primary Apple Intelligence gradients
    static let aiBlue = LinearGradient(
        colors: [
            Color(red: 0.2, green: 0.5, blue: 1.0),
            Color(red: 0.4, green: 0.3, blue: 0.9)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let aiPurple = LinearGradient(
        colors: [
            Color(red: 0.4, green: 0.3, blue: 0.9),
            Color(red: 0.6, green: 0.2, blue: 0.8)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let aiTeal = LinearGradient(
        colors: [
            Color(red: 0.2, green: 0.7, blue: 0.9),
            Color(red: 0.3, green: 0.6, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let aiPink = LinearGradient(
        colors: [
            Color(red: 0.9, green: 0.3, blue: 0.6),
            Color(red: 0.8, green: 0.4, blue: 0.9)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let aiGreen = LinearGradient(
        colors: [
            Color(red: 0.3, green: 0.8, blue: 0.5),
            Color(red: 0.2, green: 0.9, blue: 0.7)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Subtle background gradients
    static let aiBackground = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.98, blue: 1.0),
            Color(red: 0.95, green: 0.97, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let aiBackgroundDark = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.08, blue: 0.12),
            Color(red: 0.12, green: 0.08, blue: 0.15)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Apple Intelligence themed components
struct AIGlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.2),
                                        .clear,
                                        .white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.15),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )
    }
}

struct AIFloatingButton: View {
    let systemImage: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.aiBlue)
                        .shadow(
                            color: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.4),
                            radius: isPressed ? 8 : 16,
                            x: 0,
                            y: isPressed ? 4 : 8
                        )
                )
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(
            .interactiveSpring(response: 0.4, dampingFraction: 0.7),
            value: isPressed
        )
        .buttonStyle(AIFABButtonStyle(isPressed: $isPressed))
    }
}

// Animated progress indicator with AI styling
struct AIProgressRing: View {
    let progress: Double
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    Color.aiBlue,
                    style: StrokeStyle(
                        lineWidth: 8,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    .interactiveSpring(response: 1.2, dampingFraction: 0.8),
                    value: animatedProgress
                )
            
            // Center text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.aiBlue)
        }
        .frame(width: 120, height: 120)
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.interactiveSpring(response: 1.0, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// Example usage showcase
struct AIComponentShowcase: View {
    @State private var showModal = false
    @State private var progress: Double = 0.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("Apple Intelligence UI")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.aiBlue)
                    
                    Text("Beautiful micro-interactions")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Glass card example
                AIGlassCard {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(Color.aiPurple)
                        
                        Text("AI-Powered Insights")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Get intelligent spending recommendations based on your patterns")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Progress ring
                AIProgressRing(progress: progress)
                    .onTapGesture {
                        progress = Double.random(in: 0.2...1.0)
                    }
                
                // Floating action button
                HStack {
                    Spacer()
                    AIFloatingButton(systemImage: "plus") {
                        showModal = true
                    }
                }
                .padding(.trailing, 24)
            }
            .padding(24)
        }
        .background(Color.aiBackground.ignoresSafeArea())
        .overlay {
            if showModal {
                SpringModal(isPresented: $showModal) {
                    VStack(spacing: 24) {
                        Text("New Feature")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("This modal slides up with a beautiful spring animation and can be dismissed by dragging down or tapping the background.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Close") {
                            showModal = false
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.aiPurple)
                        )
                    }
                }
            }
        }
    }
}

// Custom ButtonStyle for AIFloatingButton
struct AIFABButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onAppear {
                isPressed = configuration.isPressed
            }
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}