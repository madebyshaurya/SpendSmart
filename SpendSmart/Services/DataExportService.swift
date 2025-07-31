//
//  DataExportService.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-01-15.
//

import Foundation
import SwiftUI
import PDFKit
import WebKit
import Supabase

class DataExportService: ObservableObject {
    static let shared = DataExportService()

    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: ExportError?

    private let currencyManager = CurrencyManager.shared

    private init() {}

    // MARK: - Main Export Function

    /// Export data based on the provided configuration
    func exportData(configuration: ExportConfiguration, appState: AppState) async -> ExportResult {
        await MainActor.run {
            isExporting = true
            exportProgress = 0.0
            exportError = nil
        }

        do {
            // Step 1: Fetch data (20% progress)
            await updateProgress(0.2)
            let receipts = try await fetchReceipts(appState: appState, configuration: configuration)

            // Step 2: Process and filter data (40% progress)
            await updateProgress(0.4)
            let exportData = try await processData(receipts: receipts, configuration: configuration, appState: appState)

            // Step 3: Generate file (80% progress)
            await updateProgress(0.8)
            let fileURL = try await generateFile(data: exportData, configuration: configuration)

            // Step 4: Complete (100% progress)
            await updateProgress(1.0)

            await MainActor.run {
                isExporting = false
            }

            return .success(fileURL)

        } catch let error as ExportError {
            await MainActor.run {
                isExporting = false
                exportError = error
            }
            return .failure(error)
        } catch {
            let exportError = ExportError.unknownError(error.localizedDescription)
            await MainActor.run {
                isExporting = false
                self.exportError = exportError
            }
            return .failure(exportError)
        }
    }

    // MARK: - Data Fetching

    private func fetchReceipts(appState: AppState, configuration: ExportConfiguration) async throws -> [Receipt] {
        var receipts: [Receipt] = []

        if appState.useLocalStorage {
            // Fetch from local storage
            receipts = LocalStorageService.shared.getReceipts()
        } else {
            // Fetch from backend API via SupabaseManager
            do {
                // Fetch all receipts using the backend API
                receipts = try await supabase.fetchReceipts(page: 1, limit: 1000) // Get all receipts
            } catch {
                // If backend fetch fails, throw a more specific error
                print("❌ Backend fetch error: \(error)")
                throw ExportError.unknownError("Failed to fetch data from cloud storage: \(error.localizedDescription)")
            }
        }

        // Filter by date range
        let (startDate, endDate) = configuration.effectiveDateRange
        if let startDate = startDate {
            receipts = receipts.filter { $0.purchase_date >= startDate }
        }
        if let endDate = endDate {
            receipts = receipts.filter { $0.purchase_date <= endDate }
        }

        if receipts.isEmpty {
            throw ExportError.noDataToExport
        }

        return receipts
    }

    // MARK: - Data Processing

    private func processData(receipts: [Receipt], configuration: ExportConfiguration, appState: AppState) async throws -> ExportData {
        let dateRangeString = formatDateRange(configuration: configuration)

        var exportReceipts: [ExportReceipt]? = nil
        var categorySummary: [ExportCategorySummary]? = nil
        var accountInfo: ExportAccountInfo? = nil

        // Process based on selected data types
        if configuration.dataTypes.contains(.transactions) || configuration.dataTypes.contains(.allData) {
            exportReceipts = receipts.map { receipt in
                ExportReceipt(
                    from: receipt,
                    currencyManager: currencyManager,
                    targetCurrency: configuration.targetCurrency,
                    convertCurrency: configuration.convertCurrency
                )
            }
        }

        if configuration.dataTypes.contains(.categories) || configuration.dataTypes.contains(.allData) {
            categorySummary = generateCategorySummary(receipts: receipts, configuration: configuration)
        }

        if configuration.dataTypes.contains(.accountInfo) || configuration.dataTypes.contains(.allData) {
            accountInfo = ExportAccountInfo(
                appState: appState,
                totalReceipts: receipts.count,
                dateRange: dateRangeString
            )
        }

        let exportConfigData = ExportData.ExportConfigurationData(
            format: configuration.format.rawValue,
            dataTypes: Array(configuration.dataTypes).map { $0.rawValue },
            dateRange: dateRangeString,
            includeImages: configuration.includeImages,
            convertCurrency: configuration.convertCurrency,
            targetCurrency: configuration.targetCurrency
        )

        return ExportData(
            accountInfo: accountInfo,
            receipts: exportReceipts,
            categorySummary: categorySummary,
            exportConfiguration: exportConfigData
        )
    }

