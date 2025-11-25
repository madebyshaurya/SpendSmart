import SwiftUI
import UIKit

// MARK: - Accessibility Extensions

extension View {
    /// Adds proper accessibility labels and hints for form fields
    func accessibilityFormField(label: String, hint: String? = nil, isRequired: Bool = false) -> some View {
        self
            .accessibilityLabel("\(label)\(isRequired ? ", required" : "")")
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Adds proper accessibility for editable text fields
    func accessibilityEditableField(label: String, value: String, isEditing: Bool = false) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint(isEditing ? "Double tap to finish editing" : "Double tap to edit")
            .accessibilityAddTraits(isEditing ? [.isSelected] : [])
    }
    
    /// Adds proper accessibility for picker/selection fields
    func accessibilityPickerField(label: String, selectedValue: String, optionsCount: Int) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue("Selected: \(selectedValue)")
            .accessibilityHint("Double tap to choose from \(optionsCount) options")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Adds proper accessibility for amount fields
    func accessibilityAmountField(label: String, amount: Double, currency: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue("\(amount) \(currency)")
            .accessibilityHint("Double tap to edit amount")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Adds semantic heading traits for section headers
    func accessibilitySectionHeader() -> some View {
        self
            .accessibilityAddTraits(.isHeader)
    }
    
    /// Adds proper accessibility for validation messages
    func accessibilityValidationMessage() -> some View {
        self
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel("Validation error")
    }
}

// MARK: - Keyboard Navigation Extensions

extension View {
    /// Enables keyboard navigation focus
    func keyboardNavigable() -> some View {
        self
            .focusable()
    }
    
    /// Adds keyboard shortcuts for common actions
    func commonKeyboardShortcuts(onSave: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SaveShortcut"))) { _ in
                onSave?()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CancelShortcut"))) { _ in
                onCancel?()
            }
    }
}

// MARK: - Haptic Feedback Extensions

extension View {
    /// Adds haptic feedback for form interactions
    func hapticFormFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    let impact = UIImpactFeedbackGenerator(style: style)
                    impact.impactOccurred()
                }
        )
    }
    
    /// Adds success haptic feedback
    func hapticSuccessFeedback() -> some View {
        self.modifier(SuccessHapticModifier())
    }
    
    /// Adds error haptic feedback  
    func hapticErrorFeedback() -> some View {
        self.modifier(ErrorHapticModifier())
    }
}

// MARK: - Haptic Modifiers

struct SuccessHapticModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            }
    }
}

struct ErrorHapticModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.error)
            }
    }
}

// MARK: - Press Animation Extension

extension View {
    /// Adds a press animation effect to buttons and interactive elements
    func pressAnimation(scale: CGFloat = 0.95, opacity: Double = 0.8) -> some View {
        self.modifier(PressAnimationModifier(scale: scale, opacity: opacity))
    }
}

struct PressAnimationModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .opacity(isPressed ? opacity : 1.0)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
                // Action on release
            } onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
    }
}