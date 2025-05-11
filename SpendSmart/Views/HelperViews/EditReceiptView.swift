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
    @State private var storeName: String
    @State private var storeAddress: String
    @State private var receiptName: String
    @State private var purchaseDate: Date
    @State private var totalAmount: String
    @State private var totalTax: String
    @State private var currency: String
    @State private var paymentMethod: String
    @State private var items: [ReceiptItem]

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
    private let paymentMethods = ["Credit Card", "Debit Card", "Cash", "Apple Pay", "Google Pay", "PayPal", "Gift Card", "Store Credit", "Other"]

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
        NavigationView {
            ZStack {
                // Background
                Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()

                // Main content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with store info
                        storeInfoSection

                        // Receipt details
                        receiptDetailsSection

                        // Items section
                        itemsSection
                    }
                    .padding()
                }

                // Loading overlay
                if isLoading {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Saving changes...")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.white)
                            .padding(.top, 10)
                    }
                }
            }
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
                    .fontWeight(.bold)
                    .disabled(isLoading)
                }
            }
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
    }

    // MARK: - UI Components

    // Store information section
    private var storeInfoSection: some View {
        VStack(spacing: 15) {
            Text("Store Information")
                .font(.instrumentSerif(size: 20))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 5)

            AnimatedTextField(
                title: "Store Name",
                text: $storeName,
                placeholder: "Enter store name",
                systemImage: "storefront"
            )

            AnimatedTextField(
                title: "Store Address",
                text: $storeAddress,
                placeholder: "Enter store address",
                systemImage: "mappin.and.ellipse"
            )

            AnimatedTextField(
                title: "Receipt Name",
                text: $receiptName,
                placeholder: "Enter receipt name",
                systemImage: "doc.text"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
    }

    // Receipt details section
    private var receiptDetailsSection: some View {
        VStack(spacing: 15) {
            Text("Receipt Details")
                .font(.instrumentSerif(size: 20))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 5)

            // Date picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Purchase Date")
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)

                Button(action: {
                    withAnimation(.spring()) {
                        showDatePicker.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)

                        Text(purchaseDate, style: .date)
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .rotationEffect(Angle(degrees: showDatePicker ? 180 : 0))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    )
                }

                if showDatePicker {
                    DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // Amount and tax
            HStack(spacing: 15) {
                AnimatedTextField(
                    title: "Total Amount",
                    text: $totalAmount,
                    placeholder: "0.00",
                    systemImage: "dollarsign.circle",
                    keyboardType: .decimalPad
                )

                AnimatedTextField(
                    title: "Tax",
                    text: $totalTax,
                    placeholder: "0.00",
                    systemImage: "percent",
                    keyboardType: .decimalPad
                )
            }

            // Currency picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Currency")
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)

                Button(action: {
                    withAnimation(.spring()) {
                        showCurrencyPicker.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(.secondary)

                        Text(currency)
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .rotationEffect(Angle(degrees: showCurrencyPicker ? 180 : 0))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    )
                }

                if showCurrencyPicker {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(currencies, id: \.self) { curr in
                                Button(action: {
                                    currency = curr
                                    withAnimation(.spring()) {
                                        showCurrencyPicker = false
                                    }
                                }) {
                                    Text(curr)
                                        .font(.instrumentSans(size: 16))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(currency == curr ?
                                                      Color.blue.opacity(0.2) :
                                                      colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray5))
                                        )
                                        .foregroundColor(currency == curr ? .blue : .primary)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    )
                    .frame(height: 70)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // Payment method picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Payment Method")
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)

                Button(action: {
                    withAnimation(.spring()) {
                        showPaymentMethodPicker.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.secondary)

                        Text(paymentMethod)
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .rotationEffect(Angle(degrees: showPaymentMethodPicker ? 180 : 0))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    )
                }

                if showPaymentMethodPicker {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(paymentMethods, id: \.self) { method in
                                Button(action: {
                                    paymentMethod = method
                                    withAnimation(.spring()) {
                                        showPaymentMethodPicker = false
                                    }
                                }) {
                                    HStack {
                                        Text(method)
                                            .font(.instrumentSans(size: 16))
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if paymentMethod == method {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(paymentMethod == method ?
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
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateContent)
    }

    // Items section
    private var itemsSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Items")
                    .font(.instrumentSerif(size: 20))
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    // Create a new item and open editor
                    let newItem = ReceiptItem(
                        id: UUID(),
                        name: "",
                        price: 0.0,
                        category: "Other"
                    )
                    editingItem = newItem
                    showItemEditor = true
                }) {
                    Label("Add Item", systemImage: "plus.circle.fill")
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 5)

            if items.isEmpty {
                Text("No items added yet")
                    .font(.instrumentSans(size: 16))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ItemRow(item: item, index: index)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .offset(y: 20)),
                            removal: .opacity.combined(with: .scale(scale: 0.9))
                        ))
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1 + Double(index) * 0.05), value: animateContent)
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
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateContent)
    }

    // Item row view
    private func ItemRow(item: ReceiptItem, index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text(item.category)
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(item.price, specifier: "%.2f")")
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(item.isDiscount ? .green : .primary)

                if item.isDiscount, let originalPrice = item.originalPrice {
                    Text("Original: $\(originalPrice, specifier: "%.2f")")
                        .font(.instrumentSans(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                editingItem = item
                showItemEditor = true
            }) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle())

            Button(action: {
                withAnimation {
                    items.removeAll { $0.id == item.id }
                }
            }) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
        )
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
                    // Update in Supabase
                    try await supabase
                        .from("receipts")
                        .update(updatedReceipt)
                        .eq("id", value: updatedReceipt.id)
                        .execute()
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
                    alertMessage = "Error saving changes: \(error.localizedDescription)"
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
