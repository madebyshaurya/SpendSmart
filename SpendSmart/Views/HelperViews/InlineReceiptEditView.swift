//
//  InlineReceiptEditView.swift
//  SpendSmart
//
//  Created by AI Assistant on 2025-01-25.
//

import SwiftUI
import Foundation

struct InlineReceiptEditView: View {
    // Original receipt to edit
    @Binding var receipt: Receipt
    
    // Callback for when receipt is updated
    var onUpdate: ((Receipt) -> Void)?
    
    // Environment
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState
    
    // Edit states for each field
    @State private var isEditingStoreName = false
    @State private var isEditingReceiptName = false
    @State private var isEditingStoreAddress = false
    @State private var isEditingTotalAmount = false
    @State private var isEditingTotalTax = false
    @State private var isEditingDate = false
    @State private var isEditingCurrency = false
    
    // Temporary edit values
    @State private var tempStoreName = ""
    @State private var tempReceiptName = ""
    @State private var tempStoreAddress = ""
    @State private var tempTotalAmount = ""
    @State private var tempTotalTax = ""
    @State private var tempDate = Date()
    @State private var tempCurrency = ""
    @State private var tempPaymentMethod = ""
    
    // UI states
    @State private var animateChanges = false
    @State private var logoImage: UIImage? = nil
    @State private var logoColors: [Color] = [.gray]
    @State private var isLoadingLogo = false
    @State private var showDatePicker = false
    @State private var showCurrencyPicker = false
    @State private var isEditingPaymentMethod = false
    @State private var editingItem: ReceiptItem?
    @State private var showItemEditor = false
    @State private var showSuccessIndicator = false
    @State private var successMessage = ""
    
