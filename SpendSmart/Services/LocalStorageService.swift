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
        print("💾 [LocalStorageService] Saving \(receipts.count) receipts to local storage")
        do {
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            let data = try encoder.encode(receipts)
            UserDefaults.standard.set(data, forKey: receiptsKey)
            print("✅ [LocalStorageService] Successfully saved \(receipts.count) receipts to local storage")
        } catch {
            print("❌ [LocalStorageService] Error saving receipts to local storage: \(error.localizedDescription)")
        }
    }
    
    // Get all receipts from UserDefaults
    func getReceipts() -> [Receipt] {
        print("🔄 [LocalStorageService] Loading receipts from local storage")
        guard let data = UserDefaults.standard.data(forKey: receiptsKey) else {
            print("📭 [LocalStorageService] No stored receipt data found")
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
            print("✅ [LocalStorageService] Successfully loaded \(receipts.count) receipts from local storage")
            return receipts
        } catch {
            print("❌ [LocalStorageService] Error retrieving receipts from local storage: \(error.localizedDescription)")
            return []
        }
    }
    
    // Add a new receipt
    func addReceipt(_ receipt: Receipt) {
        #if DEBUG
        print("➕ [LocalStorageService] Adding new receipt: [STORE_NAME] - $[AMOUNT]")
        #endif
        var receipts = getReceipts()
        receipts.append(receipt)
        saveReceipts(receipts)
    }
    
    // Delete a receipt
    func deleteReceipt(withId id: UUID) {
        #if DEBUG
        print("🗑️ [LocalStorageService] Deleting receipt with ID: [REDACTED]")
        #endif
        var receipts = getReceipts()
        let originalCount = receipts.count
        receipts.removeAll { $0.id == id }
        let deletedCount = originalCount - receipts.count
        print("✅ [LocalStorageService] Deleted \(deletedCount) receipt(s)")
        saveReceipts(receipts)
    }
    
    // Clear all receipts
    func clearAllReceipts() {
        UserDefaults.standard.removeObject(forKey: receiptsKey)
    }
}
