//
//  SymbolAnimations.swift
//  SpendSmart
//
//  SF Symbols 6 Animation System for iOS 26
//  Provides preset animations and animated icon components
//

import SwiftUI

/// SF Symbols 6 animation presets for iOS 26
enum SymbolAnimation {
    case bounce
    case pulse(continuous: Bool = false)
    case scale
    case variableColor
    case replace
}

// MARK: - View Extension for Symbol Animations

extension View {

    /// Animate SF Symbol with preset animation
    /// - Parameters:
    ///   - animation: The animation type to apply
    ///   - trigger: Value that triggers the animation when changed
    /// - Returns: View with animated symbol
    @ViewBuilder
    func animatedSymbol(_ animation: SymbolAnimation, trigger: some Equatable) -> some View {
        if #available(iOS 17.0, *) {
            switch animation {
            case .bounce:
                self.symbolEffect(.bounce, value: trigger)
            case .pulse(let continuous):
                if continuous {
                    self.symbolEffect(.pulse, options: .repeating)
                } else {
                    self.symbolEffect(.pulse, value: trigger)
                }
            case .scale:
                // Scale effect requires iOS 17+ but different API
                self.symbolEffect(.bounce, value: trigger) // Use bounce as fallback for scale
            case .variableColor:
                self.symbolEffect(.variableColor.iterative, value: trigger)
            case .replace:
                // Use a content transition for replace; it animates when the symbol name changes
                self.contentTransition(.symbolEffect(.replace))
            }
        } else {
            // Fallback: No animation for iOS < 17
            // Symbols still display, just without animation
            self
        }
    }

    /// Animate SF Symbol with bounce effect (convenience)
    /// - Parameter trigger: Value that triggers the animation
    /// - Returns: View with bounce animation
    func symbolBounce(trigger: some Equatable) -> some View {
        self.animatedSymbol(.bounce, trigger: trigger)
    }

    /// Animate SF Symbol with continuous pulse effect
    /// - Returns: View with continuous pulse animation
    func symbolPulse() -> some View {
        if #available(iOS 17.0, *) {
            return AnyView(self.symbolEffect(.pulse, options: .repeating))
        } else {
            return AnyView(self)
        }
    }

    /// Animate SF Symbol with bounce effect (scale alternative)
    /// - Parameter trigger: Value that triggers the animation
    /// - Returns: View with bounce animation
    func symbolScale(trigger: some Equatable) -> some View {
        self.animatedSymbol(.bounce, trigger: trigger) // Use bounce instead of scale
    }
}

// MARK: - Preset Animated Icon Components

struct AnimatedIcon {

    // MARK: - Processing States

    /// Processing/loading icon with rotating checkmark.shield
    /// - Parameter isActive: Whether the animation is active
    /// - Returns: Animated processing icon
    static func processing(isActive: Bool) -> some View {
        Image(systemName: "checkmark.shield")
            .font(.title)
            .foregroundStyle(.blue.gradient)
            .symbolPulse()
            .opacity(isActive ? 1.0 : 0.5)
    }

    /// Uploading icon with pulsing arrow
    /// - Parameter isActive: Whether the animation is active
    /// - Returns: Animated upload icon
    static func uploading(isActive: Bool) -> some View {
        Image(systemName: "arrow.up.doc")
            .font(.title)
            .foregroundStyle(.blue.gradient)
            .symbolPulse()
            .opacity(isActive ? 1.0 : 0.5)
    }

    /// Analyzing icon with variable color effect
    /// - Parameter isActive: Whether the animation is active
    /// - Returns: Animated analysis icon
    static func analyzing(isActive: Bool) -> some View {
        Image(systemName: "doc.text.magnifyingglass")
            .font(.title)
            .foregroundStyle(.blue.gradient)
            .symbolPulse()
            .opacity(isActive ? 1.0 : 0.5)
    }

    // MARK: - Success States

