//
//  ReceiptConfirmationView.swift
//  SpendSmart
//
//  Created by Claude on 2026-01-19.
//
//  Shows extracted receipt data for user review/edit before saving.
//  Beautiful branded UI with mesh gradients and Instrument Serif headlines.
//

import SwiftUI

struct ReceiptConfirmationView: View {
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var haptics = HapticManager.shared
    @StateObject private var viewModel: ReceiptConfirmationViewModel
    
    // UI State
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var editingItem: ReceiptItem?
    @State private var showAddItem = false
    @State private var showDatePicker = false
    
    // Original data from AI extraction
    let isFirstScan: Bool
    let onSave: (Receipt) -> Void
    let onCancel: () -> Void
    
    // MARK: - Initialization
    
    init(
        extractedData: ReceiptProcessingResponse,
        imageUrls: [String],
        scannedImages: [UIImage],
        isFirstScan: Bool = false,
        onSave: @escaping (Receipt) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: ReceiptConfirmationViewModel(
            extractedData: extractedData,
            imageUrls: imageUrls,
            scannedImages: scannedImages
        ))
        self.isFirstScan = isFirstScan
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.brandBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with receipt preview
                        headerSection
                        
                        // Store info section
                        storeInfoSection
                        
                        // Date & Payment section
                        datePaymentSection
                        
                        // Items section
                        itemsSection
                        
                        // Totals section
                        totalsSection
                        
