import SwiftUI

struct SubscriptionAnimatedTextField: View {
    var title: String
    @Binding var text: String
    var placeholder: String
    var systemImage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var tint: Color = .blue
    var isRequired: Bool = false
    var validationMessage: String? = nil
    var isValid: Bool = true
    var maxLength: Int? = nil

    @State private var isFocused: Bool = false
    @State private var hasBeenInteracted: Bool = false
    @FocusState private var textFieldIsFocused: Bool
    
    private var showValidation: Bool {
        hasBeenInteracted && (!isValid || validationMessage != nil)
    }
    
    private var characterCount: Int {
        text.count
    }
    
    private var isOverLimit: Bool {
        if let maxLength = maxLength {
            return characterCount > maxLength
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.instrumentSans(size: 13))
                    .foregroundColor(.secondary)
                
                if isRequired {
                    Text("*")
                        .font(.instrumentSans(size: 13))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Character count indicator
                if let maxLength = maxLength, (isFocused || characterCount > 0) {
                    Text("\(characterCount)/\(maxLength)")
                        .font(.instrumentSans(size: 11))
                        .foregroundColor(isOverLimit ? .red : .secondary)
                        .transition(.opacity)
                }
                
                // Validation icon
                if hasBeenInteracted && !text.isEmpty {
                    Image(systemName: isValid && !isOverLimit ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isValid && !isOverLimit ? .green : .red)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            HStack(spacing: 10) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(isFocused ? tint : .secondary)
                        .font(.system(size: 16))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFocused)
                }

                TextField(placeholder, text: $text)
                    .font(.instrumentSans(size: 16))
                    .keyboardType(keyboardType)
                    .focused($textFieldIsFocused)
                    .onChange(of: textFieldIsFocused) { _, newValue in
                        isFocused = newValue
                        if !newValue && !text.isEmpty {
                            hasBeenInteracted = true
                        }
                    }
                    .onChange(of: text) { _, newValue in
                        if !newValue.isEmpty {
                            hasBeenInteracted = true
                        }
                        // Enforce character limit
                        if let maxLength = maxLength, newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
                
                // Clear button when focused and has text
                if isFocused && !text.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            text = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .fieldContainerStyle(isFocused: isFocused, tint: showValidation && !isValid ? .red : tint, hasError: showValidation && !isValid)
            .accessibilityEditableField(label: title, value: text, isEditing: isFocused)
            
            // Validation message
            if let validationMessage = validationMessage, showValidation {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    
                    Text(validationMessage)
                        .font(.instrumentSans(size: 12))
                        .foregroundColor(.red)
                }
                .accessibilityValidationMessage()
                .transition(.opacity.combined(with: .offset(y: -5)))
                .animation(DesignTokens.Animation.spring, value: showValidation)
            }
        }
    }
}