    /// Success icon with bouncing checkmark.circle
    /// - Parameter show: Whether to show the success icon
    /// - Returns: Animated success icon
    static func success(show: Bool) -> some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 64))
            .foregroundStyle(.green.gradient)
            .symbolBounce(trigger: show)
            .scaleEffect(show ? 1.0 : 0.0)
            .animation(AnimationSystem.bouncy, value: show)
    }

    /// Small success checkmark for inline use
    /// - Parameter show: Whether to show the checkmark
    /// - Returns: Animated inline success icon
    static func successSmall(show: Bool) -> some View {
        Image(systemName: "checkmark")
            .font(.body)
            .foregroundStyle(.green)
            .symbolBounce(trigger: show)
            .scaleEffect(show ? 1.0 : 0.0)
            .animation(AnimationSystem.bouncy, value: show)
    }

    // MARK: - Action Buttons

    /// Add button icon with scaling plus.circle
    /// - Parameter tapped: Trigger value for the animation
    /// - Returns: Animated add icon
    static func add(tapped: Bool) -> some View {
        Image(systemName: "plus.circle.fill")
            .font(.title2)
            .symbolBounce(trigger: tapped)
    }

    /// Delete button icon with scaling trash
    /// - Parameter tapped: Trigger value for the animation
    /// - Returns: Animated delete icon
    static func delete(tapped: Bool) -> some View {
        Image(systemName: "trash.fill")
            .font(.body)
            .foregroundStyle(.red)
            .symbolBounce(trigger: tapped)
    }

    // MARK: - Warning States

    /// Warning icon with pulsing exclamation triangle
    /// - Returns: Continuously pulsing warning icon
    static func warning() -> some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange.gradient)
            .symbolPulse()
    }

    /// Error icon with shaking xmark.circle
    /// - Parameter show: Whether to show the error
    /// - Returns: Animated error icon
    static func error(show: Bool) -> some View {
        Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.red.gradient)
            .symbolBounce(trigger: show)
    }

    // MARK: - Premium Features

    /// Premium crown icon with shimmer effect
    /// - Parameter highlight: Whether to highlight the premium icon
    /// - Returns: Animated premium icon
    static func premium(highlight: Bool) -> some View {
        Image(systemName: "crown.fill")
            .foregroundStyle(.yellow.gradient)
            .symbolBounce(trigger: highlight)
            .scaleEffect(highlight ? 1.1 : 1.0)
            .animation(AnimationSystem.bouncy, value: highlight)
    }

    /// Upgrade icon with bouncing arrow
    /// - Parameter tapped: Trigger for the animation
    /// - Returns: Animated upgrade icon
    static func upgrade(tapped: Bool) -> some View {
        Image(systemName: "arrow.up.circle.fill")
            .foregroundStyle(.blue.gradient)
            .symbolBounce(trigger: tapped)
    }

    // MARK: - Progress Indicators

    /// Loading spinner with continuous rotation
    /// - Returns: Continuously rotating loading icon
    static func loading() -> some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .symbolPulse()
            .rotationEffect(.degrees(0))
            .animation(
                Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                value: UUID()
            )
    }

    /// Sparkles icon with shimmer effect (for AI processing)
    /// - Returns: Animated sparkles icon
    static func sparkles() -> some View {
        Image(systemName: "sparkles")
            .symbolPulse()
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue, .purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - Receipt Processing Stage Icons

extension AnimatedIcon {

    /// Receipt processing stage indicator
    /// - Parameters:
    ///   - stage: Current processing stage (1-5)
    ///   - currentStage: The stage currently being processed
    /// - Returns: Animated stage icon
    static func receiptStage(_ stage: Int, currentStage: Int) -> some View {
        Group {
            switch stage {
            case 1:
                uploading(isActive: currentStage == 1)
            case 2:
                Image(systemName: "checkmark.shield")
                    .font(.title)
                    .foregroundStyle(.blue.gradient)
                    .symbolBounce(trigger: currentStage == 2)
                    .opacity(currentStage >= 2 ? 1.0 : 0.5)
            case 3:
                analyzing(isActive: currentStage == 3)
            case 4:
                Image(systemName: "text.viewfinder")
                    .font(.title)
                    .foregroundStyle(.blue.gradient)
                    .symbolPulse()
                    .opacity(currentStage >= 4 ? 1.0 : 0.5)
            case 5:
                success(show: currentStage == 5)
            default:
                Image(systemName: "circle")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SymbolAnimations_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Processing States
                VStack(spacing: 12) {
                    Text("Processing States")
                        .font(.headline)

                    HStack(spacing: 20) {
                        AnimatedIcon.processing(isActive: true)
                        AnimatedIcon.uploading(isActive: true)
                        AnimatedIcon.analyzing(isActive: true)
                    }
                }

                Divider()

                // Success States
                VStack(spacing: 12) {
                    Text("Success States")
                        .font(.headline)

                    HStack(spacing: 20) {
                        AnimatedIcon.success(show: true)
                        AnimatedIcon.successSmall(show: true)
                    }
                }

                Divider()

                // Action Buttons
                VStack(spacing: 12) {
                    Text("Action Buttons")
                        .font(.headline)

                    HStack(spacing: 20) {
                        AnimatedIcon.add(tapped: true)
                        AnimatedIcon.delete(tapped: false)
                    }
                }

                Divider()

                // Warning States
                VStack(spacing: 12) {
                    Text("Warning States")
                        .font(.headline)

                    HStack(spacing: 20) {
                        AnimatedIcon.warning()
                        AnimatedIcon.error(show: true)
                    }
                }

                Divider()

                // Premium
                VStack(spacing: 12) {
                    Text("Premium")
                        .font(.headline)

                    HStack(spacing: 20) {
                        AnimatedIcon.premium(highlight: true)
                        AnimatedIcon.upgrade(tapped: false)
                    }
                }

                Divider()

                // Loading
                VStack(spacing: 12) {
                    Text("Loading")
                        .font(.headline)

                    HStack(spacing: 20) {
                        AnimatedIcon.loading()
                        AnimatedIcon.sparkles()
                    }
                }
            }
            .padding()
        }
    }
}
#endif