    // Available options
    private let currencies = ["USD", "CAD", "EUR", "GBP", "AUD", "INR", "JPY", "CNY"]
    private let paymentMethods = SubscriptionFormConstants.paymentMethods
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            storeHeaderSection
            receiptDetailsSection
            itemsSection
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(20)
        .shadow(radius: 5)
        .onAppear {
            loadLogo()
            initializeTempValues()
        }
        .onChange(of: tempStoreName) { oldValue, newValue in
            if isEditingStoreName {
                updateLogoForNewStoreName()
            }
        }
        .sheet(isPresented: $showItemEditor) {
            if let item = editingItem {
                EditReceiptItemView(item: item) { updatedItem in
                    updateItem(updatedItem)
                    editingItem = nil
                }
            }
        }
    }
    
    // MARK: - Store Header Section
    private var storeHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReceiptSectionHeader(title: "Store Information", systemImage: "storefront.fill")
            
            HStack(spacing: 16) {
                // Store Logo
                ZStack {
                    if isLoadingLogo {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(primaryLogoColor.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: primaryLogoColor))
                            )
                    } else if let logo = logoImage {
                        Image(uiImage: logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(primaryLogoColor.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: primaryLogoColor.opacity(0.2), radius: 8, x: 0, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(primaryLogoColor.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "storefront.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(primaryLogoColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(primaryLogoColor.opacity(0.3), lineWidth: 2)
                            )
                    }
                }
                .scaleEffect(animateChanges ? 1.1 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateChanges)
                
                // Store Details
                VStack(alignment: .leading, spacing: 8) {
                    EditableField(
                        value: receipt.store_name,
                        isEditing: $isEditingStoreName,
                        tempValue: $tempStoreName,
                        placeholder: "Store Name",
                        font: .instrumentSans(size: 22, weight: .bold),
                        fontWeight: .bold,
                        icon: "storefront.fill",
                        onSave: saveStoreName
                    )
                    
                    EditableField(
                        value: receipt.receipt_name,
                        isEditing: $isEditingReceiptName,
                        tempValue: $tempReceiptName,
                        placeholder: "Receipt Name",
                        font: .instrumentSans(size: 16, weight: .medium),
                        fontWeight: .medium,
                        icon: "doc.text.fill",
                        textColor: .secondary,
                        onSave: saveReceiptName
                    )
                    
                    EditableField(
                        value: receipt.store_address,
                        isEditing: $isEditingStoreAddress,
                        tempValue: $tempStoreAddress,
                        placeholder: "Store Address",
                        font: .instrumentSans(size: 14, weight: .medium),
                        fontWeight: .medium,
                        icon: "mappin.circle.fill",
                        textColor: .secondary,
                        onSave: saveStoreAddress
                    )
                }
            }
        }
    }
    
    // MARK: - Receipt Details Section
    private var receiptDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReceiptSectionHeader(title: "Receipt Details", systemImage: "doc.text.fill")
            
            VStack(spacing: 12) {
                // Purchase Date
                ModernDateField(
                    title: "Purchase Date",
                    date: $tempDate,
                    isEditing: $isEditingDate,
                    onSave: saveDate
                )
                
                // Total Amount
                ModernAmountField(
                    title: "Total Amount",
                    amount: receipt.total_amount,
                    currency: receipt.currency,
                    tempValue: $tempTotalAmount,
                    isEditing: $isEditingTotalAmount,
                    onSave: saveTotalAmount
                )
                
                // Tax Amount
                ModernAmountField(
                    title: "Tax",
                    amount: receipt.total_tax,
                    currency: receipt.currency,
                    tempValue: $tempTotalTax,
                    isEditing: $isEditingTotalTax,
                    onSave: saveTotalTax
                )
                
                // Currency Selector
                ModernSelectionField(
                    title: "Currency",
                    value: receipt.currency,
                    options: currencies,
                    systemIcon: "dollarsign.circle.fill",
                    tint: .green,
                    showPicker: $showCurrencyPicker
                ) { currency in
                    saveCurrency(currency)
                }
                
                // Payment Method Selector
                ModernSelectionField(
                    title: "Payment Method",
                    value: receipt.payment_method,
                    options: paymentMethods,
                    systemIcon: "creditcard.fill",
                    tint: .blue,
                    showPicker: $isEditingPaymentMethod
                ) { method in
                    savePaymentMethod(method)
                }
            }
        }
    }
    
    // MARK: - Items Section
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items").font(.headline)
            ForEach($receipt.items) { $item in
                HStack {
                    TextField("Item Name", text: $item.name)
                    Spacer()
                    TextField("Price", value: $item.price, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                }
            }
            .onDelete(perform: deleteItems)
            
            Button(action: { addNewItem() }) {
                Label("Add Item", systemImage: "plus")
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        receipt.items.remove(atOffsets: offsets)
    }
    
    // MARK: - Currency Picker View
    private var currencyPickerView: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(currencies, id: \.self) { currency in
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                saveCurrency(currency)
                                showCurrencyPicker = false
                            }
                        } label: {
                            Text(currency)
                                .font(.instrumentSans(size: 14))
                                .fontWeight(.medium)
                                .foregroundColor(receipt.currency == currency ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(receipt.currency == currency ? primaryLogoColor : Color.gray.opacity(0.2))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Button("Cancel") {
                withAnimation(.spring()) {
                    showCurrencyPicker = false
                }
            }
            .font(.instrumentSans(size: 14))
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: -10)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
    }
    

    
    // MARK: - Computed Properties
    private var primaryLogoColor: Color {
        logoColors.first ?? (colorScheme == .dark ? .white : .black)
    }
    
    private var secondaryLogoColor: Color {
        logoColors.count > 1 ? logoColors[1] : primaryLogoColor.opacity(0.7)
    }
    
    // MARK: - Helper Functions
    private func initializeTempValues() {
        tempStoreName = receipt.store_name
        tempReceiptName = receipt.receipt_name
        tempStoreAddress = receipt.store_address
        tempTotalAmount = String(format: "%.2f", receipt.total_amount)
        tempTotalTax = String(format: "%.2f", receipt.total_tax)
        tempDate = receipt.purchase_date
        tempCurrency = receipt.currency
        tempPaymentMethod = receipt.payment_method
    }
    
    private func loadLogo() {
        Task {
            let (image, colors) = await LogoService.shared.fetchLogoForReceipt(receipt)
            await MainActor.run {
                logoImage = image
                logoColors = colors
            }
        }
    }
    
    private func updateLogoForNewStoreName() {
        guard !tempStoreName.isEmpty else { return }
        
        isLoadingLogo = true
        animateChanges = true
        
        Task {
            // Create a temporary receipt with the new store name for logo fetching
            var tempReceipt = receipt
            tempReceipt.store_name = tempStoreName
            
            let (image, colors) = await LogoService.shared.fetchLogoForReceipt(tempReceipt)
            await MainActor.run {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    logoImage = image
                    logoColors = colors
                    isLoadingLogo = false
                    animateChanges = false
                }
            }
        }
    }
    
    // MARK: - Save Functions
    private func saveStoreName() {
        guard !tempStoreName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            receipt.store_name = tempStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
            isEditingStoreName = false
        }
        
        // Persist to database
        persistReceiptChanges()
        
        // Show success indicator
        showSuccessMessage("Store name updated")
    }
    
    private func saveReceiptName() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            receipt.receipt_name = tempReceiptName.trimmingCharacters(in: .whitespacesAndNewlines)
            isEditingReceiptName = false
        }
        
        persistReceiptChanges()
        showSuccessMessage("Receipt name updated")
    }
    
    private func saveStoreAddress() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            receipt.store_address = tempStoreAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            isEditingStoreAddress = false
        }
        
        persistReceiptChanges()
        showSuccessMessage("Store address updated")
    }
    
    private func saveDate() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            receipt.purchase_date = tempDate
            isEditingDate = false
        }
        
        persistReceiptChanges()
        showSuccessMessage("Purchase date updated")
    }
    
    private func saveTotalAmount() {
        guard let amount = Double(tempTotalAmount), amount >= 0 else { 
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
            return 
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            receipt.total_amount = amount
            isEditingTotalAmount = false
        }
        
        persistReceiptChanges()
        showSuccessMessage("Total amount updated")
    }
    
    private func saveTotalTax() {
        guard let tax = Double(tempTotalTax), tax >= 0 else { 
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
            return 
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            receipt.total_tax = tax
            isEditingTotalTax = false
        }
        
        persistReceiptChanges()
        showSuccessMessage("Tax amount updated")
    }
    
    private func saveCurrency(_ currency: String) {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            receipt.currency = currency
        }
        
        persistReceiptChanges()
        showSuccessMessage("Currency updated to \(currency)")
    }
    
    private func savePaymentMethod(_ method: String) {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            receipt.payment_method = method
        }
        
        persistReceiptChanges()
        showSuccessMessage("Payment method updated")
    }
    
    private func addNewItem() {
        let newItem = ReceiptItem(
            id: UUID(),
            name: "",
            price: 0.0,
            category: "Other"
        )
        editingItem = newItem
        showItemEditor = true
    }
    
    private func updateItem(_ updatedItem: ReceiptItem) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            if let index = receipt.items.firstIndex(where: { $0.id == updatedItem.id }) {
                receipt.items[index] = updatedItem
                showSuccessMessage("Item updated")
            } else {
                receipt.items.append(updatedItem)
                showSuccessMessage("Item added")
            }
        }
        
        persistReceiptChanges()
    }
    
    private func deleteItem(_ item: ReceiptItem) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            receipt.items.removeAll { $0.id == item.id }
        }
        
        persistReceiptChanges()
        showSuccessMessage("Item deleted")
    }
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showSuccessIndicator = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showSuccessIndicator = false
            }
        }
    }
    
    private func persistReceiptChanges() {
        // Call the onUpdate callback to trigger database persistence
        onUpdate?(receipt)
        
        // Also persist to database directly
        Task {
            do {
                // Check if we're in guest mode (using local storage)
                if appState.useLocalStorage {
                    // Update in local storage
                    var receipts = LocalStorageService.shared.getReceipts()
                    if let index = receipts.firstIndex(where: { $0.id == receipt.id }) {
                        receipts[index] = receipt
                        LocalStorageService.shared.saveReceipts(receipts)
                    }
                } else {
                    // Update via backend API
                    _ = try await SupabaseManager.shared.updateReceipt(receipt)
                }
            } catch {
                await MainActor.run {
                    // Show error feedback
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    showSuccessMessage("Error saving changes")
                }
            }
        }
    }
}

