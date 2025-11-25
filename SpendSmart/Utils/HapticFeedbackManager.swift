//
//  HapticFeedbackManager.swift
//  SpendSmart
//
//  Enhanced haptic feedback system following Apple HIG patterns
//

import UIKit
import SwiftUI

class HapticFeedbackManager: ObservableObject {
    static let shared = HapticFeedbackManager()
    
    @Published var isHapticsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isHapticsEnabled, forKey: "isHapticsEnabled")
        }
    }
    
    // Pre-initialized generators for better performance
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {
        isHapticsEnabled = UserDefaults.standard.object(forKey: "isHapticsEnabled") as? Bool ?? true
        
        // Prepare generators for immediate use
        prepareGenerators()
    }
    
    private func prepareGenerators() {
        guard isHapticsEnabled else { return }
        
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    // MARK: - Core Haptic Functions
    
    /// Light impact for subtle interactions like button taps
    func lightImpact() {
        guard isHapticsEnabled else { return }
        impactLight.impactOccurred()
        impactLight.prepare() // Re-prepare for next use
    }
    
    /// Medium impact for standard interactions like switches and important buttons
    func mediumImpact() {
        guard isHapticsEnabled else { return }
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }
    
    /// Heavy impact for significant actions like deleting or major state changes
    func heavyImpact() {
        guard isHapticsEnabled else { return }
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }
    
    /// Selection feedback for picking items from lists or changing values
    func selection() {
        guard isHapticsEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
    
    /// Success feedback for completed actions
    func success() {
        guard isHapticsEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    /// Warning feedback for cautionary actions
    func warning() {
        guard isHapticsEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
    
    /// Error feedback for failed actions
    func error() {
        guard isHapticsEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
    
    // MARK: - Contextual Haptic Functions for SpendSmart
    
    /// Haptic feedback for adding a new expense
    func expenseAdded() {
        success()
    }
    
    /// Haptic feedback for expense editing
    func expenseEdited() {
        lightImpact()
    }
    
    /// Haptic feedback for deleting an expense
    func expenseDeleted() {
        heavyImpact()
    }
    
    /// Haptic feedback for taking a receipt photo
    func receiptCaptured() {
        mediumImpact()
    }
    
    /// Haptic feedback for AI processing completion
    func aiProcessingComplete() {
        success()
    }
    
    /// Haptic feedback for AI processing error
    func aiProcessingError() {
        error()
    }
    
    /// Haptic feedback for subscription actions
    func subscriptionAdded() {
        success()
    }
    
    /// Haptic feedback for subscription updated
    func subscriptionUpdated() {
        lightImpact()
    }
    
    /// Haptic feedback for subscription deleted
    func subscriptionDeleted() {
        heavyImpact()
    }
    
    /// Haptic feedback for navigation between tabs
    func tabChanged() {
        selection()
    }
    
    /// Haptic feedback for opening sheets/modals
    func sheetPresented() {
        lightImpact()
    }
    
    /// Haptic feedback for dismissing sheets/modals
    func sheetDismissed() {
        lightImpact()
    }
    
    /// Haptic feedback for filter/search actions
    func filterApplied() {
        selection()
    }
    
    /// Haptic feedback for data refresh
    func dataRefreshed() {
        mediumImpact()
    }
    
    /// Haptic feedback for data export
    func dataExported() {
        success()
    }
    
    /// Haptic feedback for form validation errors
    func validationError() {
        warning()
    }
    
    /// Haptic feedback for form submission
    func formSubmitted() {
        mediumImpact()
    }
    
    /// Haptic feedback for toggle switches
    func toggleChanged() {
        selection()
    }
    
    /// Haptic feedback for slider value changes
    func sliderValueChanged() {
        selection()
    }
    
    /// Haptic feedback for pull-to-refresh
    func pullToRefresh() {
        mediumImpact()
    }
    
    /// Haptic feedback for long press actions
    func longPress() {
        mediumImpact()
    }
    
    /// Haptic feedback for swipe actions
    func swipeAction() {
        lightImpact()
    }
    
    // MARK: - Compound Haptic Patterns
    
    /// Complex haptic pattern for major achievements or milestones
    func celebration() {
        guard isHapticsEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.success()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.lightImpact()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.lightImpact()
            }
        }
    }
    
    /// Haptic pattern for critical errors or warnings
    func criticalAlert() {
        guard isHapticsEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.error()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.heavyImpact()
            }
        }
    }
    
    // MARK: - SwiftUI Integration
    
    /// View modifier for adding haptic feedback to buttons
    func buttonFeedback() -> some View {
        EmptyView()
            .onTapGesture { [weak self] in
                self?.lightImpact()
            }
    }
}

