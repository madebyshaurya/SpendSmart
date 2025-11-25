import SwiftUI

struct SwipeableListItem<Content: View>: View {
    @State private var offset = CGSize.zero
    @State private var opacity: Double = 1.0
    @State private var scale: Double = 1.0
    @State private var isDeleted = false
    
    let content: Content
    let onDelete: (() -> Void)?
    let onEdit: (() -> Void)?
    
    private let deleteThreshold: CGFloat = -120
    private let editThreshold: CGFloat = 80
    
    init(
        @ViewBuilder content: () -> Content,
        onDelete: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil
    ) {
        self.content = content()
        self.onDelete = onDelete
        self.onEdit = onEdit
    }
    
    var body: some View {
        if !isDeleted {
            ZStack {
                // Background actions
                HStack {
                    if onEdit != nil {
                        // Edit action (left side)
                        Button(action: { onEdit?() }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue, Color.cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                        }
                        .padding(.leading, 20)
                    }
                    
                    Spacer()
                    
                    if onDelete != nil {
                        // Delete action (right side)
                        Button(action: { deleteItem() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.red, Color.pink],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                        }
                        .padding(.trailing, 20)
                    }
                }
                
                // Main content
                content
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                            .shadow(
                                color: .black.opacity(0.08),
                                radius: offset == .zero ? 8 : 4,
                                x: 0,
                                y: offset == .zero ? 4 : 2
                            )
                    )
                    .offset(offset)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .animation(
                        .interactiveSpring(
                            response: 0.5,
                            dampingFraction: 0.8,
                            blendDuration: 0.25
                        ),
                        value: scale
                    )
                    .animation(
                        .easeInOut(duration: 0.3),
                        value: opacity
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = value.translation
                                
                                // Dynamic scaling based on swipe distance
                                let swipeDistance = abs(value.translation.width)
                                scale = max(0.95, 1.0 - (swipeDistance / 1000))
                                
                                // Provide haptic feedback at thresholds
                                if abs(value.translation.width) > 80 && scale > 0.98 {
                                    let selectionFeedback = UISelectionFeedbackGenerator()
                                    selectionFeedback.selectionChanged()
                                }
                            }
                            .onEnded { value in
                                let swipeDistance = value.translation.width
                                
                                // Determine action based on swipe distance and direction
                                if swipeDistance < deleteThreshold && onDelete != nil {
                                    deleteItem()
                                } else if swipeDistance > editThreshold && onEdit != nil {
                                    onEdit?()
                                    snapBack()
                                } else {
                                    snapBack()
                                }
                            }
                    )
            }
            .clipped()
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Delete") {
                if onDelete != nil { deleteItem() }
            }
            .accessibilityAction(named: "Edit") {
                if onEdit != nil { onEdit?() }
            }
        }
    }
    
    private func snapBack() {
        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
            offset = .zero
            scale = 1.0
            opacity = 1.0
        }
    }
    
    private func deleteItem() {
        // Success haptic
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        withAnimation(.easeInOut(duration: 0.4)) {
            opacity = 0
            scale = 0.8
            offset = CGSize(width: -UIScreen.main.bounds.width, height: 0)
        }
        
        // Delay actual deletion for animation completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isDeleted = true
            onDelete?()
        }
    }
}

// Example list item content
struct ExpenseItem: View {
    let title: String
    let amount: String
    let category: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with gradient background
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.7, blue: 0.9),
                                    Color(red: 0.5, green: 0.4, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(category)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(amount)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(20)
    }
}

// Usage Example
struct SwipeListDemo: View {
    @State private var expenses = [
        ("Coffee", "$4.50", "Dining", "cup.and.saucer.fill"),
        ("Uber", "$12.30", "Transport", "car.fill"),
        ("Groceries", "$67.80", "Shopping", "cart.fill")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(expenses.enumerated()), id: \.offset) { index, expense in
                        SwipeableListItem {
                            ExpenseItem(
                                title: expense.0,
                                amount: expense.1,
                                category: expense.2,
                                icon: expense.3
                            )
                        } onDelete: {
                            expenses.remove(at: index)
                        } onEdit: {
                            print("Edit \(expense.0)")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Expenses")
            .background(Color(.systemGroupedBackground))
        }
    }
}