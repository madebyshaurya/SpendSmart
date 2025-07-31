//
//  AIService.swift (formerly GeminiAPIService.swift)
//  SpendSmart
//
//  Created by SpendSmart Team on 2025-01-06.
//  Updated for Backend API Integration on 2025-07-29.
//

import Foundation
import UIKit

/// A unified service for handling AI API calls through the SpendSmart backend
class AIService {
    static let shared = AIService()

    // Backend API service for making requests
    private let backendAPI = BackendAPIService.shared

    private init() {}

    /// Generation configuration for AI requests
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

    /// Generate content using AI through the backend API
    /// - Parameters:
    ///   - prompt: The text prompt
    ///   - image: Optional image to include
    ///   - systemInstruction: System instruction for the model
    ///   - config: Generation configuration (passed to backend)
    /// - Returns: AI response wrapped in a unified format
    func generateContent(
        prompt: String,
        image: UIImage? = nil,
        systemInstruction: String? = nil,
        config: GenerationConfig? = nil
    ) async throws -> AIResponse {

        do {
            // Convert GenerationConfig to dictionary if provided
            var configDict: [String: Any]?
            if let config = config {
                configDict = [
                    "temperature": config.temperature ?? 0.7,
                    "topK": config.topK ?? 40,
                    "topP": config.topP ?? 0.95,
                    "maxOutputTokens": config.maxOutputTokens ?? 4096
                ]
            }

            // Make request to backend API
            let response = try await backendAPI.generateAIContent(
                prompt: prompt,
                image: image,
                systemInstruction: systemInstruction,
                config: configDict
            )

            return AIResponse(text: response.data.response)

        } catch let error as BackendAPIError {
            // Convert backend API errors to AIService errors
            switch error {
            case .unauthorized:
                throw AIServiceError.authenticationFailed
            case .rateLimited:
                throw AIServiceError.rateLimited
            case .serverError:
                throw AIServiceError.serverError
            default:
                throw AIServiceError.requestFailed(error.localizedDescription)
            }
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }

    /// Validate a receipt image using AI through the backend API
    /// - Parameter image: The receipt image to validate
    /// - Returns: Receipt validation response
    func validateReceipt(image: UIImage) async throws -> ReceiptValidationResult {
        do {
            let response = try await backendAPI.validateReceipt(image: image)

            return ReceiptValidationResult(
                isValid: response.data.isValid,
                confidence: response.data.confidence,
                message: response.data.message,
                missingElements: response.data.missingElements
            )

        } catch let error as BackendAPIError {
            // Convert backend API errors to AIService errors
            switch error {
            case .unauthorized:
                throw AIServiceError.authenticationFailed
            case .rateLimited:
                throw AIServiceError.rateLimited
            case .serverError:
                throw AIServiceError.serverError
            default:
                throw AIServiceError.requestFailed(error.localizedDescription)
            }
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }
} // End of AIService class

// MARK: - Supporting Models

/// Result of receipt validation through backend API
struct ReceiptValidationResult {
    let isValid: Bool
    let confidence: Double
    let message: String
    let missingElements: [String]
}

// MARK: - Unified Response Model

/// Unified response structure for AI services
struct AIResponse {
    let text: String?

    init(text: String?) {
        self.text = text
    }
}

// MARK: - Custom Errors

enum AIServiceError: LocalizedError {
    case authenticationFailed
    case rateLimited
    case serverError
    case requestFailed(String)
    case imageProcessingFailed
    case noResponseContent

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed with backend API"
        case .rateLimited:
            return "Rate limited by backend API"
        case .serverError:
            return "Backend server error"
        case .requestFailed(let message):
            return "Request failed: \(message)"
        case .imageProcessingFailed:
            return "Failed to process image for AI analysis"
        case .noResponseContent:
            return "AI service returned no content"
        }
    }
}



// MARK: - Legacy Support

/// Legacy alias for backward compatibility
typealias GeminiAPIService = AIService

/// Legacy error enum for backward compatibility
enum GeminiAPIError: LocalizedError {
    case recentFailure
    case allKeysFailed

    var errorDescription: String? {
        switch self {
        case .recentFailure:
            return "AI service recently failed, waiting before retry"
        case .allKeysFailed:
            return "All AI service keys failed"
        }
    }
}