// MARK: - SwiftUI View Extensions
extension View {
    /// Adds haptic feedback for button taps
    func hapticFeedback(_ type: HapticFeedbackType = .light) -> some View {
        self.onTapGesture {
            switch type {
            case .light:
                HapticFeedbackManager.shared.lightImpact()
            case .medium:
                HapticFeedbackManager.shared.mediumImpact()
            case .heavy:
                HapticFeedbackManager.shared.heavyImpact()
            case .selection:
                HapticFeedbackManager.shared.selection()
            case .success:
                HapticFeedbackManager.shared.success()
            case .warning:
                HapticFeedbackManager.shared.warning()
            case .error:
                HapticFeedbackManager.shared.error()
            }
        }
    }
    
    /// Adds contextual haptic feedback for specific SpendSmart actions
    func contextualHapticFeedback(_ context: SpendSmartHapticContext) -> some View {
        self.onTapGesture {
            switch context {
            case .expenseAdded:
                HapticFeedbackManager.shared.expenseAdded()
            case .receiptCaptured:
                HapticFeedbackManager.shared.receiptCaptured()
            case .subscriptionManaged:
                HapticFeedbackManager.shared.subscriptionUpdated()
            case .tabNavigation:
                HapticFeedbackManager.shared.tabChanged()
            case .dataAction:
                HapticFeedbackManager.shared.dataRefreshed()
            }
        }
    }
    
    /// Adds haptic feedback for form interactions
    func formHapticFeedback(
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onValidationError: @escaping () -> Void = {},
        onSuccess: @escaping () -> Void = {}
    ) -> some View {
        self
            // Note: This should observe an actual changing state variable like isFocused or text content
            // .onChange(of: someActualState) { oldValue, newValue in
            //     if newValue && !oldValue {
            //         HapticFeedbackManager.shared.selection()
            //         onEditingChanged(true)
            //     }
            // }
            .onReceive(NotificationCenter.default.publisher(for: .formValidationError)) { _ in
                HapticFeedbackManager.shared.validationError()
                onValidationError()
            }
            .onReceive(NotificationCenter.default.publisher(for: .formSubmissionSuccess)) { _ in
                HapticFeedbackManager.shared.formSubmitted()
                onSuccess()
            }
    }
}

// MARK: - Supporting Types
enum HapticFeedbackType {
    case light, medium, heavy, selection, success, warning, error
}

enum SpendSmartHapticContext {
    case expenseAdded, receiptCaptured, subscriptionManaged, tabNavigation, dataAction
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let formValidationError = Notification.Name("formValidationError")
    static let formSubmissionSuccess = Notification.Name("formSubmissionSuccess")
}

// MARK: - Environment Key for Haptic Manager
struct HapticFeedbackEnvironmentKey: EnvironmentKey {
    static let defaultValue = HapticFeedbackManager.shared
}

extension EnvironmentValues {
    var hapticFeedback: HapticFeedbackManager {
        get { self[HapticFeedbackEnvironmentKey.self] }
        set { self[HapticFeedbackEnvironmentKey.self] = newValue }
    }
}