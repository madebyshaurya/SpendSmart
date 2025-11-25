//
//  FluidAnimations.swift
//  SpendSmart
//
//  iOS 26 Fluid Animation System
//  Builds on AnimationSystem.swift with Liquid Glass-specific animations
//

import SwiftUI

/// iOS 26 fluid animation presets
/// Provides glass-specific animations and coordinated multi-element effects
struct FluidAnimations {

    // MARK: - Glass Interaction Springs

    /// Quick compression animation for glass press
    static let glassPress = Animation.spring(
        response: 0.25,
        dampingFraction: 0.75,
        blendDuration: 0
    )

    /// Bouncy restoration animation for glass release
    static let glassRelease = Animation.spring(
        response: 0.4,
        dampingFraction: 0.65,
        blendDuration: 0
    )

    /// Morphing transition for state changes
    static let morphing = Animation.spring(
        response: 0.5,
        dampingFraction: 0.8,
        blendDuration: 0.1
    )

    /// Elastic drag for swipe gestures
    static let elasticDrag = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 120.0,
        damping: 12.0,
        initialVelocity: 0
    )

    /// Smooth slide for sheet presentations
    static let smoothSlide = Animation.spring(
        response: 0.45,
        dampingFraction: 0.85,
        blendDuration: 0
    )

    // MARK: - Staggered Animations

    /// Generate staggered delays for list items
    /// - Parameters:
    ///   - count: Number of items to stagger
    ///   - baseDelay: Base delay between items (default: 0.08)
    /// - Returns: Array of delay values
    static func stagger(count: Int, baseDelay: Double = 0.08) -> [Double] {
        (0..<count).map { Double($0) * baseDelay }
    }

    /// Generate cascade animations for multiple views
    /// - Parameters:
    ///   - views: Number of views to animate
    ///   - interval: Time interval between animations (default: 0.06)
    /// - Returns: Array of animations with progressive delays
    static func cascade(views: Int, interval: Double = 0.06) -> [Animation] {
        (0..<views).map { index in
            AnimationSystem.spring.delay(Double(index) * interval)
        }
    }

    // MARK: - Number Rolling

    /// Smooth number roll animation for currency values
    /// - Parameter duration: Duration of the roll (default: 0.8)
    /// - Returns: Spring animation for number rolling
    static func numberRoll(duration: Double = 0.8) -> Animation {
        .spring(response: duration, dampingFraction: 0.85)
    }

    // MARK: - Entrance Animations

    /// Fade in with scale animation
    static let fadeInScale = Animation.spring(
        response: 0.5,
        dampingFraction: 0.75
    )

    /// Slide up entrance animation
    static let slideUp = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8
    )
}

// MARK: - View Modifiers

extension View {

    /// Glass transition (scale + blur effect)
    /// Use for modal presentations and dismissals
    /// - Returns: View with glass transition
    func glassTransition() -> some View {
        self
            .transition(
                .scale(scale: 0.92)
                .combined(with: .opacity)
            )
    }

    /// Fluid scale based on pressed state
    /// Animates scale with glass press/release animations
    /// - Parameter pressed: Whether the view is currently pressed
    /// - Returns: View with fluid scale animation
    func fluidScale(pressed: Bool) -> some View {
        self
            .scaleEffect(pressed ? 0.95 : 1.0)
            .animation(
                pressed ? FluidAnimations.glassPress : FluidAnimations.glassRelease,
                value: pressed
            )
    }

    /// Elastic drag gesture offset animation
    /// Use for swipeable items with rubber-band effect
    /// - Parameter offset: The drag offset value
    /// - Returns: View with elastic drag animation
    func elasticDrag(offset: CGFloat) -> some View {
        self
            .offset(x: offset)
            .animation(FluidAnimations.elasticDrag, value: offset)
    }

    /// Staggered appearance animation for list items
    /// - Parameters:
    ///   - index: Index of the item in the list
    ///   - baseDelay: Base delay between items (default: 0.08)
    /// - Returns: View with staggered animation
    func staggeredAnimation(index: Int, baseDelay: Double = 0.08) -> some View {
        self
            .transition(.opacity.combined(with: .offset(y: 20)))
            .animation(
                AnimationSystem.spring.delay(Double(index) * baseDelay),
                value: index
            )
    }

