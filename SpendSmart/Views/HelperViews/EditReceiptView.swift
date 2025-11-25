//
//  EditReceiptView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-17.
//

import SwiftUI
import Supabase

struct EditReceiptView: View {
    // Original receipt to edit
    let originalReceipt: Receipt

    // Callback for when editing is complete
    var onSave: (Receipt) -> Void

    // Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState

    // Edited receipt data
    @State private var storeName: String = ""
    @State private var storeAddress: String = ""
    @State private var receiptName: String = ""
    @State private var purchaseDate: Date = Date()
    @State private var totalAmount: String = ""
    @State private var totalTax: String = ""
    @State private var currency: String = "USD"
    @State private var paymentMethod: String = "Credit Card"
    @State private var items: [ReceiptItem] = []

    // UI States
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var animateContent = false
    @State private var showDatePicker = false
    @State private var showCurrencyPicker = false
    @State private var showPaymentMethodPicker = false
    @State private var editingItem: ReceiptItem?
    @State private var showItemEditor = false

    // Available currencies and payment methods
    private let currencies = ["USD", "CAD", "EUR", "GBP", "AUD", "INR", "JPY", "CNY"]
    private let paymentMethods = SubscriptionFormConstants.paymentMethods

    // Initialize with the receipt to edit
    init(receipt: Receipt, onSave: @escaping (Receipt) -> Void) {
        self.originalReceipt = receipt
        self.onSave = onSave

        // Initialize state variables with the receipt data
        _storeName = State(initialValue: receipt.store_name)
        _storeAddress = State(initialValue: receipt.store_address)
        _receiptName = State(initialValue: receipt.receipt_name)
        _purchaseDate = State(initialValue: receipt.purchase_date)
        _totalAmount = State(initialValue: String(format: "%.2f", receipt.total_amount))
        _totalTax = State(initialValue: String(format: "%.2f", receipt.total_tax))
        _currency = State(initialValue: receipt.currency)
        _paymentMethod = State(initialValue: receipt.payment_method)
        _items = State(initialValue: receipt.items)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                storeInfoSection
                receiptDetailsSection
                itemsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Edit Receipt")
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
                .disabled(isLoading)
            }
        }
        .overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Saving changes...")
                            .font(.instrumentSans(size: 16))
                            .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        )
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showItemEditor) {
            if let item = editingItem {
                EditReceiptItemView(item: item) { updatedItem in
                    if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
                        items[index] = updatedItem
                    }
                    editingItem = nil
                }
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

    // MARK: - UI Components

    // Store information section
    private var storeInfoSection: some View {
        ReceiptFormSection(title: "Store Information") {
            StyledTextField(
                title: "Store Name",
                text: $storeName,
                placeholder: "Enter store name",
                systemImage: "storefront"
            )

            StyledTextField(
                title: "Store Address",
                text: $storeAddress,
                placeholder: "Enter store address",
                systemImage: "mappin.and.ellipse"
            )

            StyledTextField(
                title: "Receipt Name",
                text: $receiptName,
                placeholder: "Enter receipt name",
                systemImage: "doc.text"
            )
        }
    }

    // Receipt details section
    private var receiptDetailsSection: some View {
        ReceiptFormSection(title: "Receipt Details") {
            StyledDatePicker(title: "Purchase Date", selection: $purchaseDate, systemImage: "calendar")
            
            StyledTextField(title: "Total Amount", text: $totalAmount, placeholder: "0.00", systemImage: "dollarsign.circle", keyboardType: .decimalPad)
            
            StyledTextField(title: "Tax", text: $totalTax, placeholder: "0.00", systemImage: "t.circle", keyboardType: .decimalPad)
            
            StyledPicker(title: "Currency", selection: $currency, options: currencies, systemImage: "coloncurrencysign.circle")
            
            StyledPicker(title: "Payment Method", selection: $paymentMethod, options: paymentMethods, systemImage: "creditcard.circle")
        }
    }

    // Items section
    private var itemsSection: some View {
        ReceiptFormSection(title: "Items") {
            ReceiptItemsList(
                items: $items,
                currency: currency,
                onItemTap: { item in
                    editingItem = item
                    showItemEditor = true
                },
                onItemDelete: { index in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        _ = items.remove(at: index)
                    }
                },
                onAddItem: {
                    let newItem = ReceiptItem(id: UUID(), name: "", price: 0.0, category: "Other")
                    withAnimation(.spring()) {
                        items.append(newItem)
                    }
                }
            )
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    // MARK: - Functions

    // Save changes to the receipt
    private func saveChanges() {
        // Validate input
        guard let totalAmountValue = Double(totalAmount) else {
            alertMessage = "Please enter a valid total amount"
            showAlert = true
            return
        }

        guard let totalTaxValue = Double(totalTax) else {
            alertMessage = "Please enter a valid tax amount"
            showAlert = true
            return
        }

        // Show loading indicator
        isLoading = true

        // Create updated receipt
        let updatedReceipt = Receipt(
            id: originalReceipt.id,
            user_id: originalReceipt.user_id,
            image_urls: originalReceipt.image_urls,
            total_amount: totalAmountValue,
            items: items,
            store_name: storeName,
            store_address: storeAddress,
            receipt_name: receiptName,
            purchase_date: purchaseDate,
            currency: currency,
            payment_method: paymentMethod,
            total_tax: totalTaxValue
        )

        // Update receipt in database
        Task {
            do {
                // Check if we're in guest mode (using local storage)
                if appState.useLocalStorage {
                    // Update in local storage
                    var receipts = LocalStorageService.shared.getReceipts()
                    if let index = receipts.firstIndex(where: { $0.id == updatedReceipt.id }) {
                        receipts[index] = updatedReceipt
                        LocalStorageService.shared.saveReceipts(receipts)
                    }
                } else {
                    // Update via backend API
                    _ = try await supabase.updateReceipt(updatedReceipt)
                }

                // Call onSave callback
                await MainActor.run {
                    isLoading = false
                    onSave(updatedReceipt)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ [EditReceiptView] Error updating receipt: \(error.localizedDescription)")
                    
                    // Provide more specific error messages
                    if error.localizedDescription.contains("row-level security policy") {
                        alertMessage = "Permission denied: You can only edit your own receipts. Please check your login status."
                    } else if error.localizedDescription.contains("network") {
                        alertMessage = "Network error: Please check your internet connection and try again."
                    } else {
                        alertMessage = "Error saving changes: \(error.localizedDescription)"
                    }
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Helper Views

// Animated text field with title and icon
struct AnimatedTextField: View {
    var title: String
    @Binding var text: String
    var placeholder: String
    var systemImage: String
    var keyboardType: UIKeyboardType = .default

    @State private var isFocused = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.instrumentSans(size: 14))
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(isFocused ? .blue : .secondary)
                    .animation(.spring(), value: isFocused)

                TextField(placeholder, text: $text)
                    .font(.instrumentSans(size: 16))
                    .keyboardType(keyboardType)
                    .onTapGesture {
                        isFocused = true
                    }
                    .onSubmit {
                        isFocused = false
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
            .animation(.spring(), value: isFocused)
        }
    }
}

// Preview
struct EditReceiptView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            ReceiptItem(id: UUID(), name: "Coffee", price: 4.99, category: "Dining"),
            ReceiptItem(id: UUID(), name: "Bagel", price: 3.49, category: "Dining"),
            ReceiptItem(id: UUID(), name: "Discount", price: -2.00, category: "Discount", isDiscount: true)
        ]

        let sampleReceipt = Receipt(
            id: UUID(),
            user_id: UUID(),
            image_urls: ["https://example.com/image.jpg"],
            total_amount: 6.48,
            items: sampleItems,
            store_name: "Coffee Shop",
            store_address: "123 Main St",
            receipt_name: "Morning Coffee",
            purchase_date: Date(),
            currency: "USD",
            payment_method: "Credit Card",
            total_tax: 0.58
        )

        return EditReceiptView(receipt: sampleReceipt) { _ in }
            .environmentObject(AppState())
    }
}

// MARK: - Custom View Modifiers
struct ItemsSectionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignTokens.Spacing.lg)
            .background(DesignTokens.Colors.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
