//
//  AnimationSystem.swift
//  SpendSmart
//
//  Apple-inspired animation system following Human Interface Guidelines
//

import SwiftUI

// MARK: - Animation System
struct AnimationSystem {
    
    // MARK: - Core Animation Curves (Apple HIG Standard)
    
    /// Smooth, natural easing for most UI transitions
    static let standard = Animation.easeInOut(duration: 0.3)
    
    /// Quick, responsive animation for immediate feedback
    static let snappy = Animation.easeOut(duration: 0.2)
    
    /// Gentle, slower animation for large state changes
    static let gentle = Animation.easeInOut(duration: 0.5)
    
    /// Bouncy spring animation for playful interactions
    static let bouncy = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 100.0,
        damping: 10.0,
        initialVelocity: 0.0
    )
    
    /// Smooth spring for natural movement
    static let spring = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8,
        blendDuration: 0.0
    )
    
    /// Crisp spring for precise interactions
    static let tightSpring = Animation.spring(
        response: 0.3,
        dampingFraction: 0.9,
        blendDuration: 0.0
    )
    
    /// Fluid spring for smooth, continuous movement
    static let fluidSpring = Animation.spring(
        response: 0.6,
        dampingFraction: 0.7,
        blendDuration: 0.0
    )
    
    // MARK: - Contextual Animations
    
    /// Animation for tab bar transitions
    static let tabTransition = Animation.easeInOut(duration: 0.25)
    
    /// Animation for sheet presentation/dismissal
    static let sheetTransition = Animation.easeInOut(duration: 0.4)
    
    /// Animation for card appearance/disappearance
    static let cardTransition = Animation.spring(response: 0.5, dampingFraction: 0.8)
    
    /// Animation for data updates and refreshes
    static let dataUpdate = Animation.easeInOut(duration: 0.3)
    
    /// Animation for form field focus/blur
    static let fieldFocus = Animation.easeOut(duration: 0.2)
    
    /// Animation for button press feedback
    static let buttonPress = Animation.easeOut(duration: 0.1)
    
    /// Animation for loading states
    static let loading = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    
    /// Animation for error states
    static let errorShake = Animation.spring(response: 0.3, dampingFraction: 0.3)
    
    /// Animation for success states
    static let successScale = Animation.spring(response: 0.4, dampingFraction: 0.6)
    
    // MARK: - Staggered Animations
    
    /// Creates staggered animation delays for list items
    static func staggerDelay(index: Int, baseDelay: Double = 0.05) -> Double {
        return Double(index) * baseDelay
    }
    
    /// Staggered animation for expense items appearing
    static func expenseItemAppear(index: Int) -> Animation {
        return standard.delay(staggerDelay(index: index, baseDelay: 0.03))
    }
    
    /// Staggered animation for category items appearing
    static func categoryItemAppear(index: Int) -> Animation {
        return spring.delay(staggerDelay(index: index, baseDelay: 0.05))
    }
}

// MARK: - Transition System
struct TransitionSystem {
    
    /// Smooth slide transition for navigation
    static let slideTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
    
    /// Scale transition for modal presentations
    static let scaleTransition = AnyTransition.scale(scale: 0.95).combined(with: .opacity)
    
    /// Slide up transition for sheets and overlays
    static let slideUpTransition = AnyTransition.move(edge: .bottom).combined(with: .opacity)
    
    /// Fade transition for content changes
    static let fadeTransition = AnyTransition.opacity
    
    /// Push transition for card-like content
    static let pushTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.98)),
        removal: .move(edge: .leading).combined(with: .scale(scale: 1.02))
    )
    
    /// Flip transition for state changes
    static let flipTransition = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.8).combined(with: .opacity),
        removal: .scale(scale: 1.2).combined(with: .opacity)
    )
    
    /// Collapse transition for content removal
    static let collapseTransition = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.01, anchor: .center).combined(with: .opacity),
        removal: .scale(scale: 0.01, anchor: .center).combined(with: .opacity)
    )
}

// MARK: - View Modifiers for Animations
struct AnimatedAppearance: ViewModifier {
    let animation: Animation
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(animation.delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

struct AnimatedScale: ViewModifier {
    let animation: Animation
    @State private var isScaled = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isScaled ? 1.0 : 0.8)
            .opacity(isScaled ? 1 : 0)
            .animation(animation, value: isScaled)
            .onAppear {
                isScaled = true
            }
    }
}

