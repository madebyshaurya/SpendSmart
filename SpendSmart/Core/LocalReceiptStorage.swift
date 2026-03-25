//
//  LocalReceiptStorage.swift
//  SpendSmart
//
//  Created by Claude on 2026-01-19.
//
//  Stores receipts locally on device for free users.
//  Free users: receipts stored locally only
//  Plus users: receipts synced to cloud
//

import Foundation

/// Manages local storage of receipts for free users
class LocalReceiptStorage: ObservableObject {
    static let shared = LocalReceiptStorage()
    
    private let receiptsKey = "com.spendsmart.localReceipts"
    private let fileManager = FileManager.default
    
    @Published private(set) var localReceipts: [Receipt] = []
    
    private var receiptsFileURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("local_receipts.json")
    }
    
    private init() {
        loadReceipts()
    }
    
    // MARK: - Public Methods
    
    /// Save a receipt locally
    func saveReceipt(_ receipt: Receipt) {
        var receipts = localReceipts
        
        // Check if receipt already exists (update) or is new (insert)
        if let index = receipts.firstIndex(where: { $0.id == receipt.id }) {
            receipts[index] = receipt
        } else {
            receipts.insert(receipt, at: 0) // Add at beginning (most recent first)
        }
        
        localReceipts = receipts
        persistReceipts()
    }
    
    /// Delete a receipt from local storage
    func deleteReceipt(id: UUID) {
        localReceipts.removeAll { $0.id == id }
        persistReceipts()
    }
    
    /// Delete a receipt by string ID
    func deleteReceipt(id: String) {
        guard let uuid = UUID(uuidString: id) else { return }
        deleteReceipt(id: uuid)
    }
    
    /// Get all local receipts
    func getAllReceipts() -> [Receipt] {
        return localReceipts
    }
    
    /// Get a specific receipt by ID
    func getReceipt(id: UUID) -> Receipt? {
        return localReceipts.first { $0.id == id }
    }
    
    /// Clear all local receipts (e.g., after migration to cloud)
    func clearAllReceipts() {
        localReceipts = []
        persistReceipts()
    }
    
    /// Migrate local receipts to cloud (when user subscribes)
    /// Returns the receipts that were migrated
    func migrateToCloud() async throws -> [Receipt] {
        let receiptsToMigrate = localReceipts
        
        for receipt in receiptsToMigrate {
            _ = try await SupabaseManager.shared.createReceipt(receipt)
        }
        
        // Clear local storage after successful migration
        clearAllReceipts()
        
        return receiptsToMigrate
    }
    
    /// Import receipts from cloud to local (when user unsubscribes)
    /// Note: This is read-only - we just load them for display, not delete from cloud
    func cacheCloudReceipts(_ receipts: [Receipt]) {
        // Merge with existing local receipts, avoiding duplicates
        var merged = localReceipts
        for receipt in receipts {
            if !merged.contains(where: { $0.id == receipt.id }) {
                merged.append(receipt)
            }
        }
        
        // Sort by date (most recent first)
        merged.sort { $0.purchase_date > $1.purchase_date }
        
        localReceipts = merged
        persistReceipts()
    }
    
    // MARK: - Private Methods
    
    private func loadReceipts() {
        guard let url = receiptsFileURL,
              fileManager.fileExists(atPath: url.path) else {
            localReceipts = []
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            localReceipts = try decoder.decode([Receipt].self, from: data)
        } catch {
            print("Failed to load local receipts: \(error)")
            localReceipts = []
        }
    }
    
    private func persistReceipts() {
        guard let url = receiptsFileURL else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(localReceipts)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save local receipts: \(error)")
        }
    }
}

// MARK: - Receipt Storage Source

/// Indicates where a receipt is stored
enum ReceiptStorageSource {
    case local      // Stored on device only (free users)
    case cloud      // Stored in Supabase (plus users)
    case cached     // Cloud receipt cached locally for offline viewing
}

/// Wrapper to track receipt source
struct StoredReceipt: Identifiable {
    let receipt: Receipt
    let source: ReceiptStorageSource
    
    var id: UUID { receipt.id }
}
