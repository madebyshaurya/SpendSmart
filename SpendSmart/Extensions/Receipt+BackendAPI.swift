//
//  Receipt+BackendAPI.swift
//  SpendSmart
//
//  Created by SpendSmart Team on 2025-07-29.
//

import Foundation

// MARK: - Receipt Backend API Extensions

extension Receipt {
    /// Convert Receipt to dictionary for backend API requests
    func toDictionary() throws -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        
        var receiptDict: [String: Any] = [
            "id": id.uuidString,
            "user_id": user_id.uuidString,
            "image_urls": image_urls,
            "total_amount": total_amount,
            "store_name": store_name,
            "store_address": store_address,
            "receipt_name": receipt_name,
            "purchase_date": dateFormatter.string(from: purchase_date),
            "currency": currency,
            "payment_method": payment_method,
            "total_tax": total_tax
        ]
        
        // Add optional logo search term
        if let logoSearchTerm = logo_search_term {
            receiptDict["logo_search_term"] = logoSearchTerm
        }
        
        // Convert items to dictionaries
        let itemsArray = try items.map { item in
            try item.toDictionary()
        }
        receiptDict["items"] = itemsArray
        
        return receiptDict
    }
    
    /// Create Receipt from backend API response dictionary
    static func fromDictionary(_ dict: [String: Any]) throws -> Receipt {
        print("🔍 [iOS] Parsing receipt dictionary with keys: \(dict.keys.sorted())")

        guard let idString = dict["id"] as? String else {
            print("❌ [iOS] Missing or invalid 'id' field")
            throw BackendAPIError.decodingFailed
        }
        guard let id = UUID(uuidString: idString) else {
            print("❌ [iOS] Invalid UUID format for 'id': \(idString)")
            throw BackendAPIError.decodingFailed
        }

        guard let userIdString = dict["user_id"] as? String else {
            print("❌ [iOS] Missing or invalid 'user_id' field")
            throw BackendAPIError.decodingFailed
        }
        guard let userId = UUID(uuidString: userIdString) else {
            print("❌ [iOS] Invalid UUID format for 'user_id': \(userIdString)")
            throw BackendAPIError.decodingFailed
        }

        guard let totalAmount = dict["total_amount"] as? Double else {
            print("❌ [iOS] Missing or invalid 'total_amount' field: \(dict["total_amount"] ?? "nil")")
            throw BackendAPIError.decodingFailed
        }

        guard let storeName = dict["store_name"] as? String else {
            print("❌ [iOS] Missing or invalid 'store_name' field")
            throw BackendAPIError.decodingFailed
        }

        guard let storeAddress = dict["store_address"] as? String else {
            print("❌ [iOS] Missing or invalid 'store_address' field")
            throw BackendAPIError.decodingFailed
        }

        guard let receiptName = dict["receipt_name"] as? String else {
            print("❌ [iOS] Missing or invalid 'receipt_name' field")
            throw BackendAPIError.decodingFailed
        }

        guard let purchaseDateString = dict["purchase_date"] as? String else {
            print("❌ [iOS] Missing or invalid 'purchase_date' field")
            throw BackendAPIError.decodingFailed
        }

        guard let currency = dict["currency"] as? String else {
            print("❌ [iOS] Missing or invalid 'currency' field")
            throw BackendAPIError.decodingFailed
        }

        guard let paymentMethod = dict["payment_method"] as? String else {
            print("❌ [iOS] Missing or invalid 'payment_method' field")
            throw BackendAPIError.decodingFailed
        }

        guard let totalTax = dict["total_tax"] as? Double else {
            print("❌ [iOS] Missing or invalid 'total_tax' field: \(dict["total_tax"] ?? "nil")")
            throw BackendAPIError.decodingFailed
        }

        print("✅ [iOS] All required fields validated successfully")
        
        // Parse date
        print("🗓️ [iOS] Parsing purchase_date: \(purchaseDateString)")
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var purchaseDate: Date
        if let date = dateFormatter.date(from: purchaseDateString) {
            purchaseDate = date
            print("✅ [iOS] Successfully parsed purchase_date with ISO8601: \(purchaseDate)")
        } else {
            print("❌ [iOS] Failed to parse purchase_date with ISO8601: \(purchaseDateString)")
            // Fallback to manual parsing
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")

            guard let fallbackDate = fallbackFormatter.date(from: purchaseDateString) else {
                print("❌ [iOS] Failed to parse purchase_date with fallback: \(purchaseDateString)")
                throw BackendAPIError.decodingFailed
            }
            purchaseDate = fallbackDate
            print("✅ [iOS] Successfully parsed purchase_date with fallback: \(purchaseDate)")
        }

        // Parse image URLs (handle both array and single string for backward compatibility)
        var imageUrls: [String] = []
        if let urls = dict["image_urls"] as? [String] {
            imageUrls = urls
            print("✅ [iOS] Found image_urls array: \(urls)")
        } else if let singleUrl = dict["image_url"] as? String, singleUrl != "placeholder_url" {
            imageUrls = [singleUrl]
            print("✅ [iOS] Found single image_url: \(singleUrl)")
        } else {
            print("⚠️ [iOS] No valid image URLs found")
        }

        // Parse items
        var receiptItems: [ReceiptItem] = []
        if let itemsArray = dict["items"] as? [[String: Any]] {
            print("🛍️ [iOS] Parsing \(itemsArray.count) receipt items")
            do {
                receiptItems = try itemsArray.map { itemDict in
                    try ReceiptItem.fromDictionary(itemDict)
                }
                print("✅ [iOS] Successfully parsed all \(receiptItems.count) items")
            } catch {
                print("❌ [iOS] Failed to parse receipt items: \(error)")
                throw error
            }
        } else {
            print("⚠️ [iOS] No items array found or invalid format")
        }
        
        // Get optional logo search term
        let logoSearchTerm = dict["logo_search_term"] as? String
        print("🏷️ [iOS] Logo search term: \(logoSearchTerm ?? "none")")

        print("🎉 [iOS] Successfully creating Receipt object")
        let receipt = Receipt(
            id: id,
            user_id: userId,
            image_urls: imageUrls,
            total_amount: totalAmount,
            items: receiptItems,
            store_name: storeName,
            store_address: storeAddress,
            receipt_name: receiptName,
            purchase_date: purchaseDate,
            currency: currency,
            payment_method: paymentMethod,
            total_tax: totalTax,
            logo_search_term: logoSearchTerm
        )
        print("✅ [iOS] Receipt created successfully: \(receipt.receipt_name)")
        return receipt
    }
}

extension ReceiptItem {
    /// Convert ReceiptItem to dictionary for backend API requests
    func toDictionary() throws -> [String: Any] {
        var itemDict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "price": price,
            "category": category,
            "isDiscount": isDiscount
        ]
        
        // Add optional fields
        if let originalPrice = originalPrice {
            itemDict["originalPrice"] = originalPrice
        }
        
        if let discountDescription = discountDescription {
            itemDict["discountDescription"] = discountDescription
        }
        
        return itemDict
    }
    
    /// Create ReceiptItem from backend API response dictionary
    static func fromDictionary(_ dict: [String: Any]) throws -> ReceiptItem {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = dict["name"] as? String,
              let price = dict["price"] as? Double,
              let category = dict["category"] as? String else {
            throw BackendAPIError.decodingFailed
        }
        
        let originalPrice = dict["originalPrice"] as? Double
        let discountDescription = dict["discountDescription"] as? String
        let isDiscount = dict["isDiscount"] as? Bool ?? false
        
        return ReceiptItem(
            id: id,
            name: name,
            price: price,
            category: category,
            originalPrice: originalPrice,
            discountDescription: discountDescription,
            isDiscount: isDiscount
        )
    }
}
