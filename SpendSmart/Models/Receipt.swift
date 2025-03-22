//
//  Receipt.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//


import Foundation

// In your Receipt.swift file, add a CodingKeys enum and implement init(from:) method

struct Receipt: Identifiable, Codable {
    var id: UUID
    var user_id: UUID
    var image_url: String
    var total_amount: Double
    var items: [ReceiptItem]
    var store_name: String
    var store_address: String
    var receipt_name: String
    var purchase_date: Date
    var currency: String
    var payment_method: String
}


struct ReceiptItem: Identifiable, Codable {
    var id: UUID
    var name: String
    var price: Double
    var category: String
}
