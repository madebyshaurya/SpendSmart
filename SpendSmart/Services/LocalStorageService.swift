//
//  LocalStorageService.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-15.
//

import Foundation
import SwiftUI

class LocalStorageService {
    static let shared = LocalStorageService()
    
    private let receiptsKey = "local_receipts"
    
    // Save receipts to UserDefaults
    func saveReceipts(_ receipts: [Receipt]) {
        do {
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            let data = try encoder.encode(receipts)
            UserDefaults.standard.set(data, forKey: receiptsKey)
            print("✅ Receipts saved to local storage successfully!")
        } catch {
            print("❌ Error saving receipts to local storage: \(error.localizedDescription)")
        }
    }
    
    // Get all receipts from UserDefaults
    func getReceipts() -> [Receipt] {
        guard let data = UserDefaults.standard.data(forKey: receiptsKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = formatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date: \(dateString)"
                )
            }
            
            let receipts = try decoder.decode([Receipt].self, from: data)
            return receipts
        } catch {
            print("❌ Error retrieving receipts from local storage: \(error.localizedDescription)")
            return []
        }
    }
    
    // Add a new receipt
    func addReceipt(_ receipt: Receipt) {
        var receipts = getReceipts()
        receipts.append(receipt)
        saveReceipts(receipts)
    }
    
    // Delete a receipt
    func deleteReceipt(withId id: UUID) {
        var receipts = getReceipts()
        receipts.removeAll { $0.id == id }
        saveReceipts(receipts)
    }
    
    // Clear all receipts
    func clearAllReceipts() {
        UserDefaults.standard.removeObject(forKey: receiptsKey)
    }
}
