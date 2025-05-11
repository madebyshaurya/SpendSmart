//
//  EditReceiptItemView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-17.
//

import SwiftUI

struct EditReceiptItemView: View {
    // Item to edit
    let originalItem: ReceiptItem
    
    // Callback for when editing is complete
    var onSave: (ReceiptItem) -> Void
    
    // Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Edited item data
    @State private var name: String
    @State private var price: String
    @State private var category: String
    @State private var isDiscount: Bool
    @State private var originalPrice: String
    @State private var discountDescription: String
    
    // UI States
    @State private var showCategoryPicker = false
    @State private var animateContent = false
    
    // Available categories
    private let categories = [
        "Dining", "Groceries", "Shopping", "Entertainment", "Transportation", 
        "Utilities", "Housing", "Health", "Education", "Travel", "Other"
    ]
    
    // Initialize with the item to edit
    init(item: ReceiptItem, onSave: @escaping (ReceiptItem) -> Void) {
        self.originalItem = item
        self.onSave = onSave
        
        // Initialize state variables with the item data
        _name = State(initialValue: item.name)
        _price = State(initialValue: String(format: "%.2f", item.price))
        _category = State(initialValue: item.category)
        _isDiscount = State(initialValue: item.isDiscount)
        _originalPrice = State(initialValue: item.originalPrice != nil ? String(format: "%.2f", item.originalPrice!) : "")
        _discountDescription = State(initialValue: item.discountDescription ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Main content
                ScrollView {
                    VStack(spacing: 20) {
                        // Basic item info
                        VStack(spacing: 15) {
                            AnimatedTextField(
                                title: "Item Name",
                                text: $name,
                                placeholder: "Enter item name",
                                systemImage: "tag"
                            )
                            
                            AnimatedTextField(
                                title: "Price",
                                text: $price,
                                placeholder: "0.00",
                                systemImage: "dollarsign.circle",
                                keyboardType: .decimalPad
                            )
                            
                            // Category picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        showCategoryPicker.toggle()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "folder")
                                            .foregroundColor(.secondary)
                                        
                                        Text(category)
                                            .font(.instrumentSans(size: 16))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .rotationEffect(Angle(degrees: showCategoryPicker ? 180 : 0))
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                    )
                                }
                                
                                if showCategoryPicker {
                                    ScrollView {
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                            ForEach(categories, id: \.self) { cat in
                                                Button(action: {
                                                    category = cat
                                                    withAnimation(.spring()) {
                                                        showCategoryPicker = false
                                                    }
                                                }) {
                                                    HStack {
                                                        Text(cat)
                                                            .font(.instrumentSans(size: 14))
                                                            .foregroundColor(.primary)
                                                        
                                                        if category == cat {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 12))
                                                                .foregroundColor(.blue)
                                                        }
                                                    }
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 12)
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(category == cat ? 
                                                                  Color.blue.opacity(0.1) : 
                                                                  colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray5))
                                                    )
                                                }
                                            }
                                        }
                                        .padding()
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                    )
                                    .frame(height: 200)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                        
                        // Discount section
                        VStack(spacing: 15) {
                            Toggle(isOn: $isDiscount.animation()) {
                                HStack {
                                    Image(systemName: "tag.slash")
                                        .foregroundColor(.red)
                                    
                                    Text("This is a discount or free item")
                                        .font(.instrumentSans(size: 16))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                            
                            if isDiscount {
                                AnimatedTextField(
                                    title: "Original Price (before discount)",
                                    text: $originalPrice,
                                    placeholder: "0.00",
                                    systemImage: "dollarsign.circle",
                                    keyboardType: .decimalPad
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                                
                                AnimatedTextField(
                                    title: "Discount Description",
                                    text: $discountDescription,
                                    placeholder: "e.g., Points Redeemed, BOGO",
                                    systemImage: "text.bubble"
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateContent)
                    }
                    .padding()
                }
            }
            .navigationTitle(originalItem.id == UUID() ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                // Animate content when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        animateContent = true
                    }
                }
            }
        }
    }
    
    // Save changes to the item
    private func saveChanges() {
        // Parse values
        let priceValue = Double(price) ?? 0.0
        let originalPriceValue = originalPrice.isEmpty ? nil : Double(originalPrice)
        
        // Create updated item
        let updatedItem = ReceiptItem(
            id: originalItem.id,
            name: name,
            price: priceValue,
            category: category,
            originalPrice: isDiscount ? originalPriceValue : nil,
            discountDescription: isDiscount && !discountDescription.isEmpty ? discountDescription : nil,
            isDiscount: isDiscount
        )
        
        // Call onSave callback
        onSave(updatedItem)
        dismiss()
    }
}

// Preview
struct EditReceiptItemView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItem = ReceiptItem(
            id: UUID(),
            name: "Coffee",
            price: 4.99,
            category: "Dining"
        )
        
        return EditReceiptItemView(item: sampleItem) { _ in }
    }
}