// MARK: - Modern UI Components


struct ModernDateField: View {
    let title: String
    @Binding var date: Date
    @Binding var isEditing: Bool
    let onSave: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.instrumentSans(size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if isEditing {
                HStack {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    
                    Spacer()
                    
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    }
                    
                    Button {
                        withAnimation(.spring()) {
                            isEditing = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                Button {
                    withAnimation(.spring()) {
                        isEditing = true
                    }
                } label: {
                    HStack {
                        Text(date, style: .date)
                            .font(.instrumentSans(size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .opacity(0.7)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct ModernAmountField: View {
    let title: String
    let amount: Double
    let currency: String
    @Binding var tempValue: String
    @Binding var isEditing: Bool
    let onSave: () -> Void
    
    @StateObject private var currencyManager = CurrencyManager.shared
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.instrumentSans(size: 14))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if isEditing {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                    
                    TextField("0.00", text: $tempValue)
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .onSubmit {
                            onSave()
                        }
                    
                    Text(currency)
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.secondary)
                    
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    }
                    
                    Button {
                        withAnimation(.spring()) {
                            tempValue = String(format: "%.2f", amount)
                            isEditing = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
                .onAppear {
                    isFocused = true
                }
            } else {
                Button {
                    withAnimation(.spring()) {
                        tempValue = String(format: "%.2f", amount)
                        isEditing = true
                    }
                } label: {
                    HStack {
                        Text(currencyManager.formatAmount(amount, currencyCode: currency))
                            .font(.instrumentSans(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .opacity(0.7)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct ModernSelectionField: View {
    let title: String
    let value: String
    let options: [String]
    let systemIcon: String
    let tint: Color
    @Binding var showPicker: Bool
    let onSelection: (String) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.instrumentSans(size: 14))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Button {
                withAnimation(.spring()) {
                    showPicker.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: systemIcon)
                        .font(.system(size: 16))
                        .foregroundColor(tint)
                    
                    Text(value)
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showPicker ? 180 : 0))
                        .animation(.spring(), value: showPicker)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(showPicker ? tint.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(showPicker ? tint.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if showPicker {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                onSelection(option)
                                withAnimation(.spring()) {
                                    showPicker = false
                                }
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(.instrumentSans(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if option == value {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(tint)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(option == value ? tint.opacity(0.1) : Color.clear)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .frame(maxHeight: 200)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .transition(.opacity.combined(with: .offset(y: -10)))
            }
        }
    }
}

// MARK: - Editable Field Component
struct EditableField: View {
    let value: String
    @Binding var isEditing: Bool
    @Binding var tempValue: String
    let placeholder: String
    let font: Font
    let fontWeight: Font.Weight
    let icon: String
    var textColor: Color = .primary
    let onSave: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
            
            if isEditing {
                TextField(placeholder, text: $tempValue)
                    .font(font)
                    .fontWeight(fontWeight)
                    .focused($isFocused)
                    .onSubmit {
                        onSave()
                    }
                    .onAppear {
                        isFocused = true
                    }
                
                Button {
                    onSave()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                }
                
                Button {
                    withAnimation(.spring()) {
                        tempValue = value
                        isEditing = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
            } else {
                Button {
                    withAnimation(.spring()) {
                        tempValue = value
                        isEditing = true
                    }
                } label: {
                    Text(value.isEmpty ? placeholder : value)
                        .font(font)
                        .fontWeight(fontWeight)
                        .foregroundColor(value.isEmpty ? .secondary : textColor)
                    
                    Spacer()
                    
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .opacity(0.7)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
