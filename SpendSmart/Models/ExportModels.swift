//
//  ExportModels.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-01-15.
//

import Foundation

// MARK: - Export Configuration Models

/// Represents the format for data export
enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    case pdf = "PDF"
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .pdf: return "pdf"
        }
    }
    
    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        case .pdf: return "application/pdf"
        }
    }
}

/// Represents the types of data that can be exported
enum ExportDataType: String, CaseIterable {
    case transactions = "Transactions"
    case categories = "Categories"
    case accountInfo = "Account Information"
    case allData = "All Data"
    
    var description: String {
        switch self {
        case .transactions:
            return "All receipt transactions and purchase details"
        case .categories:
            return "Spending breakdown by category"
        case .accountInfo:
            return "Account settings and preferences"
        case .allData:
            return "Complete data export including all information"
        }
    }
}

/// Represents predefined date ranges for export
enum ExportDateRange: String, CaseIterable {
    case last30Days = "Last 30 Days"
    case last6Months = "Last 6 Months"
    case lastYear = "Last Year"
    case allTime = "All Time"
    case custom = "Custom Range"
    
    var dateRange: (start: Date?, end: Date?) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now)
            return (start, now)
        case .last6Months:
            let start = calendar.date(byAdding: .month, value: -6, to: now)
            return (start, now)
        case .lastYear:
            let start = calendar.date(byAdding: .year, value: -1, to: now)
            return (start, now)
        case .allTime:
            return (nil, nil)
        case .custom:
            return (nil, nil) // Will be set by user selection
        }
    }
}

/// Configuration for data export
struct ExportConfiguration {
    var format: ExportFormat
    var dataTypes: Set<ExportDataType>
    var dateRange: ExportDateRange
    var customStartDate: Date?
    var customEndDate: Date?
    var includeImages: Bool
    var convertCurrency: Bool
    var targetCurrency: String
    
    init() {
        self.format = .csv
        self.dataTypes = [.transactions]
        self.dateRange = .allTime
        self.customStartDate = nil
        self.customEndDate = nil
        self.includeImages = false
        self.convertCurrency = true
        self.targetCurrency = CurrencyManager.shared.preferredCurrency
    }
    
    /// Get the effective date range for filtering data
    var effectiveDateRange: (start: Date?, end: Date?) {
        if dateRange == .custom {
            return (customStartDate, customEndDate)
        } else {
            return dateRange.dateRange
        }
    }
}

// MARK: - Export Data Models

/// Sanitized receipt data for export (privacy-safe)
struct ExportReceipt: Codable {
    let id: String
    let storeName: String
    let storeAddress: String
    let receiptName: String
    let purchaseDate: String
    let totalAmount: Double
    let currency: String
    let convertedAmount: Double?
    let convertedCurrency: String?
    let paymentMethod: String
    let totalTax: Double
    let savings: Double
    let items: [ExportReceiptItem]
    
    init(from receipt: Receipt, currencyManager: CurrencyManager, targetCurrency: String, convertCurrency: Bool) {
        self.id = receipt.id.uuidString
        self.storeName = receipt.store_name
        self.storeAddress = receipt.store_address
        self.receiptName = receipt.receipt_name
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        self.purchaseDate = formatter.string(from: receipt.purchase_date)
        
        self.totalAmount = receipt.total_amount
        self.currency = receipt.currency
        self.paymentMethod = receipt.payment_method
        self.totalTax = receipt.total_tax
        self.savings = receipt.savings
        
        if convertCurrency && receipt.currency != targetCurrency {
            self.convertedAmount = currencyManager.convertAmountSync(receipt.total_amount, from: receipt.currency, to: targetCurrency)
            self.convertedCurrency = targetCurrency
        } else {
            self.convertedAmount = nil
            self.convertedCurrency = nil
        }
        
        self.items = receipt.items.map { ExportReceiptItem(from: $0) }
    }
}

/// Sanitized receipt item data for export
struct ExportReceiptItem: Codable {
    let id: String
    let name: String
    let price: Double
    let category: String
    let originalPrice: Double?
    let discountDescription: String?
    let isDiscount: Bool
    
    init(from item: ReceiptItem) {
        self.id = item.id.uuidString
        self.name = item.name
        self.price = item.price
        self.category = item.category
        self.originalPrice = item.originalPrice
        self.discountDescription = item.discountDescription
        self.isDiscount = item.isDiscount
    }
}

/// Category spending summary for export
struct ExportCategorySummary: Codable {
    let category: String
    let totalSpent: Double
    let currency: String
    let transactionCount: Int
    let averageSpent: Double
    let percentage: Double
}

/// Account information for export (privacy-safe)
struct ExportAccountInfo: Codable {
    let accountType: String
    let storageType: String
    let preferredCurrency: String
    let exportDate: String
    let totalReceipts: Int
    let dateRange: String
    
    init(appState: AppState, totalReceipts: Int, dateRange: String) {
        self.accountType = appState.isGuestUser ? "Guest" : "Registered"
        self.storageType = appState.useLocalStorage ? "Local Device" : "Cloud"
        self.preferredCurrency = CurrencyManager.shared.preferredCurrency
        
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        self.exportDate = formatter.string(from: Date())
        
        self.totalReceipts = totalReceipts
        self.dateRange = dateRange
    }
}

/// Complete export data container
struct ExportData: Codable {
    let accountInfo: ExportAccountInfo?
    let receipts: [ExportReceipt]?
    let categorySummary: [ExportCategorySummary]?
    let exportConfiguration: ExportConfigurationData
    
    struct ExportConfigurationData: Codable {
        let format: String
        let dataTypes: [String]
        let dateRange: String
        let includeImages: Bool
        let convertCurrency: Bool
        let targetCurrency: String
    }
}

// MARK: - Export Result

/// Result of an export operation
enum ExportResult {
    case success(URL)
    case failure(ExportError)
}

/// Errors that can occur during export
enum ExportError: LocalizedError {
    case noDataToExport
    case fileCreationFailed
    case pdfGenerationFailed
    case permissionDenied
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .noDataToExport:
            return "No data available for the selected criteria"
        case .fileCreationFailed:
            return "Failed to create export file"
        case .pdfGenerationFailed:
            return "Failed to generate PDF document"
        case .permissionDenied:
            return "Permission denied to save file"
        case .unknownError(let message):
            return "Export failed: \(message)"
        }
    }
}