    private func generateCategorySummary(receipts: [Receipt], configuration: ExportConfiguration) -> [ExportCategorySummary] {
        var categoryTotals: [String: Double] = [:]
        var categoryCounts: [String: Int] = [:]

        let targetCurrency = configuration.targetCurrency

        for receipt in receipts {
            for item in receipt.items where !item.isDiscount {
                let convertedAmount = configuration.convertCurrency ?
                    currencyManager.convertAmountSync(item.price, from: receipt.currency, to: targetCurrency) :
                    item.price

                categoryTotals[item.category, default: 0] += convertedAmount
                categoryCounts[item.category, default: 0] += 1
            }

            // Add tax as a separate category
            let convertedTax = configuration.convertCurrency ?
                currencyManager.convertAmountSync(receipt.total_tax, from: receipt.currency, to: targetCurrency) :
                receipt.total_tax

            if convertedTax > 0 {
                categoryTotals["Tax", default: 0] += convertedTax
                categoryCounts["Tax", default: 0] += 1
            }
        }

        let totalSpent = categoryTotals.values.reduce(0, +)

        return categoryTotals.map { category, total in
            ExportCategorySummary(
                category: category,
                totalSpent: total,
                currency: targetCurrency,
                transactionCount: categoryCounts[category] ?? 0,
                averageSpent: total / Double(categoryCounts[category] ?? 1),
                percentage: totalSpent > 0 ? (total / totalSpent) * 100 : 0
            )
        }.sorted { $0.totalSpent > $1.totalSpent }
    }

    private func formatDateRange(configuration: ExportConfiguration) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let (startDate, endDate) = configuration.effectiveDateRange