    /// Morphing transition between states
    /// Use when content changes significantly
    /// - Parameter trigger: Value that triggers the morphing
    /// - Returns: View with morphing animation
    func morphing<V: Equatable>(trigger: V) -> some View {
        self
            .animation(FluidAnimations.morphing, value: trigger)
    }

    /// Smooth slide transition for sheets and modals
    /// - Parameter isPresented: Whether the view is presented
    /// - Returns: View with smooth slide animation
    func smoothSlide(isPresented: Bool) -> some View {
        self
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(FluidAnimations.smoothSlide, value: isPresented)
    }
}

// MARK: - Number Animation View

/// Animated number display with rolling effect
struct AnimatedNumber: View {
    let value: Double
    let format: NumberFormatter

    @State private var displayValue: Double = 0

    var body: some View {
        Text(formatted)
            .contentTransition(.numericText(value: value))
            .animation(FluidAnimations.numberRoll(), value: value)
            .onAppear {
                displayValue = value
            }
            .onChange(of: value) { oldValue, newValue in
                displayValue = newValue
            }
    }

    private var formatted: String {
        format.string(from: NSNumber(value: displayValue)) ?? ""
    }
}

// MARK: - Currency Animated Number

extension AnimatedNumber {
    /// Create animated number with currency formatting
    /// - Parameters:
    ///   - value: The numeric value to display
    ///   - currencyCode: Currency code (e.g., "USD")
    /// - Returns: AnimatedNumber view with currency formatting
    static func currency(value: Double, currencyCode: String = "USD") -> AnimatedNumber {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        return AnimatedNumber(value: value, format: formatter)
    }

    /// Create animated number with decimal formatting
    /// - Parameters:
    ///   - value: The numeric value to display
    ///   - decimalPlaces: Number of decimal places (default: 0)
    /// - Returns: AnimatedNumber view with decimal formatting
    static func decimal(value: Double, decimalPlaces: Int = 0) -> AnimatedNumber {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimalPlaces
        formatter.minimumFractionDigits = decimalPlaces
        return AnimatedNumber(value: value, format: formatter)
    }
}

// MARK: - Coordinated Animation Helper

/// Helper for coordinating multiple view animations
struct CoordinatedAnimation {

    /// Animate multiple views in sequence
    /// - Parameters:
    ///   - count: Number of views
    ///   - delay: Delay between each animation
    ///   - action: Closure to execute for each index
    static func sequence(count: Int, delay: Double = 0.1, action: @escaping (Int) -> Void) {
        for index in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * delay) {
                action(index)
            }
        }
    }

    /// Animate views in reverse sequence
    /// - Parameters:
    ///   - count: Number of views
    ///   - delay: Delay between each animation
    ///   - action: Closure to execute for each index
    static func reverseSequence(count: Int, delay: Double = 0.1, action: @escaping (Int) -> Void) {
        for index in (0..<count).reversed() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(count - index - 1) * delay) {
                action(index)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FluidAnimations_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Number animation
                VStack(spacing: 12) {
                    Text("Animated Numbers")
                        .font(.headline)

                    AnimatedNumber.currency(value: 1234.56, currencyCode: "USD")
                        .font(.largeTitle)

                    AnimatedNumber.decimal(value: 42, decimalPlaces: 0)
                        .font(.title)
                }

                Divider()

                // Glass press animation
                VStack(spacing: 12) {
                    Text("Glass Press Animation")
                        .font(.headline)

                    RoundedRectangle(cornerRadius: 16)
                        .fill(.blue.opacity(0.3))
                        .frame(width: 200, height: 100)
                        .fluidScale(pressed: false)
                }

                Divider()

                // Staggered list items
                VStack(spacing: 12) {
                    Text("Staggered Animations")
                        .font(.headline)

                    ForEach(0..<3) { index in
                        HStack {
                            Image(systemName: "circle.fill")
                            Text("Item \(index + 1)")
                            Spacer()
                        }
                        .padding()
                        .glassCard()
                        .staggeredAnimation(index: index)
                    }
                }
            }
            .padding()
        }
    }
}
#endif
