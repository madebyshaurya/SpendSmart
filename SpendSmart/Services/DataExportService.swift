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
        var categoryData: [String: (total: Double, count: Int, savings: Double, originalTotal: Double)] = [:]

        let targetCurrency = configuration.targetCurrency

        for receipt in receipts {
            for item in receipt.items where !item.isDiscount {
                let convertedAmount = configuration.convertCurrency ?
                    currencyManager.convertAmountSync(item.price, from: receipt.currency, to: targetCurrency) :
                    item.price

                let itemSavings = calculateSavings(for: item)
                
                let originalPrice = item.originalPrice ?? item.price
                let convertedOriginalPrice = configuration.convertCurrency ?
                    currencyManager.convertAmountSync(originalPrice, from: receipt.currency, to: targetCurrency) :
                    originalPrice
                
                let convertedSavings = configuration.convertCurrency ?
                    currencyManager.convertAmountSync(itemSavings, from: receipt.currency, to: targetCurrency) :
                    itemSavings

                let current = categoryData[item.category] ?? (total: 0, count: 0, savings: 0, originalTotal: 0)
                categoryData[item.category] = (
                    total: current.total + convertedAmount,
                    count: current.count + 1,
                    savings: current.savings + convertedSavings,
                    originalTotal: current.originalTotal + convertedOriginalPrice
                )
            }

            // Add tax as a separate category
            let convertedTax = configuration.convertCurrency ?
                currencyManager.convertAmountSync(receipt.total_tax, from: receipt.currency, to: targetCurrency) :
                receipt.total_tax

            if convertedTax > 0 {
                let current = categoryData["Tax"] ?? (total: 0, count: 0, savings: 0, originalTotal: 0)
                categoryData["Tax"] = (
                    total: current.total + convertedTax,
                    count: current.count + 1,
                    savings: current.savings,
                    originalTotal: current.originalTotal + convertedTax
                )
            }
        }

        let totalSpent = categoryData.values.reduce(0) { $0 + $1.total }

        return categoryData.map { category, data in
            let averageSpent = data.count > 0 ? data.total / Double(data.count) : 0
            let averageSavings = data.count > 0 ? data.savings / Double(data.count) : 0
            let savingsPercentage = data.originalTotal > 0 ? (data.savings / data.originalTotal) * 100 : 0

            return ExportCategorySummary(
                category: category,
                totalSpent: data.total,
                currency: targetCurrency,
                transactionCount: data.count,
                averageSpent: averageSpent,
                percentage: totalSpent > 0 ? (data.total / totalSpent) * 100 : 0,
                totalSavings: data.savings,
                averageSavings: averageSavings,
                savingsPercentage: savingsPercentage,
                originalTotal: data.originalTotal
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

        // Add receipts data with comprehensive information
        if let receipts = data.receipts, !receipts.isEmpty {
            csvContent += "DETAILED TRANSACTIONS\n"
            csvContent += "Receipt ID,Store Name,Store Address,Receipt Name,Purchase Date,Total Amount,Currency"
            if receipts.first?.convertedAmount != nil {
                csvContent += ",Converted Amount,Converted Currency"
            }
            csvContent += ",Payment Method,Tax,Savings,Original Price Before Discounts"
            if data.exportConfiguration.includeImages {
                csvContent += ",Image URLs"
            }
            csvContent += "\n"

            for receipt in receipts {
                // Calculate original price before discounts
                let originalPrice = receipt.items.reduce(0.0) { total, item in
                    if item.isDiscount {
                        return total
                    } else if let originalPrice = item.originalPrice, originalPrice > item.price {
                        return total + originalPrice
                    } else {
                        return total + item.price
                    }
                }
                
                csvContent += "\(receipt.id),\(csvEscape(receipt.storeName)),\(csvEscape(receipt.storeAddress)),\(csvEscape(receipt.receiptName)),\(receipt.purchaseDate),\(receipt.totalAmount),\(receipt.currency)"
                if let convertedAmount = receipt.convertedAmount, let convertedCurrency = receipt.convertedCurrency {
                    csvContent += ",\(convertedAmount),\(convertedCurrency)"
                }
                csvContent += ",\(csvEscape(receipt.paymentMethod)),\(receipt.totalTax),\(receipt.savings),\(originalPrice)"
                if data.exportConfiguration.includeImages {
                    csvContent += ",\(csvEscape(receipt.imageUrls?.joined(separator: "; ") ?? ""))"
                }
                csvContent += "\n"
            }
            csvContent += "\n"

            // Add detailed items data
            csvContent += "DETAILED RECEIPT ITEMS\n"
            csvContent += "Receipt ID,Item Name,Price,Category,Original Price,Discount Description,Is Discount,Savings Amount\n"

            for receipt in receipts {
                for item in receipt.items {
                    let savingsAmount = calculateSavings(for: item)
                    
                    csvContent += "\(receipt.id),\(csvEscape(item.name)),\(item.price),\(csvEscape(item.category)),\(item.originalPrice ?? 0),\(csvEscape(item.discountDescription ?? "")),\(item.isDiscount),\(savingsAmount)\n"
                }
            }
            csvContent += "\n"
        }

        // Add comprehensive category summary
        if let categories = data.categorySummary, !categories.isEmpty {
            csvContent += "CATEGORY SUMMARY\n"
            csvContent += "Category,Total Spent,Currency,Transaction Count,Average Spent,Percentage,Total Savings,Average Savings,Savings Percentage,Original Total\n"

            for category in categories {
                csvContent += "\(csvEscape(category.category)),\(category.totalSpent),\(category.currency),\(category.transactionCount),\(category.averageSpent),\(String(format: "%.2f", category.percentage))%,\(category.totalSavings),\(category.averageSavings),\(String(format: "%.2f", category.savingsPercentage))%,\(category.originalTotal)\n"
            }
            csvContent += "\n"
        }

        // Add export configuration details
        csvContent += "EXPORT CONFIGURATION\n"
        csvContent += "Format,\(data.exportConfiguration.format)\n"
        csvContent += "Data Types,\(data.exportConfiguration.dataTypes.joined(separator: "; "))\n"
        csvContent += "Date Range,\(data.exportConfiguration.dateRange)\n"
        csvContent += "Include Images,\(data.exportConfiguration.includeImages)\n"
        csvContent += "Convert Currency,\(data.exportConfiguration.convertCurrency)\n"
        csvContent += "Target Currency,\(data.exportConfiguration.targetCurrency)\n"

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

            // Create enhanced export data with additional metadata
            let enhancedData = EnhancedExportData(
                metadata: ExportMetadata(
                    exportDate: Date(),
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                    exportFormat: "JSON",
                    totalReceipts: data.receipts?.count ?? 0,
                    totalItems: data.receipts?.reduce(0) { $0 + $1.items.count } ?? 0,
                    totalCategories: data.categorySummary?.count ?? 0
                ),
                accountInfo: data.accountInfo,
                receipts: data.receipts,
                categorySummary: data.categorySummary,
                exportConfiguration: data.exportConfiguration
            )

            let jsonData = try encoder.encode(enhancedData)
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
        let margin: CGFloat = 40
        let contentRect = CGRect(x: margin, y: margin, width: pageRect.width - 2 * margin, height: pageRect.height - 2 * margin)

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)

        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDFContext()
            throw ExportError.pdfGenerationFailed
        }

        var currentPage = 0
        var currentY: CGFloat = contentRect.minY + 30

        // Add title to first page
        currentY = addTitle(context: context, rect: contentRect, y: currentY)
        currentY += 40

        // Add account information
        if let accountInfo = data.accountInfo {
            currentY = addAccountInfo(accountInfo, context: context, rect: contentRect, y: currentY)
            currentY += 30
        }

        // Add category summary
        if let categories = data.categorySummary, !categories.isEmpty {
            currentY = addCategorySummary(categories, context: context, rect: contentRect, y: currentY)
            currentY += 30
        }

        // Add transactions with detailed items
        if let receipts = data.receipts, !receipts.isEmpty {
            currentY = addDetailedTransactions(receipts, context: context, rect: contentRect, y: currentY, currentPage: &currentPage, includeImages: data.exportConfiguration.includeImages)
        }

        UIGraphicsEndPDFContext()

        // Write PDF data to file
        try pdfData.write(to: url)
    }

    private func addTitle(context: CGContext, rect: CGRect, y: CGFloat) -> CGFloat {
        let title = "SpendSmart Data Export"
        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
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
        context.setLineWidth(3)
        context.move(to: CGPoint(x: titleRect.minX, y: titleRect.maxY + 8))
        context.addLine(to: CGPoint(x: titleRect.maxX, y: titleRect.maxY + 8))
        context.strokePath()

        return titleRect.maxY + 20
    }

    private func addAccountInfo(_ accountInfo: ExportAccountInfo, context: CGContext, rect: CGRect, y: CGFloat) -> CGFloat {
        let sectionTitle = "Account Information"
        let font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let textFont = UIFont.systemFont(ofSize: 14)

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
            currentY = itemRect.maxY + 8
        }

        return currentY
    }

    private func addCategorySummary(_ categories: [ExportCategorySummary], context: CGContext, rect: CGRect, y: CGFloat) -> CGFloat {
        let sectionTitle = "Category Summary"
        let font = UIFont.systemFont(ofSize: 18, weight: .semibold)
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
        currentY = titleRect.maxY + 25

        // Add table headers
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.black
        ]

        let headers = ["Category", "Total Spent", "Transactions", "Average", "Percentage", "Savings"]
        let columnWidth = rect.width / CGFloat(headers.count)

        // Draw header background
        context.setFillColor(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).cgColor)
        context.fill(CGRect(x: rect.minX, y: currentY - 5, width: rect.width, height: 25))

        for (index, header) in headers.enumerated() {
            let headerString = NSAttributedString(string: header, attributes: textAttributes)
            let headerRect = CGRect(x: rect.minX + CGFloat(index) * columnWidth + 5, y: currentY, width: columnWidth - 10, height: 20)

            headerString.draw(in: headerRect)
        }

        currentY += 30

        // Add category data
        for category in categories {
            let rowData = [
                category.category,
                String(format: "%.2f %@", category.totalSpent, category.currency),
                "\(category.transactionCount)",
                String(format: "%.2f %@", category.averageSpent, category.currency),
                String(format: "%.1f%%", category.percentage),
                String(format: "%.2f %@", category.totalSavings, category.currency)
            ]

            for (index, data) in rowData.enumerated() {
                let dataString = NSAttributedString(string: data, attributes: textAttributes)
                let dataRect = CGRect(x: rect.minX + CGFloat(index) * columnWidth + 5, y: currentY, width: columnWidth - 10, height: 18)

                dataString.draw(in: dataRect)
            }

            currentY += 20
        }

        return currentY
    }

    private func addDetailedTransactions(_ receipts: [ExportReceipt], context: CGContext, rect: CGRect, y: CGFloat, currentPage: inout Int, includeImages: Bool) -> CGFloat {
        let sectionTitle = "Detailed Transactions"
        let font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let textFont = UIFont.systemFont(ofSize: 11)
        let itemFont = UIFont.systemFont(ofSize: 10)

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
        currentY = titleRect.maxY + 25

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.black
        ]

        let itemAttributes: [NSAttributedString.Key: Any] = [
            .font: itemFont,
            .foregroundColor: UIColor.darkGray
        ]

        for (receiptIndex, receipt) in receipts.enumerated() {
            // Check if we need a new page
            if currentY > rect.maxY - 200 {
                UIGraphicsBeginPDFPage()
                currentPage += 1
                currentY = rect.minY + 30
                
                // Add page header
                let pageHeader = "Page \(currentPage) - SpendSmart Data Export"
                let pageHeaderAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.gray
                ]
                let pageHeaderString = NSAttributedString(string: pageHeader, attributes: pageHeaderAttributes)
                pageHeaderString.draw(in: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 15))
                currentY += 25
            }

            // Receipt header with background
            context.setFillColor(UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 0.1).cgColor)
            context.fill(CGRect(x: rect.minX, y: currentY - 5, width: rect.width, height: 35))

            // Receipt title
            let receiptTitle = "Receipt #\(receiptIndex + 1): \(receipt.storeName)"
            let receiptTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0)
            ]
            let receiptTitleString = NSAttributedString(string: receiptTitle, attributes: receiptTitleAttributes)
            receiptTitleString.draw(in: CGRect(x: rect.minX + 10, y: currentY, width: rect.width - 20, height: 20))
            currentY += 25

            // Receipt details
            var receiptDetails = [
                "Date: \(receipt.purchaseDate)",
                "Store: \(receipt.storeName)",
                "Address: \(receipt.storeAddress)",
                "Payment Method: \(receipt.paymentMethod)",
                "Total Amount: \(String(format: "%.2f %@", receipt.totalAmount, receipt.currency))"
            ]

            if let convertedAmount = receipt.convertedAmount, let convertedCurrency = receipt.convertedCurrency {
                receiptDetails.append("Converted Amount: \(String(format: "%.2f %@", convertedAmount, convertedCurrency))")
            }

            receiptDetails.append("Tax: \(String(format: "%.2f %@", receipt.totalTax, receipt.currency))")
            receiptDetails.append("Savings: \(String(format: "%.2f %@", receipt.savings, receipt.currency))")

            for detail in receiptDetails {
                let detailString = NSAttributedString(string: detail, attributes: textAttributes)
                let detailRect = CGRect(x: rect.minX + 20, y: currentY, width: rect.width - 40, height: 16)
                detailString.draw(in: detailRect)
                currentY += 18
            }

            currentY += 10

            // Items section
            if !receipt.items.isEmpty {
                let itemsTitle = "Items:"
                let itemsTitleString = NSAttributedString(string: itemsTitle, attributes: textAttributes)
                itemsTitleString.draw(in: CGRect(x: rect.minX + 20, y: currentY, width: rect.width - 40, height: 16))
                currentY += 20

                // Items table header
                let itemHeaders = ["Item Name", "Price", "Category", "Original Price", "Discount"]
                let itemColumnWidths: [CGFloat] = [rect.width * 0.35, rect.width * 0.15, rect.width * 0.25, rect.width * 0.15, rect.width * 0.10]

                // Draw header background
                context.setFillColor(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).cgColor)
                context.fill(CGRect(x: rect.minX + 20, y: currentY - 3, width: rect.width - 40, height: 20))

                var xOffset: CGFloat = rect.minX + 20
                for (index, header) in itemHeaders.enumerated() {
                    let headerString = NSAttributedString(string: header, attributes: textAttributes)
                    let headerRect = CGRect(x: xOffset + 2, y: currentY, width: itemColumnWidths[index] - 4, height: 16)
                    headerString.draw(in: headerRect)
                    xOffset += itemColumnWidths[index]
                }
                currentY += 25

                // Items data
                for item in receipt.items {
                    // Check if we need a new page for items
                    if currentY > rect.maxY - 100 {
                        UIGraphicsBeginPDFPage()
                        currentPage += 1
                        currentY = rect.minY + 30
                        
                        // Add page header
                        let pageHeader = "Page \(currentPage) - Receipt #\(receiptIndex + 1) Items"
                        let pageHeaderAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                            .foregroundColor: UIColor.gray
                        ]
                        let pageHeaderString = NSAttributedString(string: pageHeader, attributes: pageHeaderAttributes)
                        pageHeaderString.draw(in: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 15))
                        currentY += 25
                    }

                    let itemData = [
                        item.name,
                        String(format: "%.2f", item.price),
                        item.category,
                        item.originalPrice != nil ? String(format: "%.2f", item.originalPrice!) : "-",
                        item.isDiscount ? "Yes" : "No"
                    ]

                    xOffset = rect.minX + 20
                    for (index, data) in itemData.enumerated() {
                        let dataString = NSAttributedString(string: data, attributes: itemAttributes)
                        let dataRect = CGRect(x: xOffset + 2, y: currentY, width: itemColumnWidths[index] - 4, height: 14)
                        dataString.draw(in: dataRect)
                        xOffset += itemColumnWidths[index]
                    }
                    currentY += 16
                }
            }

            currentY += 20

            // Add receipt images if enabled
            if includeImages {
                // We need to get the original Receipt object to access image_urls
                // For now, we'll add a placeholder for images
                let imagesTitle = "Receipt Images: (Images would be included here)"
                let imagesTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.gray
                ]
                let imagesTitleString = NSAttributedString(string: imagesTitle, attributes: imagesTitleAttributes)
                imagesTitleString.draw(in: CGRect(x: rect.minX + 20, y: currentY, width: rect.width - 40, height: 16))
                currentY += 25
            }

            // Add separator line
            context.setStrokeColor(UIColor.lightGray.cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: rect.minX, y: currentY))
            context.addLine(to: CGPoint(x: rect.maxX, y: currentY))
            context.strokePath()
            currentY += 15
        }

        return currentY
    }



    // MARK: - Image Handling

    /// Load image from URL (supports both local and remote URLs)
    private func loadImage(from urlString: String) -> UIImage? {
        if urlString.hasPrefix("local://") {
            // Handle local images
            let filename = String(urlString.dropFirst(8)) // Remove "local://" prefix
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let imageURL = documentsPath.appendingPathComponent(filename)
            
            if let imageData = try? Data(contentsOf: imageURL),
               let image = UIImage(data: imageData) {
                return image
            }
        } else if let url = URL(string: urlString) {
            // Handle remote images
            if let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                return image
            }
        }
        return nil
    }

    /// Add receipt images to PDF if enabled
    private func addReceiptImages(_ receipt: Receipt, context: CGContext, rect: CGRect, y: CGFloat, currentPage: inout Int) -> CGFloat {
        var currentY = y
        
        if !receipt.image_urls.isEmpty {
            // Add images section header
            let imagesTitle = "Receipt Images:"
            let imagesTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            let imagesTitleString = NSAttributedString(string: imagesTitle, attributes: imagesTitleAttributes)
            imagesTitleString.draw(in: CGRect(x: rect.minX + 20, y: currentY, width: rect.width - 40, height: 16))
            currentY += 25
            
            // Add each image
            for (index, imageUrl) in receipt.image_urls.enumerated() {
                if let image = loadImage(from: imageUrl) {
                    // Check if we need a new page for the image
                    if currentY > rect.maxY - 200 {
                        UIGraphicsBeginPDFPage()
                        currentPage += 1
                        currentY = rect.minY + 30
                        
                        // Add page header
                        let pageHeader = "Page \(currentPage) - Receipt Images"
                        let pageHeaderAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                            .foregroundColor: UIColor.gray
                        ]
                        let pageHeaderString = NSAttributedString(string: pageHeader, attributes: pageHeaderAttributes)
                        pageHeaderString.draw(in: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 15))
                        currentY += 25
                    }
                    
                    // Calculate image dimensions to fit within page
                    let maxImageWidth = rect.width - 40
                    let maxImageHeight = 300.0
                    
                    let imageSize = image.size
                    let widthRatio = maxImageWidth / imageSize.width
                    let heightRatio = maxImageHeight / imageSize.height
                    let scaleFactor = min(widthRatio, heightRatio, 1.0) // Don't scale up
                    
                    let scaledWidth = imageSize.width * scaleFactor
                    let scaledHeight = imageSize.height * scaleFactor
                    
                    let imageRect = CGRect(
                        x: rect.minX + 20,
                        y: currentY,
                        width: scaledWidth,
                        height: scaledHeight
                    )
                    
                    // Draw image
                    image.draw(in: imageRect)
                    
                    // Add image caption
                    let caption = "Image \(index + 1) of \(receipt.image_urls.count)"
                    let captionAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10),
                        .foregroundColor: UIColor.gray
                    ]
                    let captionString = NSAttributedString(string: caption, attributes: captionAttributes)
                    captionString.draw(in: CGRect(x: rect.minX + 20, y: currentY + scaledHeight + 5, width: rect.width - 40, height: 12))
                    
                    currentY += scaledHeight + 25
                }
            }
        }
        
        return currentY
    }

    // MARK: - Helper Functions
    
    /// Calculate savings amount for a receipt item
    private func calculateSavings(for item: ReceiptItem) -> Double {
        if item.isDiscount {
            return abs(item.price)
        } else if let originalPrice = item.originalPrice, originalPrice > item.price {
            return originalPrice - item.price
        } else {
            return 0.0
        }
    }
    
    private func calculateSavings(for item: ExportReceiptItem) -> Double {
        if item.isDiscount {
            return abs(item.price)
        } else if let originalPrice = item.originalPrice, originalPrice > item.price {
            return originalPrice - item.price
        } else {
            return 0.0
        }
    }

    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            exportProgress = progress
        }
    }
}
