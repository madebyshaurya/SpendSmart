import SwiftUI

extension Animation {
    // MARK: - Emil Kowalski / Animations.dev Inspired Easing
    
    /// Instant response, settling gently. Best for modal presentations, dropdowns, and entrances.
    /// CSS Equivalent: cubic-bezier(0.165, 0.84, 0.44, 1) (ease-out-quart)
    static var brandEaseOut: Animation {
        .timingCurve(0.165, 0.84, 0.44, 1, duration: 0.3)
    }
    
    /// Snappy entrance for small UI elements (micro-interactions).
    /// CSS Equivalent: cubic-bezier(0.23, 1, 0.32, 1) (ease-out-quint)
    static var brandSnappyOut: Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: 0.25)
    }
    
    /// Smooth movement for on-screen elements changing state.
    /// CSS Equivalent: cubic-bezier(0.77, 0, 0.175, 1) (ease-in-out-quart)
    static var brandEaseInOut: Animation {
        .timingCurve(0.77, 0, 0.175, 1, duration: 0.35)
    }
    
    /// Gentle transition for hover/color changes.
    /// CSS Equivalent: cubic-bezier(0.25, 0.1, 0.25, 1) (ease)
    static var brandEase: Animation {
        .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2)
    }
    
    // MARK: - Springs
    
    /// Natural spring for interactive elements (drag, scale).
    /// "Apple style": Duration ~0.5, Bounce ~0.3
    static var brandSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
    }
    
    /// Bouncy spring for "viral" or playful elements (Roast, Aura).
    static var brandBouncy: Animation {
        .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    }
    
    /// Snappy spring for quick feedback
    static var brandSnappy: Animation {
        .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    }
    
    /// Gentle spring for subtle movements
    static var brandGentle: Animation {
        .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
    }
    
    // MARK: - Semantic Animations
    
    /// Tab bar icon bounce
    static var tabBounce: Animation {
        .spring(response: 0.35, dampingFraction: 0.5, blendDuration: 0)
    }
    
    /// Card press feedback
    static var cardPress: Animation {
        .spring(response: 0.25, dampingFraction: 0.6, blendDuration: 0)
    }
    
    /// Pull to refresh snap
    static var pullToRefresh: Animation {
        .spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0)
    }
    
    /// Success celebration bounce
    static var celebration: Animation {
        .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0)
    }
    
    /// Smooth scroll deceleration
    static var smoothScroll: Animation {
        .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.4)
    }
}

// MARK: - View Modifier for Entrance

struct BrandEntranceModifier: ViewModifier {
    let index: Int
    let delay: Double
    let direction: EntranceDirection
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    enum EntranceDirection {
        case fromBottom
        case fromTop
        case fromLeft
        case fromRight
        case scale
        case fade
    }
    
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(scaleValue)
                .offset(offsetValue)
                .onAppear {
                    withAnimation(.spring(duration: 0.35, bounce: 0.12).delay(Double(index) * delay)) {
                        isVisible = true
                    }
                }
        }
    }
    
    private var scaleValue: CGFloat {
        guard !isVisible else { return 1 }
        switch direction {
        case .scale: return 0.9
        case .fromBottom, .fromTop, .fromLeft, .fromRight: return 0.96
        case .fade: return 1
        }
    }
    
    private var offsetValue: CGSize {
        guard !isVisible else { return .zero }
        switch direction {
        case .fromBottom: return CGSize(width: 0, height: 20)
        case .fromTop: return CGSize(width: 0, height: -20)
        case .fromLeft: return CGSize(width: -20, height: 0)
        case .fromRight: return CGSize(width: 20, height: 0)
        case .scale, .fade: return .zero
        }
    }
}

