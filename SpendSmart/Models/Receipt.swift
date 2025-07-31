//
//  Receipt.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//


import Foundation

struct Receipt: Identifiable, Codable, Equatable {
    var id: UUID
    var user_id: UUID
    var image_urls: [String] // Array of image URLs for multiple receipt images
    var total_amount: Double
    var items: [ReceiptItem]
    var store_name: String
    var store_address: String
    var receipt_name: String
    var purchase_date: Date
    var currency: String
    var payment_method: String
    var total_tax: Double
    var logo_search_term: String? // Optimized search term for finding the store's logo

    // Custom coding keys matching Supabase column names
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case image_urls
        case total_amount
        case items
        case store_name
        case store_address
        case receipt_name
        case purchase_date
        case currency
        case payment_method
        case total_tax
        case logo_search_term
    }

    // Computed property to get the main image URL (for backward compatibility with code)
    var image_url: String {
        return image_urls.first ?? "placeholder_url"
    }

    // Computed property to get the actual amount spent (what the customer actually paid)
    var actualAmountSpent: Double {
        // For receipts with discounts, the actual amount spent is the total shown at the bottom of the receipt
        // This is what the customer actually paid, which is the total_amount
        return total_amount
    }

    // Computed property to calculate the original price before discounts
    var originalPrice: Double {
        // Calculate the sum of all non-discount items and their original prices if available
        let regularItemsTotal = items.reduce(0) { total, item in
            if item.isDiscount {
                return total
            } else if let originalPrice = item.originalPrice, originalPrice > item.price {
                return total + originalPrice
            } else {
                return total + item.price
            }
        }

        // Original price is regular items total + tax
        // We don't add discounts here because that's part of the savings calculation
        return regularItemsTotal + total_tax
    }

    // Computed property to calculate savings
    var savings: Double {
        // Calculate the sum of all discount items (these are typically negative values)
        let discountItemsTotal = items.reduce(0) { total, item in
            if item.isDiscount {
                return total + abs(item.price) // Convert to positive for savings display
            } else if let originalPrice = item.originalPrice, originalPrice > item.price {
                return total + (originalPrice - item.price) // Add the difference as savings
            } else {
                return total
            }
        }

        // Return the total discounts (should be positive)
        return discountItemsTotal
    }

    init(id: UUID, user_id: UUID, image_urls: [String] = [], total_amount: Double, items: [ReceiptItem], store_name: String, store_address: String, receipt_name: String, purchase_date: Date, currency: String, payment_method: String, total_tax: Double, logo_search_term: String? = nil) {
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
    }

    // Convenience initializer that accepts a single image_url for backward compatibility with code
    init(id: UUID, user_id: UUID, image_url: String, total_amount: Double, items: [ReceiptItem], store_name: String, store_address: String, receipt_name: String, purchase_date: Date, currency: String, payment_method: String, total_tax: Double, logo_search_term: String? = nil) {
        let urls = image_url != "placeholder_url" ? [image_url] : []
        self.init(id: id, user_id: user_id, image_urls: urls, total_amount: total_amount, items: items, store_name: store_name, store_address: store_address, receipt_name: receipt_name, purchase_date: purchase_date, currency: currency, payment_method: payment_method, total_tax: total_tax, logo_search_term: logo_search_term)
    }

    // MARK: - Decodable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        self.id = try container.decode(UUID.self, forKey: .id)
        self.user_id = try container.decode(UUID.self, forKey: .user_id)

        // image_urls can be an array, a single string, null, or missing
        if let urls = try? container.decode([String].self, forKey: .image_urls) {
            self.image_urls = urls
        } else if let single = try? container.decode(String.self, forKey: .image_urls) {
            self.image_urls = [single]
        } else {
            self.image_urls = []
        }

        // Numeric fields that might be null
        self.total_amount = try container.decodeIfPresent(Double.self, forKey: .total_amount) ?? 0.0
        self.total_tax    = try container.decodeIfPresent(Double.self, forKey: .total_tax)    ?? 0.0

        // Optional arrays
        self.items = try container.decodeIfPresent([ReceiptItem].self, forKey: .items) ?? []

        // Strings that might be null
        self.store_name    = try container.decodeIfPresent(String.self, forKey: .store_name)    ?? ""
        self.store_address = try container.decodeIfPresent(String.self, forKey: .store_address) ?? ""
        self.receipt_name  = try container.decodeIfPresent(String.self, forKey: .receipt_name)  ?? ""
        self.currency      = try container.decodeIfPresent(String.self, forKey: .currency)      ?? "USD"
        self.payment_method = try container.decodeIfPresent(String.self, forKey: .payment_method) ?? ""
        self.logo_search_term = try container.decodeIfPresent(String.self, forKey: .logo_search_term)

        // Parse purchase_date which Supabase returns as ISO8601 string
        if let dateString = try? container.decode(String.self, forKey: .purchase_date) {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                self.purchase_date = date
            } else if let timestamp = Double(dateString) {
                self.purchase_date = Date(timeIntervalSince1970: timestamp)
            } else {
                self.purchase_date = Date()
            }
        } else if let date = try? container.decode(Date.self, forKey: .purchase_date) {
            self.purchase_date = date
        } else {
            self.purchase_date = Date()
        }
    }

}

struct ReceiptItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var price: Double
    var category: String
    var originalPrice: Double? // Original price before discount
    var discountDescription: String? // Description of the discount (e.g., "Points Redeemed")
    var isDiscount: Bool // Whether this item represents a discount

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case price
        case category
        case originalPrice
        case discountDescription
        case isDiscount
    }

    init(id: UUID, name: String, price: Double, category: String, originalPrice: Double? = nil, discountDescription: String? = nil, isDiscount: Bool = false) {
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
        self.discountDescription = try container.decodeIfPresent(String.self, forKey: .discountDescription)
        self.isDiscount = try container.decodeIfPresent(Bool.self, forKey: .isDiscount) ?? false
    }
}

