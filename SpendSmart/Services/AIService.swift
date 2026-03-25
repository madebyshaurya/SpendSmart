import Foundation
import UIKit

class AIService {
    static let shared = AIService()
    private let backendAPI = BackendAPIService.shared

    private init() {}

    struct GenerationConfig {
        let temperature: Float?
        let topP: Float?
        let topK: Int?
        let maxOutputTokens: Int?
        let responseMIMEType: String?

        init(temperature: Float? = nil, topP: Float? = nil, topK: Int? = nil, maxOutputTokens: Int? = nil, responseMIMEType: String? = nil) {
            self.temperature = temperature
            self.topP = topP
            self.topK = topK
            self.maxOutputTokens = maxOutputTokens
            self.responseMIMEType = responseMIMEType
        }
    }

    func generateContent(prompt: String, image: UIImage? = nil, systemInstruction: String? = nil, config: GenerationConfig? = nil) async throws -> AIResponse {
        var configDict: [String: Any]?
        if let c = config {
            configDict = ["temperature": c.temperature ?? 0.7, "topK": c.topK ?? 40, "topP": c.topP ?? 0.95, "maxOutputTokens": c.maxOutputTokens ?? 4096]
        }
        let text = try await backendAPI.generateAIContent(prompt: prompt, image: image, systemInstruction: systemInstruction, config: configDict)
        return AIResponse(text: text)
    }
    



    
    func processReceipt(images: [UIImage]) async throws -> ReceiptProcessingResult {
        let response = try await backendAPI.processReceipt(images: images)
        return ReceiptProcessingResult(
            isValid: response.isValid,
            message: response.message,
            storeName: response.store_name,
            purchaseDate: response.purchase_date,
            totalAmount: response.total_amount,
            currency: response.currency,
            items: response.items?.map { ReceiptProcessingItem(name: $0.name, price: $0.price, category: $0.category, isDiscount: $0.isDiscount, originalPrice: $0.originalPrice, discountDescription: nil) } ?? [],
            totalTax: response.total_tax,
            paymentMethod: response.payment_method,
            storeAddress: response.store_address,
            receiptName: response.receipt_name,
            logoSearchTerm: response.logo_search_term
        )
    }
}



struct ReceiptProcessingResult {
    let isValid: Bool
    let message: String?
    let storeName: String?
    let purchaseDate: String?
    let totalAmount: Double?
    let currency: String?
    let items: [ReceiptProcessingItem]
    let totalTax: Double?
    let paymentMethod: String?
    let storeAddress: String?
    let receiptName: String?
    let logoSearchTerm: String?
}

struct ReceiptProcessingItem: Codable {
    let name: String
    let price: Double
    let category: String
    let isDiscount: Bool
    let originalPrice: Double?
    let discountDescription: String?
}

struct AIResponse {
    let text: String?
}

enum AIServiceError: LocalizedError {
    case authenticationFailed, rateLimited, serverError, requestFailed(String), imageProcessingFailed, noResponseContent
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed: return "Authentication failed"
        case .rateLimited: return "Rate limited"
        case .serverError: return "Server error"
        case .requestFailed(let m): return m
        default: return "AI service error"
        }
    }
}


