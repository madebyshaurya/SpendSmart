import Foundation

struct Receipt: Identifiable, Codable, Equatable {
    var id: UUID
    var user_id: UUID
    var image_urls: [String]
    var total_amount: Double
    var items: [ReceiptItem]
    var store_name: String
    var store_address: String
    var receipt_name: String
    var purchase_date: Date
    var currency: String
    var payment_method: String
    var total_tax: Double
    var logo_search_term: String?
    var tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id, user_id, image_urls, total_amount, items, store_name, store_address, receipt_name,
            purchase_date, currency, payment_method, total_tax, logo_search_term, tags
    }

    var image_url: String {
        image_urls.first ?? "placeholder_url"
    }

    var actualAmountSpent: Double {
        total_amount
    }

    var originalPrice: Double {
        let regularItemsTotal = items.reduce(0) { total, item in
            if item.isDiscount { return total }
            return total + (item.originalPrice ?? item.price)
        }
        return regularItemsTotal + total_tax
    }

    var savings: Double {
        items.reduce(0) { total, item in
            if item.isDiscount {
                return total + abs(item.price)
            } else if let original = item.originalPrice, original > item.price {
                return total + (original - item.price)
            }
            return total
        }
    }

    init(
        id: UUID, user_id: UUID, image_urls: [String] = [], total_amount: Double,
        items: [ReceiptItem], store_name: String, store_address: String, receipt_name: String,
        purchase_date: Date, currency: String, payment_method: String, total_tax: Double,
        logo_search_term: String? = nil, tags: [String]? = nil
    ) {
        self.id = id
        self.user_id = user_id
        self.image_urls = image_urls
        self.total_amount = total_amount
        self.items = items
        self.store_name = store_name
        self.store_address = store_address
        self.receipt_name = receipt_name
        self.purchase_date = purchase_date
        self.currency = currency
        self.payment_method = payment_method
        self.total_tax = total_tax
        self.logo_search_term = logo_search_term
        self.tags = tags
    }

    init(
        id: UUID, user_id: UUID, image_url: String, total_amount: Double, items: [ReceiptItem],
        store_name: String, store_address: String, receipt_name: String, purchase_date: Date,
        currency: String, payment_method: String, total_tax: Double, logo_search_term: String? = nil,
        tags: [String]? = nil
    ) {
        let urls = image_url != "placeholder_url" ? [image_url] : []
        self.init(
            id: id, user_id: user_id, image_urls: urls, total_amount: total_amount, items: items,
            store_name: store_name, store_address: store_address, receipt_name: receipt_name,
            purchase_date: purchase_date, currency: currency, payment_method: payment_method,
            total_tax: total_tax, logo_search_term: logo_search_term, tags: tags)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.user_id = try container.decode(UUID.self, forKey: .user_id)

        if let urls = try? container.decode([String].self, forKey: .image_urls) {
            self.image_urls = urls
        } else if let single = try? container.decode(String.self, forKey: .image_urls) {
            self.image_urls = [single]
        } else {
            self.image_urls = []
        }

        self.total_amount = try container.decodeIfPresent(Double.self, forKey: .total_amount) ?? 0.0
        self.total_tax = try container.decodeIfPresent(Double.self, forKey: .total_tax) ?? 0.0
        self.items = try container.decodeIfPresent([ReceiptItem].self, forKey: .items) ?? []
        self.store_name = try container.decodeIfPresent(String.self, forKey: .store_name) ?? ""
        self.store_address =
            try container.decodeIfPresent(String.self, forKey: .store_address) ?? ""
        self.receipt_name = try container.decodeIfPresent(String.self, forKey: .receipt_name) ?? ""
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        self.payment_method =
            try container.decodeIfPresent(String.self, forKey: .payment_method) ?? ""
        self.logo_search_term = try container.decodeIfPresent(
            String.self, forKey: .logo_search_term)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)

        if let dateString = try? container.decode(String.self, forKey: .purchase_date) {
            if let date = PurchaseDateParser.parse(dateString) {
                self.purchase_date = date
            } else {
                self.purchase_date = Date(
                    timeIntervalSince1970: Double(dateString) ?? Date().timeIntervalSince1970)
            }
        } else {
            self.purchase_date =
                try container.decodeIfPresent(Date.self, forKey: .purchase_date) ?? Date()
        }
    }
}

// MARK: - Factory from Backend Response

extension Receipt {
    /// Create a Receipt from a backend processing response + uploaded image URLs.
    static func from(response: ReceiptProcessingResponse, imageUrls: [String]) -> Receipt {
        let items = (response.items ?? []).map { item in
            ReceiptItem(
                id: UUID(),
                name: item.name,
                price: item.price,
                category: item.category,
                originalPrice: item.originalPrice,
                isDiscount: item.isDiscount
            )
        }
        return Receipt(
            id: UUID(),
            user_id: UUID(),
            image_urls: imageUrls,
            total_amount: response.total_amount ?? 0,
            items: items,
            store_name: response.store_name ?? "Unknown Store",
            store_address: response.store_address ?? "",
            receipt_name: response.receipt_name ?? response.store_name ?? "Receipt",
            purchase_date: PurchaseDateParser.parse(response.purchase_date) ?? Date(),
            currency: response.currency ?? "USD",
            payment_method: response.payment_method ?? "Unknown",
            total_tax: response.total_tax ?? 0,
            logo_search_term: response.logo_search_term
        )
    }
}

struct ReceiptItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var price: Double
    var category: String
    var originalPrice: Double?
    var discountDescription: String?
    var isDiscount: Bool

    init(
        id: UUID, name: String, price: Double, category: String, originalPrice: Double? = nil,
        discountDescription: String? = nil, isDiscount: Bool = false
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.category = category
        self.originalPrice = originalPrice
        self.discountDescription = discountDescription
        self.isDiscount = isDiscount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.price = try container.decodeIfPresent(Double.self, forKey: .price) ?? 0.0
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.originalPrice = try container.decodeIfPresent(Double.self, forKey: .originalPrice)
        self.discountDescription = try container.decodeIfPresent(
            String.self, forKey: .discountDescription)
        self.isDiscount = try container.decodeIfPresent(Bool.self, forKey: .isDiscount) ?? false
    }
}
