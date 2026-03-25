import PhotosUI
import SwiftUI

// MARK: - Manual Entry View Model

@MainActor
class ManualEntryViewModel: ObservableObject {
    // MARK: - Form State

    @Published var storeName = ""
    @Published var storeAddress = ""
    @Published var receiptName = ""
    @Published var totalAmount: Double = 0
    @Published var totalTax: Double = 0
    @Published var currency = "USD"
    @Published var paymentMethod = ""
    @Published var purchaseDate = Date()
    @Published var items: [ReceiptItem] = []
    @Published var logoSearchTerm = ""
    @Published var selectedTags: [String] = []

    // MARK: - Image State

    @Published var attachedImages: [UIImage] = []
    @Published var isLoadingImages = false

    // MARK: - Save State

    @Published var isSaving = false

    // MARK: - Validation

    var canSave: Bool {
        !storeName.trimmingCharacters(in: .whitespaces).isEmpty && totalAmount > 0
    }

    var itemsSubtotal: Double {
        items.reduce(0) { total, item in
            if item.isDiscount {
                return total - abs(item.price)
            }
            return total + item.price
        }
    }

    // MARK: - Image Loading

    func loadImages(from pickerItems: [PhotosPickerItem]) {
        isLoadingImages = true
        attachedImages = []

        Task {
            var loadedImages: [UIImage] = []

            for item in pickerItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedImages.append(image)
                }
            }

            attachedImages = loadedImages
            isLoadingImages = false
        }
    }

    // MARK: - Save Receipt

    func saveReceipt() async -> Receipt {
        isSaving = true

        var imageUrls: [String] = []
        if !attachedImages.isEmpty {
            imageUrls = await ImageStorageService.shared.uploadImages(attachedImages)
        }

        let receipt = Receipt(
            id: UUID(),
            user_id: SupabaseManager.shared.currentUser?.id ?? UUID(),
            image_urls: imageUrls,
            total_amount: totalAmount,
            items: items,
            store_name: storeName,
            store_address: storeAddress,
            receipt_name: receiptName.isEmpty ? storeName : receiptName,
            purchase_date: purchaseDate,
            currency: currency,
            payment_method: paymentMethod,
            total_tax: totalTax,
            logo_search_term: logoSearchTerm.isEmpty ? nil : logoSearchTerm,
            tags: selectedTags.isEmpty ? nil : selectedTags
        )

        return receipt
    }

    // MARK: - Helpers

    func formatPrice(_ price: Double) -> String {
        let formatter = AppFormatters.currency(code: currency)
        return formatter.string(from: NSNumber(value: price)) ?? "\(currency) \(String(format: "%.2f", price))"
    }

    func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "food", "groceries", "restaurant":
            return .brandSuccess
        case "transport", "transportation", "travel":
            return .brandInfo
        case "entertainment", "leisure":
            return .brandPurple
        case "shopping", "retail":
            return .brandWarning
        case "health", "medical", "pharmacy":
            return .brandError
        case "utilities", "bills":
            return .brandIndigo
        default:
            return Color.brandTextTertiary
        }
    }
}
