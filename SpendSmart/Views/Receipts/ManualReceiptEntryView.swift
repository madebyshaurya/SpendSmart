//
//  ManualReceiptEntryView.swift
//  SpendSmart
//
//  Manual receipt entry form - a FREE feature for creating receipts without scanning.
//  Beautiful branded UI with smooth animations and optional image attachments.
//

import SwiftUI
import PhotosUI

struct ManualReceiptEntryView: View {
    // MARK: - Environment & State Objects

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ManualEntryViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var haptics = HapticManager.shared
    @EnvironmentObject private var appState: AppState

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var editingItem: ReceiptItem?
    @State private var showAddItem = false
    @State private var showSuccessAnimation = false
    @State private var appearAnimation = false

    // MARK: - Callbacks

    let onSave: (Receipt) -> Void
    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        heroSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)

                        storeInfoSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.05), value: appearAnimation)

                        datePaymentSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: appearAnimation)

                        itemsSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.15), value: appearAnimation)

                        totalsSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: appearAnimation)

                        photosSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.25), value: appearAnimation)

                        tagsSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.3), value: appearAnimation)

                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .scrollDismissesKeyboard(.interactively)

                VStack {
                    Spacer()
                    bottomButtons
                }

                if showSuccessAnimation {
                    successOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Receipt")
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
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.items.append(newItem)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedPhotos) { _, newValue in
                viewModel.loadImages(from: newValue)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    appearAnimation = true
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                MeshGradient.brandHero
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                Image(systemName: "pencil.line")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.brandVibrantBlue.opacity(0.3), radius: 16, x: 0, y: 8)

            VStack(spacing: 8) {
                Text("Enter Manually")
                    .font(.instrumentSerifItalic(size: 26))
                    .foregroundColor(.brandTextPrimary)

                Text("Create a receipt without scanning. Just fill in the details below.")
                    .font(.manrope(size: 14, weight: .regular))
                    .foregroundColor(.brandTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                Text("FREE Feature")
                    .font(.manrope(size: 12, weight: .semibold))
            }
            .foregroundColor(.brandSuccess)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.brandSuccess.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    // MARK: - Store Info Section

    private var storeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Store Information", required: true)

            VStack(spacing: 12) {
                EditableField(
                    label: "Store Name",
                    text: $viewModel.storeName,
                    icon: "storefront"
                )

                EditableField(
                    label: "Receipt Name (optional)",
                    text: $viewModel.receiptName,
                    icon: "doc.text"
                )

                EditableField(
                    label: "Address (optional)",
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

                EditableField(
                    label: "Payment Method (optional)",
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
                sectionHeader("Items (Optional)")
                Spacer()
                Button {
                    haptics.buttonPress()
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
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.brandTextTertiary)

            Text("No items added yet")
                .font(.manrope(size: 14, weight: .medium))
                .foregroundColor(.brandTextSecondary)

            Text("You can add itemized details or just enter the total amount below.")
                .font(.manrope(size: 12, weight: .regular))
                .foregroundColor(.brandTextTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                haptics.buttonPress()
                showAddItem = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add First Item")
                }
                .font(.manrope(size: 14, weight: .semibold))
                .foregroundColor(.brandVibrantBlue)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(cardBackground)
    }

    private func itemRow(_ item: ReceiptItem) -> some View {
        HStack(spacing: 12) {
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

            if item.isDiscount {
                Text(viewModel.formatPrice(-abs(item.price)))
                    .font(.ibmPlexMono(size: 15))
                    .foregroundColor(.brandSuccess)
            } else {
                Text(viewModel.formatPrice(item.price))
                    .font(.ibmPlexMono(size: 15))
                    .foregroundColor(.brandTextPrimary)
            }

            Menu {
                Button {
                    editingItem = item
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    haptics.destructive()
                    withAnimation(.easeOut(duration: 0.2)) {
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
            sectionHeader("Totals", required: true)

            VStack(spacing: 12) {
                if !viewModel.items.isEmpty {
                    HStack {
                        Text("Items Subtotal")
                            .font(.manrope(size: 14, weight: .regular))
                            .foregroundColor(.brandTextSecondary)
                        Spacer()
                        Text(viewModel.formatPrice(viewModel.itemsSubtotal))
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.brandTextSecondary)
                    }

                    Divider()
                        .background(Color.brandBorder)
                }

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

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total")
                            .font(.manrope(size: 16, weight: .semibold))
                            .foregroundColor(.brandTextPrimary)
                        Text("Required")
                            .font(.manrope(size: 11, weight: .medium))
                            .foregroundColor(.brandVibrantBlue)
                    }
                    Spacer()

                    HStack(spacing: 4) {
                        Text(viewModel.currency)
                            .font(.manrope(size: 14, weight: .medium))
                            .foregroundColor(.brandTextSecondary)

                        TextField("0.00", value: $viewModel.totalAmount, format: .number.precision(.fractionLength(2)))
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.brandTextPrimary)
                            .fontWeight(.semibold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                if !viewModel.items.isEmpty {
                    Button {
                        haptics.buttonPress()
                        withAnimation(.easeOut(duration: 0.2)) {
                            viewModel.totalAmount = viewModel.itemsSubtotal + viewModel.totalTax
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                            Text("Calculate from items")
                        }
                        .font(.manrope(size: 13, weight: .medium))
                        .foregroundColor(.brandVibrantBlue)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(cardBackground)
        }
    }

    // MARK: - Photos Section

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Photos (Optional)")

            VStack(spacing: 12) {
                ReceiptImageStack(
                    images: $viewModel.attachedImages,
                    onDelete: { index in
                        if index < viewModel.attachedImages.count {
                            viewModel.attachedImages.remove(at: index)
                        }
                        if index < selectedPhotos.count {
                            selectedPhotos.remove(at: index)
                        }
                    },
                    addButton: {
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                Text("Add Photo")
                                    .font(.manrope(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color.brandVibrantBlue)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.brandIceBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                    .foregroundStyle(Color.brandVibrantBlue.opacity(0.4))
                            )
                        }
                    }
                )

                if viewModel.isLoadingImages {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .brandVibrantBlue))
                        .padding(.vertical, 8)
                }
            }
            .padding(16)
            .background(cardBackground)
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Tags (Optional)")

            TagInputView(selectedTags: $viewModel.selectedTags)
                .padding(16)
                .background(cardBackground)
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 12) {
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
                .opacity(viewModel.canSave ? 1 : 0.6)
            }
            .disabled(viewModel.isSaving || !viewModel.canSave)
            .shadow(color: Color.brandVibrantBlue.opacity(viewModel.canSave ? 0.3 : 0.1), radius: 12, x: 0, y: 6)

            if !viewModel.canSave {
                Text("Enter a store name and total amount to save")
                    .font(.manrope(size: 12, weight: .medium))
                    .foregroundColor(.brandTextTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.brandBackground
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: -4)
                .ignoresSafeArea()
        )
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.brandSuccess)

                Text("Receipt Saved!")
                    .font(.manrope(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.brandSurface)
            )
            .scaleEffect(showSuccessAnimation ? 1 : 0.5)
            .opacity(showSuccessAnimation ? 1 : 0)
        }
        .transition(.opacity)
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, required: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.manrope(size: 13, weight: .semibold))
                .foregroundColor(.brandTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            if required {
                Text("*")
                    .font(.manrope(size: 13, weight: .bold))
                    .foregroundColor(.brandVibrantBlue)
            }
        }
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
        guard viewModel.canSave else { return }

        Task {
            let receipt = await viewModel.saveReceipt()

            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSuccessAnimation = true
                }
                haptics.chaChing()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onSave(receipt)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ManualReceiptEntryView(
        onSave: { receipt in
            print("Saved: \(receipt.store_name)")
        },
        onCancel: { }
    )
    .environmentObject(AppState())
}
