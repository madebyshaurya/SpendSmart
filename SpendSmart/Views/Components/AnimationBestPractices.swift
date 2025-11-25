import SwiftUI

// MARK: - Animation Best Practices & Performance Guide

/*
 ANIMATION TIMING & EASING CURVES
 
 Apple's Human Interface Guidelines recommend these timing functions:
 
 1. Interactive Spring (Recommended for most UI)
    - response: 0.4-0.8 (how quickly animation reaches target)
    - dampingFraction: 0.6-0.8 (controls bounce/overshoot)
    - blendDuration: 0.25 (smooth transitions between animations)
 
 2. Ease Curves for Non-Interactive
    - .easeInOut: Natural feel for most transitions
    - .easeOut: Good for appearing elements
    - .easeIn: Good for disappearing elements
 
 3. Custom Cubic Bezier (Advanced)
    - Animation(.timingCurve(0.25, 0.1, 0.25, 1.0))
    - Use for fine-tuned control
*/

// MARK: - Performance Optimization Techniques

struct PerformantAnimationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            // ✅ GOOD: Use .animation with specific values
            Rectangle()
                .fill(Color.blue)
                .frame(width: isAnimating ? 200 : 100, height: 100)
                .animation(.interactiveSpring(), value: isAnimating)
            
            // ✅ GOOD: Combine multiple animations efficiently
            Text("Animated Text")
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isAnimating)
            
            Button("Toggle") {
                isAnimating.toggle()
            }
        }
    }
}

// MARK: - Accessibility Guidelines

struct AccessibleAnimationView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            Button("Toggle Details") {
                isExpanded.toggle()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Expands to show additional information")
            
            if isExpanded {
                Text("Additional details here...")
                    .transition(
                        // Respect reduce motion preference
                        reduceMotion ? .opacity : .slide.combined(with: .opacity)
                    )
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2) : .interactiveSpring(),
            value: isExpanded
        )
    }
}

// MARK: - Memory & Performance Considerations

/*
 PERFORMANCE BEST PRACTICES:
 
 1. Use @State for animation values instead of @ObservedObject when possible
    - @State is more efficient for local animation state
    - Reduces unnecessary view updates
 
 2. Prefer .animation(value:) over .animation() (deprecated)
    - More predictable behavior
    - Better performance with specific triggers
 
 3. Use withAnimation sparingly for complex sequences
    - Wrap only the state changes that need animation
    - Avoid animating too many properties simultaneously
 
 4. Optimize shadow usage
    - Use .shadow() sparingly (expensive on GPU)
    - Consider using background colors instead of complex shadows
    - Reduce shadow radius for better performance
 
 5. Frame rate considerations
    - Target 60fps for smooth animations
    - Use Instruments to profile animation performance
    - Test on older devices (iPhone SE, older iPads)
 
 6. Memory management
    - Dispose of animation timers properly
    - Avoid memory leaks with long-running animations
    - Use .onDisappear to clean up resources
*/

// MARK: - Responsive Design Patterns

struct ResponsiveAnimatedCard: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var isPressed = false
    
    var body: some View {
        VStack {
            Text("Responsive Card")
                .font(.title2.weight(.semibold))
        }
        .frame(
            maxWidth: horizontalSizeClass == .compact ? .infinity : 300,
            minHeight: 120
        )
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: isPressed)
        .onTapGesture {
            // Provide different haptic feedback based on device size
            let style: UIImpactFeedbackGenerator.FeedbackStyle = 
                horizontalSizeClass == .compact ? .medium : .light
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
        .pressEvents {
            isPressed = true
        } onPressEnded: {
            isPressed = false
        }
    }
}

// MARK: - Animation Presets for Consistency

struct AnimationPresets {
    // Quick interactions (buttons, taps)
    static let quickResponse = Animation.interactiveSpring(
        response: 0.4,
        dampingFraction: 0.6,
        blendDuration: 0.25
    )
    
    // Smooth transitions (views, modals)
    static let smoothTransition = Animation.interactiveSpring(
        response: 0.7,
        dampingFraction: 0.8,
        blendDuration: 0.3
    )
    
    // Playful interactions (cards, games)
    static let playfulBounce = Animation.interactiveSpring(
        response: 0.5,
        dampingFraction: 0.6,
        blendDuration: 0.4
    )
    
    // Subtle feedback (progress, status)
    static let subtleFeedback = Animation.easeInOut(duration: 0.3)
    
    // Attention-grabbing (errors, warnings)
    static let attention = Animation.easeInOut(duration: 0.2).repeatCount(2, autoreverses: true)
}

// MARK: - Testing Animation Performance

/*
 TESTING YOUR ANIMATIONS:
 
 1. Device Testing
    - Test on iPhone SE (slowest supported device)
    - Test on iPad with split screen
    - Test with accessibility settings enabled
 
 2. Performance Monitoring
    - Use Xcode's Animation Hitches instrument
    - Monitor for dropped frames during animation
    - Check memory usage during complex animations
 
 3. Accessibility Testing
    - Enable "Reduce Motion" in Settings
    - Test with VoiceOver enabled
    - Ensure animations don't interfere with navigation
 
 4. Edge Cases
    - Rapid successive taps/gestures
    - Interrupting animations mid-flight
    - Low battery mode behavior
    - Background/foreground transitions
*/

// Example of performance-conscious implementation
struct OptimizedAnimationExample: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Rectangle()
            .fill(Color.aiBlue)
            .frame(width: 100, height: 100)
            .scaleEffect(scale)
            .opacity(opacity)
            // Combine animations for efficiency
            .animation(.interactiveSpring(), value: scale)
            .animation(.interactiveSpring(), value: opacity)
            .onTapGesture {
                // Animate multiple properties together for better performance
                scale = scale == 1.0 ? 1.2 : 1.0
                opacity = opacity == 1.0 ? 0.7 : 1.0
            }
    }
}