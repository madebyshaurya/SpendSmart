import SwiftUI

struct AnimatedDropdown<Option: Hashable & CustomStringConvertible>: View {
    var title: String
    var icon: String? = nil
    var options: [Option]
    @Binding var selection: Option
    var tint: Color = .blue
    var collapsedHeight: CGFloat = 48
    var isRequired: Bool = false
    var validationMessage: String? = nil
    var isValid: Bool = true

    @State private var isOpen = false
    @State private var hasBeenInteracted = false
    @Namespace private var arrowNamespace
    @Environment(\.colorScheme) private var colorScheme
    
    private var showValidation: Bool {
        hasBeenInteracted && (!isValid || validationMessage != nil)
    }
    
    private var borderColor: Color {
        if showValidation && !isValid {
            return .red
        } else if hasBeenInteracted && isValid {
            return .green
        } else if isOpen {
            return tint
        } else {
            return Color.clear
        }
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
                
                // Validation icon
                if hasBeenInteracted {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isValid ? .green : .red)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isOpen.toggle()
                    hasBeenInteracted = true
                }
            }) {
                HStack(spacing: 10) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(isOpen ? tint : .secondary)
                            .font(.system(size: 16))
                    }
                    Text(selection.description)
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isOpen ? tint : .secondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isOpen)
                }
                .frame(height: collapsedHeight)
                .fieldContainerStyle(isFocused: isOpen, tint: tint, hasError: showValidation && !isValid)
                .accessibilityPickerField(
                    label: title, 
                    selectedValue: selection.description, 
                    optionsCount: options.count
                )
            }

            if isOpen {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selection = option
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                isOpen = false
                            }
                            hasBeenInteracted = true
                        }) {
                            HStack {
                                Text(option.description)
                                    .font(.instrumentSans(size: 15))
                                    .foregroundColor(.primary)
                                Spacer()
                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(tint)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selection == option ? tint.opacity(0.12) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .pressAnimation()
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
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
