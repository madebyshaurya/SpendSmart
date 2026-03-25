import SwiftUI

// MARK: - Receipt Confirmation View Model

@MainActor
class ReceiptConfirmationViewModel: ObservableObject {
    // MARK: - Receipt Data (Editable)

    @Published var storeName: String
    @Published var storeAddress: String
    @Published var receiptName: String
    @Published var totalAmount: Double
    @Published var totalTax: Double
    @Published var currency: String
    @Published var paymentMethod: String
    @Published var purchaseDate: Date
    @Published var items: [ReceiptItem]
    @Published var logoSearchTerm: String?

    // MARK: - Images

    @Published var imageUrls: [String]
    @Published var scannedImages: [UIImage]

    // MARK: - Save State

    @Published var isSaving = false

    // MARK: - Initialization

    init(
        extractedData: ReceiptProcessingResponse,
        imageUrls: [String],
        scannedImages: [UIImage]
    ) {
        self.imageUrls = imageUrls
        self.scannedImages = scannedImages

        // Initialize from extracted data
        self.storeName = extractedData.store_name ?? "Unknown Store"
        self.storeAddress = extractedData.store_address ?? ""
        self.receiptName = extractedData.receipt_name ?? extractedData.store_name ?? "Receipt"
        self.totalAmount = extractedData.total_amount ?? 0
        self.totalTax = extractedData.total_tax ?? 0
        self.currency = extractedData.currency ?? "USD"
        self.paymentMethod = extractedData.payment_method ?? "Unknown"
        self.purchaseDate = PurchaseDateParser.parse(extractedData.purchase_date) ?? Date()
        self.logoSearchTerm = extractedData.logo_search_term

        // Convert items
        self.items = extractedData.items?.map { item in
            ReceiptItem(
                id: UUID(),
                name: item.name,
                price: item.price,
                category: item.category,
                originalPrice: item.originalPrice,
                isDiscount: item.isDiscount
            )
        } ?? []
    }

    // MARK: - Computed Properties

    var itemsSubtotal: Double {
        items.reduce(0) { total, item in
            if item.isDiscount {
                return total - abs(item.price)
            }
            return total + item.price
        }
    }

    // MARK: - Build Receipt

    func buildReceipt() -> Receipt {
        isSaving = true
        return Receipt(
            id: UUID(),
            user_id: UUID(),
            image_urls: imageUrls,
            total_amount: totalAmount,
            items: items,
            store_name: storeName,
            store_address: storeAddress,
            receipt_name: receiptName,
            purchase_date: purchaseDate,
            currency: currency,
            payment_method: paymentMethod,
            total_tax: totalTax,
            logo_search_term: logoSearchTerm
        )
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
