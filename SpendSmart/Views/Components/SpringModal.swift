import SwiftUI
import UIKit

struct SpringModal<Content: View>: View {
    @Binding var isPresented: Bool
    @State private var dragOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 0
    
    let content: Content
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black
                .opacity(backgroundOpacity * 0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Modal content
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 40, height: 6)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    // Content
                    content
                        .padding(.horizontal, 24)
                        .padding(.bottom, 34)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.regularMaterial)
                        .shadow(
                            color: .black.opacity(0.15),
                            radius: 30,
                            x: 0,
                            y: -10
                        )
                )
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow downward drag
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                                // Reduce background opacity as user drags down
                                backgroundOpacity = max(0, 1 - (Double(dragOffset) / 300))
                            }
                        }
                        .onEnded { value in
                            // Dismiss if dragged down enough or with sufficient velocity
                            if value.translation.height > 150 || value.predictedEndTranslation.height > 300 {
                                dismiss()
                            } else {
                                // Spring back to position
                                withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                    backgroundOpacity = 1
                                }
                            }
                        }
                )
            }
        }
        .animation(.interactiveSpring(response: 0.6, dampingFraction: 0.8), value: backgroundOpacity)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .onAppear {
            withAnimation(.interactiveSpring(response: 0.7, dampingFraction: 0.8)) {
                backgroundOpacity = 1
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            dismiss()
        }
    }
    
    private func dismiss() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            backgroundOpacity = 0
            dragOffset = 400
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
            dragOffset = 0
        }
    }
}

// Example modal content with Apple Intelligence styling
struct AddExpenseModal: View {
    @Binding var isPresented: Bool
    @State private var amount = ""
    @State private var category = "Dining"
    @State private var description = ""
    
    let categories = ["Dining", "Transport", "Shopping", "Entertainment", "Bills"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Expense")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Track your spending")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Form fields
            VStack(spacing: 20) {
                // Amount field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("$0.00", text: $amount)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                }
                
                // Category picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Description field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("What did you buy?", text: $description)
                        .font(.system(size: 17, weight: .medium))
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                )
                
                Button("Add Expense") {
                    // Add expense logic here
                    isPresented = false
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.5, blue: 1.0),
                                    Color(red: 0.4, green: 0.3, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .padding(.top, 8)
        }
    }
}

// Usage Example
struct ModalDemo: View {
    @State private var showModal = false
    
    var body: some View {
        ZStack {
            VStack {
                Button("Show Modal") {
                    showModal = true
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 200, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            
            if showModal {
                SpringModal(isPresented: $showModal) {
                    AddExpenseModal(isPresented: $showModal)
                }
            }
        }
    }
}