                        // Bottom padding for buttons
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                
                // Fixed bottom buttons
                VStack {
                    Spacer()
                    bottomButtons
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Review Receipt")
                        .font(.manrope(size: 17, weight: .semibold))
                        .foregroundColor(.brandTextPrimary)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        haptics.buttonPress()
                        onCancel()
                        dismiss()
                    }
                    .font(.manrope(size: 16, weight: .medium))
                    .foregroundColor(.brandTextSecondary)
                }
            }
            .sheet(item: $editingItem) { item in
                EditItemSheet(item: item) { updatedItem in
                    haptics.success()
                    if let index = viewModel.items.firstIndex(where: { $0.id == item.id }) {
                        viewModel.items[index] = updatedItem
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddItemSheet { newItem in
                    haptics.success()
                    viewModel.items.append(newItem)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Receipt image preview (if available)
            if !viewModel.scannedImages.isEmpty {
                ReceiptImageStack(
                    images: .constant(viewModel.scannedImages),
                    onDelete: { _ in }, // Read-only in confirmation view
                    showsAddButton: false,
                    addButton: { EmptyView() } // No add button
                )
                .padding(.horizontal)
            }
            
            // Headline - special for first scan
            if isFirstScan {
                Text("Your First Receipt!")
                    .font(.instrumentSerifItalic(size: 28))
                    .foregroundColor(.brandVibrantBlue)
                
                Text("Looking great! Review the details below and save when ready.")
                    .font(.manrope(size: 14, weight: .regular))
                    .foregroundColor(.brandTextSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Confirm Details")
                    .font(.instrumentSerifItalic(size: 28))
                    .foregroundColor(.brandTextPrimary)
                
                Text("Review the extracted information and make any corrections before saving.")
                    .font(.manrope(size: 14, weight: .regular))
                    .foregroundColor(.brandTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Store Info Section
    
    private var storeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Store Information")
            
            VStack(spacing: 12) {
                EditableField(
                    label: "Store Name",
                    text: $viewModel.storeName,
                    icon: "storefront"
                )
                
                EditableField(
                    label: "Receipt Name",
                    text: $viewModel.receiptName,
                    icon: "doc.text"
                )
                
                EditableField(
                    label: "Address",
                    text: $viewModel.storeAddress,
                    icon: "location"
                )
            }
            .padding(16)
            .background(cardBackground)
        }
    }
    
    // MARK: - Date & Payment Section
    
    private var datePaymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Purchase Details")
            
            VStack(spacing: 12) {
                // Date picker
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.brandVibrantBlue)
                        .frame(width: 24)
                    
                    Text("Date")
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundColor(.brandTextSecondary)
                    
                    Spacer()
                    
                    DatePicker("", selection: $viewModel.purchaseDate, displayedComponents: [.date])
                        .labelsHidden()
                        .tint(.brandVibrantBlue)
                }
                .padding(.vertical, 4)
                
                Divider()
                    .background(Color.brandBorder)
                
                // Currency picker
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.brandVibrantBlue)
                        .frame(width: 24)
                    
                    Text("Currency")
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundColor(.brandTextSecondary)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "INR", "CHF"], id: \.self) { curr in
                            Button(curr) {
                                viewModel.currency = curr
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.currency)
                                .font(.manrope(size: 15, weight: .semibold))
                                .foregroundColor(.brandTextPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.brandTextSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
                    .background(Color.brandBorder)
                
                // Payment method
                EditableField(
                    label: "Payment",
                    text: $viewModel.paymentMethod,
                    icon: "creditcard"
                )
            }
            .padding(16)
            .background(cardBackground)
        }
    }
    
    // MARK: - Items Section
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Items (\(viewModel.items.count))")
                Spacer()
                Button {
                    showAddItem = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundColor(.brandVibrantBlue)
                }
            }
            
            if viewModel.items.isEmpty {
                emptyItemsView
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.items) { item in
                        itemRow(item)
                        
                        if item.id != viewModel.items.last?.id {
                            Divider()
                                .background(Color.brandBorder)
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(cardBackground)
            }
        }
    }
    
    private var emptyItemsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bag")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.brandTextTertiary)
            
            Text("No items extracted")
                .font(.manrope(size: 14, weight: .medium))
                .foregroundColor(.brandTextSecondary)
            
            Button {
                showAddItem = true
            } label: {
                Text("Add Item Manually")
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundColor(.brandVibrantBlue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(cardBackground)
    }
    
    private func itemRow(_ item: ReceiptItem) -> some View {
        HStack(spacing: 12) {
            // Category indicator
            Circle()
                .fill(viewModel.categoryColor(for: item.category))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.manrope(size: 15, weight: .medium))
                    .foregroundColor(.brandTextPrimary)
                    .lineLimit(1)
                
                Text(item.category)
                    .font(.manrope(size: 12, weight: .regular))
                    .foregroundColor(.brandTextTertiary)
            }
            
            Spacer()
            
            // Price
            VStack(alignment: .trailing, spacing: 2) {
                if item.isDiscount {
                    Text(viewModel.formatPrice(-abs(item.price)))
                        .font(.ibmPlexMono(size: 15))
                        .foregroundColor(.brandSuccess)
                } else {
                    Text(viewModel.formatPrice(item.price))
                        .font(.ibmPlexMono(size: 15))
                        .foregroundColor(.brandTextPrimary)
                }
                
                if let originalPrice = item.originalPrice, originalPrice > item.price {
                    Text(viewModel.formatPrice(originalPrice))
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.brandTextTertiary)
                        .strikethrough()
                }
            }
            
            // Edit/Delete buttons
            Menu {
                Button {
                    editingItem = item
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    haptics.destructive()
                    withAnimation {
                        viewModel.items.removeAll { $0.id == item.id }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.brandTextSecondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            editingItem = item
        }
    }
    
    // MARK: - Totals Section
    
    private var totalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Totals")
            
            VStack(spacing: 12) {
                // Subtotal (calculated from items)
                HStack {
                    Text("Subtotal")
                        .font(.manrope(size: 14, weight: .regular))
                        .foregroundColor(.brandTextSecondary)
                    Spacer()
                    Text(viewModel.formatPrice(viewModel.items.filter { !$0.isDiscount }.reduce(0) { $0 + $1.price }))
                        .font(.ibmPlexMono(size: 14))
                        .foregroundColor(.brandTextSecondary)
                }
                
                // Tax
                HStack {
                    Text("Tax")
                        .font(.manrope(size: 14, weight: .regular))
                        .foregroundColor(.brandTextSecondary)
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(viewModel.currency)
                            .font(.manrope(size: 12, weight: .medium))
                            .foregroundColor(.brandTextTertiary)
                        
                        TextField("0.00", value: $viewModel.totalTax, format: .number.precision(.fractionLength(2)))
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.brandTextPrimary)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Divider()
                    .background(Color.brandBorder)
                
                // Total
                HStack {
                    Text("Total")
                        .font(.manrope(size: 16, weight: .semibold))
                        .foregroundColor(.brandTextPrimary)
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(viewModel.currency)
                            .font(.manrope(size: 14, weight: .medium))
                            .foregroundColor(.brandTextSecondary)
                        
                        TextField("0.00", value: $viewModel.totalAmount, format: .number.precision(.fractionLength(2)))
                            .font(.ibmPlexMono(size: 18))
                            .foregroundColor(.brandTextPrimary)
                            .fontWeight(.semibold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }
            .padding(16)
            .background(cardBackground)
        }
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            // Save button with mesh gradient
            Button(action: saveReceipt) {
                ZStack {
                    MeshGradient.brandButton
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Save Receipt")
                                .font(.manrope(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                    }
                }
                .frame(height: 56)
            }
            .disabled(viewModel.isSaving)
            .shadow(color: Color.brandVibrantBlue.opacity(0.3), radius: 12, x: 0, y: 6)
            
            // Discard button
            Button {
                onCancel()
                dismiss()
            } label: {
                Text("Discard Receipt")
                    .font(.manrope(size: 15, weight: .medium))
                    .foregroundColor(.brandTextSecondary)
            }
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.brandBackground
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: -4)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.manrope(size: 13, weight: .semibold))
            .foregroundColor(.brandTextTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.brandSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )
    }
    
    // MARK: - Save Flow
    
    private func saveReceipt() {
        haptics.buttonPress()
        let receipt = viewModel.buildReceipt()
        onSave(receipt)
        dismiss()
    }
}