struct PressAnimation: ViewModifier {
    @State private var isPressed = false
    let hapticFeedback: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(AnimationSystem.buttonPress, value: isPressed)
            .onTapGesture {
                if hapticFeedback {
                    HapticFeedbackManager.shared.lightImpact()
                }
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Rectangle()
                        .offset(x: phase)
                        .animation(
                            isActive ? 
                            Animation.linear(duration: 1.5).repeatForever(autoreverses: false) : 
                            .default,
                            value: phase
                        )
                )
                .onAppear {
                    if isActive {
                        phase = 300
                    }
                }
                .opacity(isActive ? 1 : 0)
            )
    }
}

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(
                isActive ? 
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                .default,
                value: isPulsing
            )
            .onAppear {
                if isActive {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                isPulsing = newValue
            }
    }
}

struct RotationAnimation: ViewModifier {
    @State private var isRotating = false
    let isActive: Bool
    let speed: Double
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                isActive ?
                Animation.linear(duration: speed).repeatForever(autoreverses: false) :
                .default,
                value: isRotating
            )
            .onAppear {
                if isActive {
                    isRotating = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                isRotating = newValue
            }
    }
}

// MARK: - View Extensions
extension View {
    /// Adds smooth appearance animation with optional delay
    func animatedAppearance(
        animation: Animation = AnimationSystem.spring,
        delay: Double = 0
    ) -> some View {
        self.modifier(AnimatedAppearance(animation: animation, delay: delay))
    }
    
    /// Adds scale animation on appearance
    func animatedScale(animation: Animation = AnimationSystem.bouncy) -> some View {
        self.modifier(AnimatedScale(animation: animation))
    }
    
    /// Adds press animation with optional haptic feedback
    func pressAnimation(withHaptics: Bool = true) -> some View {
        self.modifier(PressAnimation(hapticFeedback: withHaptics))
    }
    
    /// Adds shimmer loading effect
    func shimmer(isActive: Bool = true) -> some View {
        self.modifier(ShimmerEffect(isActive: isActive))
    }
    
    /// Adds pulse animation
    func pulse(isActive: Bool = true) -> some View {
        self.modifier(PulseAnimation(isActive: isActive))
    }
    
    /// Adds rotation animation
    func rotate(isActive: Bool = true, speed: Double = 1.0) -> some View {
        self.modifier(RotationAnimation(isActive: isActive, speed: speed))
    }
    
    /// Adds contextual transition based on content type
    func contextualTransition(_ type: ContentTransitionType) -> some View {
        switch type {
        case .card:
            return self.transition(TransitionSystem.scaleTransition)
        case .list:
            return self.transition(TransitionSystem.slideTransition)
        case .modal:
            return self.transition(TransitionSystem.slideUpTransition)
        case .content:
            return self.transition(TransitionSystem.fadeTransition)
        case .navigation:
            return self.transition(TransitionSystem.pushTransition)
        }
    }
    
    /// Applies reduce motion preferences automatically
    func respectsMotionPreferences<V: Equatable>(
        value: V,
        animation: Animation = AnimationSystem.standard,
        reducedAnimation: Animation = .linear(duration: 0)
    ) -> some View {
        self.modifier(ReduceMotionModifier(animation: animation, reducedAnimation: reducedAnimation))
    }
    
    /// Adds staggered list animation
    func staggeredListAnimation(index: Int, type: ListAnimationType = .expense) -> some View {
        let animation = type == .expense ? 
            AnimationSystem.expenseItemAppear(index: index) :
            AnimationSystem.categoryItemAppear(index: index)
        
        return self.animatedAppearance(
            animation: animation,
            delay: AnimationSystem.staggerDelay(index: index)
        )
    }
}

// MARK: - Supporting Types
enum ContentTransitionType {
    case card, list, modal, content, navigation
}

enum ListAnimationType {
    case expense, category, subscription
}

// MARK: - Loading Animation Components
struct LoadingSpinner: View {
    @State private var isRotating = false
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 24, color: Color = DesignTokens.Colors.Primary.blue) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Circle()
            .stroke(color.opacity(0.3), lineWidth: 3)
            .overlay(
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(AnimationSystem.loading, value: isRotating)
            )
            .frame(width: size, height: size)
            .onAppear {
                isRotating = true
            }
    }
}

struct LoadingDots: View {
    @State private var animationState = 0
    let color: Color
    
    init(color: Color = DesignTokens.Colors.Primary.blue) {
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationState == index ? 1.2 : 0.8)
                    .opacity(animationState == index ? 1.0 : 0.5)
            }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.6).repeatForever()) {
                animationState = 2
            }
        }
    }
}

// MARK: - Gesture-Based Animations
// SwipeToDelete functionality moved to contextMenu for better iOS compliance