        if let startDate = startDate, let endDate = endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else if let startDate = startDate {
            return "From \(formatter.string(from: startDate))"
        } else if let endDate = endDate {
            return "Until \(formatter.string(from: endDate))"
        } else {
            return "All Time"
        }
    }

    // MARK: - File Generation

    private func generateFile(data: ExportData, configuration: ExportConfiguration) async throws -> URL {
        let fileName = generateFileName(configuration: configuration)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)

        do {
            switch configuration.format {
            case .csv:
                try generateCSVFile(data: data, url: fileURL)
            case .json:
                try generateJSONFile(data: data, url: fileURL)
            case .pdf:
                try await generatePDFFile(data: data, url: fileURL)
            }
        } catch {
            print("❌ File generation error: \(error)")
            throw ExportError.fileCreationFailed
        }

        return fileURL
    }

    private func generateFileName(configuration: ExportConfiguration) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let dataTypeString = configuration.dataTypes.count == 1 ?
            configuration.dataTypes.first?.rawValue.replacingOccurrences(of: " ", with: "_") ?? "Data" :
            "SpendSmart_Data"

        return "\(dataTypeString)_\(timestamp).\(configuration.format.fileExtension)"
    }

    // MARK: - CSV Generation

    private func generateCSVFile(data: ExportData, url: URL) throws {
        var csvContent = ""

        // Add account info header if available
        if let accountInfo = data.accountInfo {
            csvContent += "SpendSmart Data Export\n"
            csvContent += "Export Date,\(csvEscape(accountInfo.exportDate))\n"
            csvContent += "Account Type,\(csvEscape(accountInfo.accountType))\n"
            csvContent += "Storage Type,\(csvEscape(accountInfo.storageType))\n"
            csvContent += "Preferred Currency,\(csvEscape(accountInfo.preferredCurrency))\n"
            csvContent += "Date Range,\(csvEscape(accountInfo.dateRange))\n"
            csvContent += "Total Receipts,\(accountInfo.totalReceipts)\n\n"
        }

        // Add receipts data
        if let receipts = data.receipts, !receipts.isEmpty {
            csvContent += "TRANSACTIONS\n"
            csvContent += "Receipt ID,Store Name,Store Address,Receipt Name,Purchase Date,Total Amount,Currency"
            if receipts.first?.convertedAmount != nil {
                csvContent += ",Converted Amount,Converted Currency"
            }
            csvContent += ",Payment Method,Tax,Savings\n"

            for receipt in receipts {
                csvContent += "\(receipt.id),\(csvEscape(receipt.storeName)),\(csvEscape(receipt.storeAddress)),\(csvEscape(receipt.receiptName)),\(receipt.purchaseDate),\(receipt.totalAmount),\(receipt.currency)"
                if let convertedAmount = receipt.convertedAmount, let convertedCurrency = receipt.convertedCurrency {
                    csvContent += ",\(convertedAmount),\(convertedCurrency)"
                }
                csvContent += ",\(csvEscape(receipt.paymentMethod)),\(receipt.totalTax),\(receipt.savings)\n"
            }
            csvContent += "\n"

            // Add items data
            csvContent += "RECEIPT ITEMS\n"
            csvContent += "Receipt ID,Item Name,Price,Category,Original Price,Discount Description,Is Discount\n"

            for receipt in receipts {
                for item in receipt.items {
                    csvContent += "\(receipt.id),\(csvEscape(item.name)),\(item.price),\(csvEscape(item.category)),\(item.originalPrice ?? 0),\(csvEscape(item.discountDescription ?? "")),\(item.isDiscount)\n"
                }
            }
            csvContent += "\n"
        }

        // Add category summary
        if let categories = data.categorySummary, !categories.isEmpty {
            csvContent += "CATEGORY SUMMARY\n"
            csvContent += "Category,Total Spent,Currency,Transaction Count,Average Spent,Percentage\n"

            for category in categories {
                csvContent += "\(csvEscape(category.category)),\(category.totalSpent),\(category.currency),\(category.transactionCount),\(category.averageSpent),\(String(format: "%.2f", category.percentage))%\n"
            }
        }

        try csvContent.write(to: url, atomically: true, encoding: .utf8)
    }

    private func csvEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    // MARK: - JSON Generation

    private func generateJSONFile(data: ExportData, url: URL) throws {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let jsonData = try encoder.encode(data)
            try jsonData.write(to: url)
        } catch {
            print("❌ JSON encoding error: \(error)")
            throw ExportError.fileCreationFailed
        }
    }

    // MARK: - PDF Generation

    private func generatePDFFile(data: ExportData, url: URL) async throws {
        // Create PDF using UIGraphics (iOS approach)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size
        let margin: CGFloat = 50
        let contentRect = CGRect(x: margin, y: margin, width: pageRect.width - 2 * margin, height: pageRect.height - 2 * margin)

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        UIGraphicsBeginPDFPage()

        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDFContext()
            throw ExportError.pdfGenerationFailed
        }

        var currentY: CGFloat = contentRect.minY + 50 // Start from top with margin

        // Add title
        currentY = addTitle(context: context, rect: contentRect, y: currentY)
        currentY += 30

        // Add account information
        if let accountInfo = data.accountInfo {
            currentY = addAccountInfo(accountInfo, context: context, rect: contentRect, y: currentY)
            currentY += 20
        }

        // Add category summary
        if let categories = data.categorySummary, !categories.isEmpty {
            currentY = addCategorySummary(categories, context: context, rect: contentRect, y: currentY)
            currentY += 20
        }

        // Add transactions
        if let receipts = data.receipts, !receipts.isEmpty {
            addTransactions(receipts, context: context, rect: contentRect, y: currentY)
        }

        UIGraphicsEndPDFContext()

        // Write PDF data to file
        try pdfData.write(to: url)
    }

    private func addTitle(context: CGContext, rect: CGRect, y: CGFloat) -> CGFloat {
        let title = "SpendSmart Data Export"
        let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0) // Blue color
        ]

        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let titleSize = titleString.size()
        let titleRect = CGRect(x: rect.midX - titleSize.width/2, y: y, width: titleSize.width, height: titleSize.height)

        // Draw title
        titleString.draw(in: titleRect)

        // Draw underline
        context.setStrokeColor(UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0).cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: titleRect.minX, y: titleRect.maxY + 5))
        context.addLine(to: CGPoint(x: titleRect.maxX, y: titleRect.maxY + 5))
        context.strokePath()

        return titleRect.maxY + 15
    }

    private func addAccountInfo(_ accountInfo: ExportAccountInfo, context: CGContext, rect: CGRect, y: CGFloat) -> CGFloat {
        let sectionTitle = "Account Information"
        let font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let textFont = UIFont.systemFont(ofSize: 12)

        var currentY = y

        // Add section title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        let titleString = NSAttributedString(string: sectionTitle, attributes: titleAttributes)
        let titleSize = titleString.size()
        let titleRect = CGRect(x: rect.minX, y: currentY, width: rect.width, height: titleSize.height)

        // Draw section title
        titleString.draw(in: titleRect)
        currentY = titleRect.maxY + 15

        // Add account info details
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.black
        ]

        let infoItems = [
            "Export Date: \(accountInfo.exportDate)",
            "Account Type: \(accountInfo.accountType)",
            "Storage Type: \(accountInfo.storageType)",
            "Preferred Currency: \(accountInfo.preferredCurrency)",
            "Date Range: \(accountInfo.dateRange)",
            "Total Receipts: \(accountInfo.totalReceipts)"
        ]

        for item in infoItems {
            let itemString = NSAttributedString(string: item, attributes: textAttributes)
            let itemSize = itemString.size()
            let itemRect = CGRect(x: rect.minX + 20, y: currentY, width: rect.width - 40, height: itemSize.height)

            itemString.draw(in: itemRect)
            currentY = itemRect.maxY + 5
        }

        return currentY
    }

    private func addCategorySummary(_ categories: [ExportCategorySummary], context: CGContext, rect: CGRect, y: CGFloat) -> CGFloat {
        let sectionTitle = "Category Summary"
        let font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let textFont = UIFont.systemFont(ofSize: 10)

        var currentY = y

        // Add section title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        let titleString = NSAttributedString(string: sectionTitle, attributes: titleAttributes)
        let titleSize = titleString.size()
        let titleRect = CGRect(x: rect.minX, y: currentY, width: rect.width, height: titleSize.height)

        // Draw section title
        titleString.draw(in: titleRect)
        currentY = titleRect.maxY + 20

        // Add table headers
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.black
        ]

        let headers = ["Category", "Total Spent", "Transactions", "Average", "Percentage"]
        let columnWidth = rect.width / CGFloat(headers.count)

        for (index, header) in headers.enumerated() {
            let headerString = NSAttributedString(string: header, attributes: textAttributes)
            let headerRect = CGRect(x: rect.minX + CGFloat(index) * columnWidth, y: currentY, width: columnWidth, height: 15)

            headerString.draw(in: headerRect)
        }

        currentY += 25

        // Add category data
        for category in categories.prefix(10) { // Limit to first 10 categories
            let rowData = [
                category.category,
                String(format: "%.2f %@", category.totalSpent, category.currency),
                "\(category.transactionCount)",
                String(format: "%.2f %@", category.averageSpent, category.currency),
                String(format: "%.1f%%", category.percentage)
            ]

            for (index, data) in rowData.enumerated() {
                let dataString = NSAttributedString(string: data, attributes: textAttributes)
                let dataRect = CGRect(x: rect.minX + CGFloat(index) * columnWidth, y: currentY, width: columnWidth, height: 12)

                dataString.draw(in: dataRect)
            }

            currentY += 15
        }

        return currentY
    }

    private func addTransactions(_ receipts: [ExportReceipt], context: CGContext, rect: CGRect, y: CGFloat) {
        let sectionTitle = "Recent Transactions"
        let font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let textFont = UIFont.systemFont(ofSize: 9)

        var currentY = y

        // Add section title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        let titleString = NSAttributedString(string: sectionTitle, attributes: titleAttributes)
        let titleSize = titleString.size()
        let titleRect = CGRect(x: rect.minX, y: currentY, width: rect.width, height: titleSize.height)

        // Draw section title
        titleString.draw(in: titleRect)
        currentY = titleRect.maxY + 20

        // Add table headers
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.black
        ]

        let headers = ["Date", "Store", "Amount", "Payment"]
        let columnWidths: [CGFloat] = [rect.width * 0.2, rect.width * 0.4, rect.width * 0.25, rect.width * 0.15]

        var xOffset: CGFloat = rect.minX
        for (index, header) in headers.enumerated() {
            let headerString = NSAttributedString(string: header, attributes: textAttributes)
            let headerRect = CGRect(x: xOffset, y: currentY, width: columnWidths[index], height: 12)

            headerString.draw(in: headerRect)
            xOffset += columnWidths[index]
        }

        currentY += 20

        // Add transaction data (limit to first 15 transactions)
        for receipt in receipts.prefix(15) {
            let amountDisplay = receipt.convertedAmount != nil ?
                String(format: "%.2f %@", receipt.convertedAmount!, receipt.convertedCurrency!) :
                String(format: "%.2f %@", receipt.totalAmount, receipt.currency)

            let rowData = [
                receipt.purchaseDate,
                receipt.storeName,
                amountDisplay,
                receipt.paymentMethod
            ]

            xOffset = rect.minX
            for (index, data) in rowData.enumerated() {
                let dataString = NSAttributedString(string: data, attributes: textAttributes)
                let dataRect = CGRect(x: xOffset, y: currentY, width: columnWidths[index], height: 10)

                dataString.draw(in: dataRect)
                xOffset += columnWidths[index]
            }

            currentY += 12
        }
    }



    // MARK: - Helper Functions

    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            exportProgress = progress
        }
    }
}
