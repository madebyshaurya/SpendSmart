//
//  TagInputView.swift
//  SpendSmart
//
//  Reusable tag input component for receipt categorization.
//  Features suggested tags, custom tag input, and beautiful brand styling.
//

import SwiftUI

struct TagInputView: View {
    @Binding var selectedTags: [String]
    
    // Suggested tags
    private let suggestedTags = [
        "Business", "Personal", "Travel", "Groceries", 
        "Entertainment", "Medical", "Office", "Gift"
    ]
    
    @State private var showCustomTagInput = false
    @State private var customTagText = ""
    @FocusState private var isCustomTagFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected tags + suggestions in a flowing layout
            FlowLayout(spacing: 8) {
                // Show suggested tags
                ForEach(suggestedTags, id: \.self) { tag in
                    TagChip(
                        text: tag,
                        isSelected: selectedTags.contains(tag),
                        onTap: { toggleTag(tag) }
                    )
                }
                
                // Show custom tags that aren't in suggestions
                ForEach(customTags, id: \.self) { tag in
                    TagChip(
                        text: tag,
                        isSelected: true,
                        isCustom: true,
                        onTap: { toggleTag(tag) },
                        onRemove: { removeCustomTag(tag) }
                    )
                }
                
                // Add custom tag button
                if !showCustomTagInput {
                    AddTagButton {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showCustomTagInput = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isCustomTagFocused = true
                        }
                    }
                }
            }
            
            // Custom tag input field
            if showCustomTagInput {
                HStack(spacing: 8) {
                    TextField("Custom tag...", text: $customTagText)
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundColor(.brandTextPrimary)
                        .focused($isCustomTagFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addCustomTag()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.brandSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.brandVibrantBlue, lineWidth: 1.5)
                        )
                    
                    Button {
                        addCustomTag()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.brandVibrantBlue)
                            .clipShape(Circle())
                    }
                    .disabled(customTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(customTagText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showCustomTagInput = false
                            customTagText = ""
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.brandTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.brandSurface)
                            .clipShape(Circle())
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var customTags: [String] {
        selectedTags.filter { !suggestedTags.contains($0) }
    }
    
    // MARK: - Actions
    
    private func toggleTag(_ tag: String) {
        HapticManager.shared.buttonPress()
        withAnimation(.easeOut(duration: 0.15)) {
            if selectedTags.contains(tag) {
                selectedTags.removeAll { $0 == tag }
            } else {
                selectedTags.append(tag)
            }
        }
    }
    
    private func addCustomTag() {
        let trimmed = customTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !selectedTags.contains(trimmed) else {
            customTagText = ""
            return
        }
        
        HapticManager.shared.success()
        withAnimation(.easeOut(duration: 0.2)) {
            selectedTags.append(trimmed)
            customTagText = ""
            showCustomTagInput = false
        }
    }
    
    private func removeCustomTag(_ tag: String) {
        HapticManager.shared.buttonPress()
        withAnimation(.easeOut(duration: 0.15)) {
            selectedTags.removeAll { $0 == tag }
        }
    }
}

// MARK: - Tag Chip Component

struct TagChip: View {
    let text: String
    let isSelected: Bool
    var isCustom: Bool = false
    let onTap: () -> Void
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.manrope(size: 13, weight: .semibold))
            
            if isCustom && isSelected {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
        .foregroundColor(isSelected ? .brandVibrantBlue : .brandTextSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.brandIceBlue : Color.brandSurface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.brandVibrantBlue.opacity(0.3) : Color.brandBorder, lineWidth: 1)
        )
        .contentShape(Capsule())
        .onTapGesture {
            onTap()
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Add Tag Button

struct AddTagButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add")
                    .font(.manrope(size: 13, weight: .semibold))
            }
            .foregroundColor(.brandVibrantBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.brandIceBlue.opacity(0.5))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(.brandVibrantBlue.opacity(0.4))
            )
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x - spacing)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var tags: [String] = ["Personal", "Groceries"]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("TAGS (OPTIONAL)")
                    .font(.manrope(size: 13, weight: .semibold))
                    .foregroundColor(.brandTextTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                TagInputView(selectedTags: $tags)
                
                Divider()
                
                Text("Selected: \(tags.joined(separator: ", "))")
                    .font(.manrope(size: 14, weight: .regular))
                    .foregroundColor(.brandTextSecondary)
            }
            .padding()
            .background(Color.brandBackground)
        }
    }
    
    return PreviewWrapper()
}
