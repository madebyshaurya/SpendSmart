import SwiftUI
import UIKit

struct StyledPicker<SelectionValue: Hashable & CustomStringConvertible>: View {
    var title: String
    @Binding var selection: SelectionValue
    var options: [SelectionValue]
    var systemImage: String

    @Environment(\.colorScheme) private var colorScheme
    
    // Computed property to ensure selection is always valid
    private var safeSelection: SelectionValue {
        if options.contains(selection) {
            return selection
        } else {
            // Return the first option if current selection is invalid
            return options.first ?? selection
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        // Ensure we update with a valid selection
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = option
                        }
                    }) {
                        HStack {
                            Text(option.description)
                            if option.description == safeSelection.description {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(safeSelection.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            // Initialize with a valid selection if current is invalid
            if !options.contains(selection), let firstOption = options.first {
                selection = firstOption
            }
        }
    }
}
