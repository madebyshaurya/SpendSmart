//
//  SampleReceipt.swift
//  SpendSmart
//
//  Sample receipt data for onboarding "Try Scanning" experience.
//

import SwiftUI

// MARK: - Sample Receipt Type

enum SampleReceiptType: String, CaseIterable, Identifiable {
    case grocery
    case restaurant
    case retail
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .grocery: return "Grocery"
        case .restaurant: return "Restaurant"
        case .retail: return "Retail"
        }
    }
    
    var emoji: String {
        switch self {
        case .grocery: return "🛒"
        case .restaurant: return "🍔"
        case .retail: return "👕"
        }
    }
    
    var imageName: String {
        switch self {
        case .grocery: return "sample_receipt_grocery"
        case .restaurant: return "sample_receipt_restaurant"
        case .retail: return "sample_receipt_retail"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .grocery: return Color.brandSuccess
        case .restaurant: return Color.brandWarning
        case .retail: return Color.brandVibrantBlue
        }
    }
    
    /// Pre-parsed receipt data for the sample
    /// This is what we'll show after the "AI processing" animation
    var sampleData: SampleReceiptData {
        switch self {
        case .grocery:
            return SampleReceiptData(
                storeName: "Trader Joe's",
                logoSearchTerm: "Trader Joe's",
                storeAddress: "123 Main Street, San Francisco, CA 94102",
                purchaseDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                currency: "USD",
                paymentMethod: "Apple Pay",
                items: [
                    SampleReceiptItem(name: "Organic Whole Milk", price: 5.99, category: "Dairy"),
                    SampleReceiptItem(name: "Sourdough Bread", price: 4.49, category: "Bakery"),
                    SampleReceiptItem(name: "Avocados (4 pack)", price: 6.99, category: "Produce"),
                    SampleReceiptItem(name: "Free Range Eggs", price: 7.49, category: "Dairy"),
                    SampleReceiptItem(name: "Organic Bananas", price: 2.29, category: "Produce"),
                    SampleReceiptItem(name: "Greek Yogurt", price: 4.99, category: "Dairy"),
                    SampleReceiptItem(name: "Member Discount", price: -3.50, category: "Discount", isDiscount: true)
                ],
                totalTax: 2.15,
                totalAmount: 30.89
            )
            
        case .restaurant:
            return SampleReceiptData(
                storeName: "Shake Shack",
                logoSearchTerm: "Shake Shack",
                storeAddress: "456 Market Street, San Francisco, CA 94105",
                purchaseDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                currency: "USD",
                paymentMethod: "Credit Card",
                items: [
                    SampleReceiptItem(name: "ShackBurger", price: 11.49, category: "Food"),
                    SampleReceiptItem(name: "Cheese Fries", price: 5.99, category: "Food"),
                    SampleReceiptItem(name: "Chocolate Shake", price: 6.49, category: "Beverages"),
                    SampleReceiptItem(name: "Lemonade", price: 3.99, category: "Beverages")
                ],
                totalTax: 2.52,
                totalAmount: 30.48
            )
            
        case .retail:
            return SampleReceiptData(
                storeName: "Target",
                logoSearchTerm: "Target",
                storeAddress: "789 Mission Street, San Francisco, CA 94103",
                purchaseDate: Date(),
                currency: "USD",
                paymentMethod: "Debit Card",
                items: [
                    SampleReceiptItem(name: "Cotton T-Shirt (Gray)", price: 14.99, category: "Clothing"),
                    SampleReceiptItem(name: "Phone Charger Cable", price: 19.99, category: "Electronics"),
                    SampleReceiptItem(name: "Hand Soap (2 pack)", price: 8.49, category: "Household"),
                    SampleReceiptItem(name: "Notebook Set", price: 12.99, category: "Office"),
                    SampleReceiptItem(name: "Circle Savings", price: -5.00, category: "Discount", isDiscount: true)
                ],
                totalTax: 4.58,
                totalAmount: 56.04
            )
        }
    }
}

// MARK: - Sample Receipt Data

struct SampleReceiptData {
    let storeName: String
    let logoSearchTerm: String
    let storeAddress: String
    let purchaseDate: Date
    let currency: String
    let paymentMethod: String
    let items: [SampleReceiptItem]
    let totalTax: Double
    let totalAmount: Double
    
    var formattedDate: String {
        purchaseDate.formatted(date: .long, time: .omitted)
    }
    
    var itemCount: Int {
        items.filter { !$0.isDiscount }.count
    }
    
    var savings: Double {
        items.filter { $0.isDiscount }.reduce(0) { $0 + abs($1.price) }
    }
}

// MARK: - Sample Receipt Item

struct SampleReceiptItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
    let category: String
    var isDiscount: Bool = false
    
    var emoji: String {
        // Category-based emoji mapping
        switch category.lowercased() {
        case "dairy": return "🥛"
        case "bakery": return "🍞"
        case "produce": return "🥑"
        case "food": return "🍔"
        case "beverages": return "🥤"
        case "clothing": return "👕"
        case "electronics": return "🔌"
        case "household": return "🧴"
        case "office": return "📓"
        case "discount": return "🏷️"
        default: return "📦"
        }
    }
}

// MARK: - Helper Extension

extension SampleReceiptData {
    /// Convert to a real Receipt object (for display purposes only, not saved)
    func toDisplayReceipt() -> Receipt {
        Receipt(
            id: UUID(),
            user_id: UUID(),
            image_urls: [],
            total_amount: totalAmount,
            items: items.map { item in
                ReceiptItem(
                    id: item.id,
                    name: item.name,
                    price: item.price,
                    category: item.category,
                    isDiscount: item.isDiscount
                )
            },
            store_name: storeName,
            store_address: storeAddress,
            receipt_name: "\(storeName) Receipt",
            purchase_date: purchaseDate,
            currency: currency,
            payment_method: paymentMethod,
            total_tax: totalTax,
            logo_search_term: logoSearchTerm
        )
    }
}
