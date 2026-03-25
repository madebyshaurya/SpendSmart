//
//  HapticManager.swift
//  SpendSmart
//
//  Created by Claude on 2026-01-19.
//
//  Centralized haptic feedback manager with user preference toggle.
//  Makes the app feel alive and responsive!
//

import SwiftUI
import UIKit
import CoreHaptics

@MainActor
class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    
    // MARK: - Feedback Generators (lazy initialized)
    
    private lazy var lightImpact = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var softImpact = UIImpactFeedbackGenerator(style: .soft)
    private lazy var rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var selectionFeedback = UISelectionFeedbackGenerator()
    private lazy var notificationFeedback = UINotificationFeedbackGenerator()
    private var engine: CHHapticEngine?
    private var lifecycleObservers: [NSObjectProtocol] = []

    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    
    private init() {
        // Prepare generators for faster response
        prepareGenerators()
        setupEngine()
    }
    
    private func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

    private func setupEngine() {
        guard supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            engine?.stoppedHandler = { reason in
                guard reason != .systemError else { return }
                Task { @MainActor [weak self] in
                    self?.startEngineIfNeeded()
                }
            }
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.startEngineIfNeeded(forceRestart: true)
                }
            }
            startEngineIfNeeded(forceRestart: true)
            registerLifecycleObserversIfNeeded()
        } catch {
            engine = nil
        }
    }

    private func startEngineIfNeeded(forceRestart: Bool = false) {
        guard supportsHaptics, let engine else { return }

        if forceRestart {
            try? engine.start()
            return
        }

        // Just start — CHHapticEngine handles redundant starts gracefully
        try? engine.start()
    }

    private func registerLifecycleObserversIfNeeded() {
        guard lifecycleObservers.isEmpty else { return }

        let center = NotificationCenter.default
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.engine?.stop(completionHandler: nil)
            }
        )

        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.startEngineIfNeeded()
            }
        )
    }

    private func playCorePattern(
        events: [CHHapticEvent],
        fallback: () -> Void
    ) {
        guard supportsHaptics, let engine else {
            fallback()
            return
        }

        startEngineIfNeeded()

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            fallback()
        }
    }
    
    // MARK: - Impact Haptics
    
    /// Light tap - for subtle interactions like selections, toggles
    func light() {
        guard hapticsEnabled else { return }
        lightImpact.impactOccurred()
    }
    
    /// Medium tap - for button presses, confirmations
    func medium() {
        guard hapticsEnabled else { return }
        mediumImpact.impactOccurred()
    }
    
    /// Heavy tap - for significant actions like completing a task
    func heavy() {
        guard hapticsEnabled else { return }
        heavyImpact.impactOccurred()
    }
    
    /// Soft tap - gentle feedback for delicate interactions
    func soft() {
        guard hapticsEnabled else { return }
        softImpact.impactOccurred()
    }
    
    /// Rigid tap - crisp, precise feedback
    func rigid() {
        guard hapticsEnabled else { return }
        rigidImpact.impactOccurred()
    }
    
    /// Variable intensity impact
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1.0) {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred(intensity: intensity)
    }
    
    // MARK: - Selection Haptics
    
    /// Selection changed - for pickers, tab changes, list item selection
    func selection() {
        guard hapticsEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Notification Haptics
    
    /// Success - task completed, receipt saved, sign in successful
    func success() {
        guard hapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Warning - approaching limit, validation issue
    func warning() {
        guard hapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Error - action failed, network error
    func error() {
        guard hapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Semantic Haptics (named for common use cases)
    
    /// Tab bar item tapped
    func tabTapped() {
        guard hapticsEnabled else { return }
        impact(.light, intensity: 0.7)
    }
    
    /// Button pressed (primary action)
    func buttonPress() {
        guard hapticsEnabled else { return }
        mediumImpact.impactOccurred()
    }
    
    /// Camera shutter / scan initiated
    func cameraShutter() {
        guard hapticsEnabled else { return }
        rigidImpact.impactOccurred()
    }
    
    /// Receipt scan complete
    func scanComplete() {
        guard hapticsEnabled else { return }
        // Double tap pattern for completion
        Task {
            mediumImpact.impactOccurred()
            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run {
                self.success()
            }
        }
    }
    
    /// Receipt saved successfully
    func receiptSaved() {
        guard hapticsEnabled else { return }
        success()
    }
    
    /// Sign in successful - celebratory pattern
    func signInSuccess() {
        guard hapticsEnabled else { return }
        Task {
            mediumImpact.impactOccurred()
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run {
                self.heavyImpact.impactOccurred()
            }
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run {
                self.success()
            }
        }
    }
    
    /// Pull to refresh triggered
    func pullToRefresh() {
        guard hapticsEnabled else { return }
        mediumImpact.impactOccurred()
    }
    
    /// Delete/destructive action
    func destructive() {
        guard hapticsEnabled else { return }
        warning()
    }
    
    /// Toggle switched
    func toggle() {
        guard hapticsEnabled else { return }
        impact(.light, intensity: 0.6)
    }
    
    /// Picker value changed
    func pickerChanged() {
        guard hapticsEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    /// Sheet/modal presented
    func sheetPresented() {
        guard hapticsEnabled else { return }
        impact(.soft, intensity: 0.5)
    }
    
    /// Sheet/modal dismissed
    func sheetDismissed() {
        guard hapticsEnabled else { return }
        impact(.soft, intensity: 0.3)
    }
    
    /// Long press recognized
    func longPress() {
        guard hapticsEnabled else { return }
        heavyImpact.impactOccurred()
    }
    
    /// Scroll snap / pagination
    func scrollSnap() {
        guard hapticsEnabled else { return }
        impact(.light, intensity: 0.5)
    }
    
    /// Upgrade/purchase action - celebratory!
    func purchase() {
        guard hapticsEnabled else { return }
        Task {
            heavyImpact.impactOccurred()
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                self.success()
            }
        }
    }
    
    // MARK: - Advanced Patterns
    
    /// Heartbeat pattern for important moments
    func heartbeat() {
        guard hapticsEnabled else { return }
        Task {
            softImpact.impactOccurred(intensity: 0.8)
            try? await Task.sleep(for: .milliseconds(120))
            await MainActor.run {
                self.mediumImpact.impactOccurred(intensity: 1.0)
            }
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run {
                self.softImpact.impactOccurred(intensity: 0.6)
            }
            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run {
                self.mediumImpact.impactOccurred(intensity: 0.8)
            }
        }
    }
    
    /// Countdown pattern (3, 2, 1)
    func countdown() {
        guard hapticsEnabled else { return }
        Task {
            lightImpact.impactOccurred()
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                self.mediumImpact.impactOccurred()
            }
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                self.heavyImpact.impactOccurred()
            }
        }
    }
    
    /// Ratchet effect for scrolling through values
    func ratchet(intensity: CGFloat = 0.5) {
        guard hapticsEnabled else { return }
        impact(.light, intensity: intensity)
    }
    
    /// Milestone celebration
    func milestone() {
        guard hapticsEnabled else { return }
        Task {
            for i in 0..<3 {
                let intensity = 0.4 + (Double(i) * 0.2)
                await MainActor.run {
                    self.impact(.medium, intensity: intensity)
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            await MainActor.run {
                self.success()
            }
        }
    }
    
    /// Swipe action feedback
    func swipeAction() {
        guard hapticsEnabled else { return }
        impact(.rigid, intensity: 0.8)
    }
    
    /// Drag threshold reached
    func dragThreshold() {
        guard hapticsEnabled else { return }
        impact(.medium, intensity: 0.7)
    }

    // MARK: - Core Haptics Patterns

    /// Multi-stage fireworks burst with a final satisfying thud
    func celebration() {
        guard hapticsEnabled else { return }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.65)
                ],
                relativeTime: 0.00
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.70)
                ],
                relativeTime: 0.07
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.75)
                ],
                relativeTime: 0.14
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.68),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.80)
                ],
                relativeTime: 0.21
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.80),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85)
                ],
                relativeTime: 0.28
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.00),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.28)
                ],
                relativeTime: 0.42
            )
        ]

        playCorePattern(events: events) { [weak self] in
            self?.milestone()
        }
    }

    /// Coin-drop feel with rapid descending taps
    func chaChing() {
        guard hapticsEnabled else { return }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.92)
                ],
                relativeTime: 0.00
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.73),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.84)
                ],
                relativeTime: 0.05
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.61),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.76)
                ],
                relativeTime: 0.10
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.49),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.68)
                ],
                relativeTime: 0.15
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.40),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.60)
                ],
                relativeTime: 0.21
            )
        ]

        playCorePattern(events: events) { [weak self] in
            self?.receiptSaved()
        }
    }

    /// Quick triple-pulse error cue with sharp intensity
    func errorShake() {
        guard hapticsEnabled else { return }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0.00
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.98)
                ],
                relativeTime: 0.08
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.90),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.96)
                ],
                relativeTime: 0.16
            )
        ]

        playCorePattern(events: events) { [weak self] in
            self?.error()
        }
    }

    /// Crisp snap followed by a very short settling buzz
    func smoothSnap() {
        guard hapticsEnabled else { return }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.90),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95)
                ],
                relativeTime: 0.00
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.40)
                ],
                relativeTime: 0.015,
                duration: 0.07
            )
        ]

        playCorePattern(events: events) { [weak self] in
            self?.scrollSnap()
        }
    }

    /// Building light-to-heavy taps ending in a success punctuation
    func ascendingSuccess() {
        guard hapticsEnabled else { return }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.30),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
                ],
                relativeTime: 0.00
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.48),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.58)
                ],
                relativeTime: 0.09
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.66),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.70)
                ],
                relativeTime: 0.18
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.86),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.82)
                ],
                relativeTime: 0.27
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                ],
                relativeTime: 0.38
            )
        ]

        playCorePattern(events: events) { [weak self] in
            self?.success()
        }
    }

    /// Subtle pulsing continuous haptics for gentle attention cues
    func gentlePulse() {
        guard hapticsEnabled else { return }

        let events = [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.24),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
                ],
                relativeTime: 0.00,
                duration: 0.14
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.28),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.24)
                ],
                relativeTime: 0.22,
                duration: 0.14
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.32),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.28)
                ],
                relativeTime: 0.44,
                duration: 0.14
            )
        ]

        playCorePattern(events: events) { [weak self] in
            self?.soft()
        }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Adds haptic feedback when a value changes
    func hapticOnChange<V: Equatable>(of value: V, type: HapticType = .selection) -> some View {
        self.onChange(of: value) { _, _ in
            Task { @MainActor in
                switch type {
                case .light: HapticManager.shared.light()
                case .medium: HapticManager.shared.medium()
                case .heavy: HapticManager.shared.heavy()
                case .selection: HapticManager.shared.selection()
                case .success: HapticManager.shared.success()
                case .warning: HapticManager.shared.warning()
                case .error: HapticManager.shared.error()
                }
            }
        }
    }
}

enum HapticType {
    case light, medium, heavy, selection, success, warning, error
}