// MARK: - Editable Field Component

struct EditableField: View {
    let label: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.brandVibrantBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.manrope(size: 12, weight: .medium))
                    .foregroundColor(.brandTextTertiary)
                
                TextField(label, text: $text)
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundColor(.brandTextPrimary)
            }
        }
    }
}

// MARK: - Edit Item Sheet

struct EditItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let item: ReceiptItem
    let onSave: (ReceiptItem) -> Void
    
    @State private var name: String
    @State private var price: Double
    @State private var category: String
    @State private var isDiscount: Bool
    
    init(item: ReceiptItem, onSave: @escaping (ReceiptItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _name = State(initialValue: item.name)
        _price = State(initialValue: item.price)
        _category = State(initialValue: item.category)
        _isDiscount = State(initialValue: item.isDiscount)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Name", text: $name)
                    
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0.00", value: $price, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    Toggle("Is Discount", isOn: $isDiscount)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = ReceiptItem(
                            id: item.id,
                            name: name,
                            price: price,
                            category: category,
                            originalPrice: item.originalPrice,
                            discountDescription: item.discountDescription,
                            isDiscount: isDiscount
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var categories: [String] {
        ["Groceries", "Food", "Transport", "Entertainment", "Shopping", "Health", "Utilities", "Other"]
    }
}

// MARK: - Add Item Sheet

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let onAdd: (ReceiptItem) -> Void
    
    @State private var name: String = ""
    @State private var price: Double = 0
    @State private var category: String = "Other"
    @State private var isDiscount: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("New Item") {
                    TextField("Name", text: $name)
                    
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0.00", value: $price, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    Toggle("Is Discount", isOn: $isDiscount)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newItem = ReceiptItem(
                            id: UUID(),
                            name: name,
                            price: price,
                            category: category,
                            isDiscount: isDiscount
                        )
                        onAdd(newItem)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var categories: [String] {
        ["Groceries", "Food", "Transport", "Entertainment", "Shopping", "Health", "Utilities", "Other"]
    }
}

// MARK: - Preview

#Preview {
    let sampleResponse = ReceiptProcessingResponse(
        isValid: true,
        message: nil,
        store_name: "Trader Joe's",
        purchase_date: "2026-01-19",
        total_amount: 47.82,
        currency: "USD",
        items: [
            BackendReceiptProcessingItem(name: "Organic Bananas", price: 2.99, category: "Groceries", isDiscount: false, originalPrice: nil),
            BackendReceiptProcessingItem(name: "Almond Milk", price: 3.49, category: "Groceries", isDiscount: false, originalPrice: nil),
            BackendReceiptProcessingItem(name: "Sourdough Bread", price: 4.29, category: "Groceries", isDiscount: false, originalPrice: 5.49),
            BackendReceiptProcessingItem(name: "Member Discount", price: -2.50, category: "Discount", isDiscount: true, originalPrice: nil)
        ],
        total_tax: 3.82,
        payment_method: "Apple Pay",
        store_address: "123 Market Street, San Francisco, CA",
        receipt_name: "Weekly Groceries",
        logo_search_term: "trader joes logo"
    )
    
    ReceiptConfirmationView(
        extractedData: sampleResponse,
        imageUrls: [],
        scannedImages: [],
        onSave: { _ in },
        onCancel: { }
    )
}