extension View {
    /// Animate view entrance with Scale + Opacity + Slide (The "Emil" Standard)
    func animateEntrance(
        index: Int = 0,
        delay: Double = 0.04,
        direction: BrandEntranceModifier.EntranceDirection = .fromBottom
    ) -> some View {
        modifier(BrandEntranceModifier(index: index, delay: delay, direction: direction))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isActive {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                        .animation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: phase
                        )
                    }
                }
            )
            .mask(content)
            .onAppear {
                if isActive {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Add shimmer loading effect
    func shimmer(_ isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Bounce on Tap

struct BounceOnTapModifier: ViewModifier {
    @State private var isPressed = false
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.brandSnappy, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

extension View {
    /// Add bounce effect on tap
    func bounceOnTap(action: @escaping () -> Void) -> some View {
        modifier(BounceOnTapModifier(action: action))
    }
}

// MARK: - Pulse Animation

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let isActive: Bool
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.8)
                    .animation(
                        .easeOut(duration: 1.0)
                        .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear {
                if isActive {
                    isPulsing = true
                }
            }
    }
}

extension View {
    /// Add pulsing ring effect (for attention-grabbing)
    func pulse(isActive: Bool = true, color: Color = .brandVibrantBlue) -> some View {
        modifier(PulseModifier(isActive: isActive, color: color))
    }
}

// MARK: - Shake Animation

struct ShakeModifier: ViewModifier {
    let trigger: Int
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, _ in
                withAnimation(.linear(duration: 0.05)) {
                    offset = 8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.linear(duration: 0.05)) { offset = -8 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.linear(duration: 0.05)) { offset = 6 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.linear(duration: 0.05)) { offset = -6 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.linear(duration: 0.05)) { offset = 0 }
                }
            }
    }
}

extension View {
    /// Shake animation for errors (increment trigger to shake)
    func shake(trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

// MARK: - Floating Animation

struct FloatModifier: ViewModifier {
    @State private var isFloating = false
    let amplitude: CGFloat
    let speed: Double
    
    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? amplitude : -amplitude)
            .animation(
                .easeInOut(duration: speed)
                .repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear {
                isFloating = true
            }
    }
}

extension View {
    /// Gentle floating animation (for illustrations, empty states)
    func floating(amplitude: CGFloat = 8, speed: Double = 2.0) -> some View {
        modifier(FloatModifier(amplitude: amplitude, speed: speed))
    }
}

// MARK: - Scale on Appear

struct ScaleOnAppearModifier: ViewModifier {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.brandBouncy.delay(delay)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

extension View {
    /// Pop-in animation on appear
    func scaleOnAppear(delay: Double = 0) -> some View {
        modifier(ScaleOnAppearModifier(delay: delay))
    }
}

// MARK: - Typewriter Effect

struct TypewriterModifier: ViewModifier {
    let text: String
    let speed: Double
    @State private var displayedText = ""
    @State private var currentIndex = 0
    
    func body(content: Content) -> some View {
        Text(displayedText)
            .onAppear {
                startTyping()
            }
    }
    
    private func startTyping() {
        guard currentIndex < text.count else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            let index = text.index(text.startIndex, offsetBy: currentIndex)
            displayedText += String(text[index])
            currentIndex += 1
            startTyping()
        }
    }
}

extension View {
    /// Typewriter text reveal effect
    func typewriter(text: String, speed: Double = 0.05) -> some View {
        modifier(TypewriterModifier(text: text, speed: speed))
    }
}

// MARK: - Parallax Tilt Effect

struct ParallaxTiltModifier: ViewModifier {
    @State private var dragOffset: CGSize = .zero
    let intensity: CGFloat

    init(intensity: CGFloat = 8) {
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(Double(dragOffset.height / intensity)),
                axis: (x: -1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(Double(dragOffset.width / intensity)),
                axis: (x: 0, y: 1, z: 0)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        withAnimation(.interactiveSpring(response: 0.15)) {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.brandBouncy) {
                            dragOffset = .zero
                        }
                    }
            )
    }
}

extension View {
    /// Adds a subtle 3D parallax tilt when the user drags on the view.
    /// Great for cards, share cards, and hero sections.
    func parallaxTilt(intensity: CGFloat = 8) -> some View {
        modifier(ParallaxTiltModifier(intensity: intensity))
    }
}

// MARK: - Continuous Rotation

struct ContinuousRotationModifier: ViewModifier {
    @State private var rotation: Double = 0
    let duration: Double
    let clockwise: Bool
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    rotation = clockwise ? 360 : -360
                }
            }
    }
}

extension View {
    /// Continuous rotation (for loading indicators)
    func continuousRotation(duration: Double = 1.0, clockwise: Bool = true) -> some View {
        modifier(ContinuousRotationModifier(duration: duration, clockwise: clockwise))
    }
}
