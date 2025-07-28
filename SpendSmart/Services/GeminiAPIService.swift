//
//  AIService.swift (formerly GeminiAPIService.swift)
//  SpendSmart
//
//  Created by SpendSmart Team on 2025-01-06.
//

import Foundation
import UIKit
import GoogleGenerativeAI
import OpenAI

/// A unified service for handling AI API calls with support for both Gemini and OpenAI
class AIService {
    static let shared = AIService()

    // API keys for Gemini
    private let geminiAPIKeys = [
        geminiAPIKey,   // Primary API key
        geminiAPIKey2   // Secondary API key
    ]
    private var currentGeminiKeyIndex = 0

    // OpenAI client
    private lazy var openAIClient: OpenAI = {
        return OpenAI(apiToken: openAIAPIKey)
    }()

    // Track failures
    private var lastGeminiFailure: Date?
    private var lastOpenAIFailure: Date?
    private let failureTimeout: TimeInterval = 300 // 5 minutes before retrying after failure

    private init() {}
    
    /// Generate content using the configured AI service (OpenAI or Gemini)
    /// - Parameters:
    ///   - prompt: The text prompt
    ///   - image: Optional image to include
    ///   - systemInstruction: System instruction for the model
    ///   - config: Generation configuration (only used for Gemini)
    /// - Returns: AI response wrapped in a unified format
    func generateContent(
        prompt: String,
        image: UIImage? = nil,
        systemInstruction: String? = nil,
        config: GenerationConfig? = nil
    ) async throws -> AIResponse {

        if useOpenAI {
            return try await generateContentWithOpenAI(
                prompt: prompt,
                image: image,
                systemInstruction: systemInstruction
            )
        } else {
            let geminiResponse = try await generateContentWithGemini(
                prompt: prompt,
                image: image,
                systemInstruction: systemInstruction,
                config: config
            )
            return AIResponse(text: geminiResponse.text)
        }
    }

    // MARK: - OpenAI Implementation

    /// Generate content using OpenAI GPT-4o Mini
    /// Note: Currently supports text-only. Vision support can be added once API structure is confirmed.
    private func generateContentWithOpenAI(
        prompt: String,
        image: UIImage? = nil,
        systemInstruction: String? = nil
    ) async throws -> AIResponse {

        // Check if we should retry OpenAI based on previous failures
        if !shouldRetryOpenAI() {
            throw AIServiceError.recentFailure
        }

        do {
            // Build messages array
            var messages: [ChatQuery.ChatCompletionMessageParam] = []

            // Add system instruction if provided
            if let systemInstruction = systemInstruction {
                messages.append(.system(.init(content: systemInstruction)))
            }

            // Handle image + text or text-only requests with proper vision API
            if let image = image {
                // Convert UIImage to base64 for OpenAI Vision API
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw AIServiceError.imageProcessingFailed
                }
                let base64Image = imageData.base64EncodedString()
                let dataURL = "data:image/jpeg;base64,\(base64Image)"

                // Enhanced prompt for actual vision analysis
                let visionPrompt = """
                \(prompt)

                IMPORTANT: Analyze the provided receipt image and respond with ONLY valid JSON, no additional text or explanations.

                For receipt validation, respond with this exact JSON structure:
                {
                    "isValid": true,
                    "confidence": 0.9,
                    "message": "Receipt validated from image analysis",
                    "missingElements": []
                }

                For receipt data extraction, respond with valid JSON containing store name, items, prices, and totals based on the actual image content.
                Do not include markdown formatting or code blocks - just pure JSON.

                CRITICAL: Return ONLY ONE complete JSON object. Do not return multiple JSON objects or any additional text.
                """

                // Create user message with vision content using the correct MacPaw/OpenAI SDK structure
                // Use the same pattern as the working text-only message but with vision content
                let userMessage = ChatQuery.ChatCompletionMessageParam.user(
                    .init(content: .vision([
                        .init(chatCompletionContentPartTextParam: .init(text: visionPrompt)),
                        .init(chatCompletionContentPartImageParam: .init(imageUrl: .init(url: dataURL, detail: .auto)))
                    ]))
                )

                messages.append(userMessage)
                print("🔑 Using OpenAI Vision API with actual image analysis")
                print("📸 Image processed: \(imageData.count) bytes")
            } else {
                // For text-only requests, ensure JSON response
                let textPrompt = """
                \(prompt)

                IMPORTANT: Respond with ONLY valid JSON, no additional text, explanations, or markdown formatting.
                """
                messages.append(.user(.init(content: .string(textPrompt))))
            }

            // Create the chat query
            let query = ChatQuery(
                messages: messages,
                model: .gpt4_o_mini,
                maxTokens: 4096,
                temperature: 0.7
            )

            print("🔑 Trying OpenAI API with GPT-4o Mini")
            let result = try await openAIClient.chats(query: query)

            // Extract content from response
            guard let choice = result.choices.first,
                  let content = choice.message.content else {
                throw AIServiceError.noResponseContent
            }

            // Calculate and display cost information
            if let usage = result.usage {
                let inputTokens = usage.promptTokens
                let outputTokens = usage.completionTokens
                let totalTokens = usage.totalTokens

                // GPT-4o Mini pricing (as of 2024):
                // Text: $0.15/1M input tokens, $0.60/1M output tokens
                // Vision: $0.15/1M input tokens, $0.60/1M output tokens (same as text)
                let inputCost = Double(inputTokens) * 0.15 / 1_000_000
                let outputCost = Double(outputTokens) * 0.60 / 1_000_000
                let totalCost = inputCost + outputCost

                let hasImage = image != nil
                let apiType = hasImage ? "Vision" : "Text"

                print("✅ OpenAI API call successful (\(apiType) mode)")
                print("💰 Cost: $\(String(format: "%.6f", totalCost)) (Input: \(inputTokens) tokens, Output: \(outputTokens) tokens, Total: \(totalTokens) tokens)")

                if hasImage {
                    print("📸 Image processed: Receipt image analyzed by GPT-4o Mini Vision")
                }
            } else {
                print("✅ OpenAI API call successful")
            }

            // Clear any previous failure tracking
            lastOpenAIFailure = nil

            // Clean up the response to ensure it's valid JSON
            let cleanedContent = cleanJSONResponse(content)

            return AIResponse(text: cleanedContent)

        } catch {
            print("❌ OpenAI API call failed: \(error)")

            // Track the failure
            trackOpenAIFailure()

            throw error
        }
    }

    // MARK: - Gemini Implementation

    /// Generate content using Gemini API with fallback
    private func generateContentWithGemini(
        prompt: String,
        image: UIImage? = nil,
        systemInstruction: String? = nil,
        config: GenerationConfig? = nil
    ) async throws -> GenerateContentResponse {

        // Check if we should retry Gemini based on previous failures
        if !shouldRetryGemini() {
            throw AIServiceError.recentFailure
        }

        var lastError: Error?
        
        // Try each API key until one works or all fail
        for keyAttempt in 0..<geminiAPIKeys.count {
            // Rotate through available API keys
            let keyIndex = (currentGeminiKeyIndex + keyAttempt) % geminiAPIKeys.count
            let apiKey = geminiAPIKeys[keyIndex]
            
            print("🔑 Trying Gemini API with key \(keyIndex + 1) of \(geminiAPIKeys.count)")
            
            do {
                let model: GenerativeModel
                if let systemInstruction = systemInstruction {
                    model = GenerativeModel(
                        name: "gemini-2.0-flash",
                        apiKey: apiKey,
                        generationConfig: config,
                        systemInstruction: systemInstruction
                    )
                } else {
                    model = GenerativeModel(
                        name: "gemini-2.0-flash",
                        apiKey: apiKey,
                        generationConfig: config
                    )
                }
                
                let response: GenerateContentResponse
                if let image = image {
                    response = try await model.generateContent(prompt, image)
                } else {
                    response = try await model.generateContent(prompt)
                }
                
                print("✅ Gemini API call successful with key \(keyIndex + 1)")

                // Update the current key index to start with this successful key next time
                currentGeminiKeyIndex = keyIndex

                // Clear any previous failure tracking
                lastGeminiFailure = nil

                return response
                
            } catch {
                print("❌ Gemini API error with key \(keyIndex + 1): \(error)")
                lastError = error

                // Check if this is a specific GoogleGenerativeAI error
                let errorString = error.localizedDescription.lowercased()
                if errorString.contains("503") || errorString.contains("overloaded") || errorString.contains("unavailable") {
                    print("🔄 Service overloaded/rate limited, retrying with alternative...")
                    continue
                } else if errorString.contains("429") || errorString.contains("rate limit") {
                    print("🔄 Rate limited, retrying with alternative...")
                    continue
                } else if errorString.contains("401") || errorString.contains("403") || errorString.contains("unauthorized") {
                    print("🔑 Authentication error, retrying...")
                    continue
                } else {
                    // For other errors, still try the next key
                    print("⚠️ Service error, retrying...")
                    continue
                }
            }
        }

        // If we get here, all alternatives failed
        print("🚫 All service alternatives failed")

        // Rotate to the next key for next time
        currentGeminiKeyIndex = (currentGeminiKeyIndex + 1) % geminiAPIKeys.count

        // Track the failure
        trackGeminiFailure()

        // Throw the last error we encountered
        throw lastError ?? AIServiceError.allKeysFailed
    }

    // MARK: - Helper Methods

    /// Track Gemini failure
    func trackGeminiFailure() {
        lastGeminiFailure = Date()
    }

    /// Track OpenAI failure
    func trackOpenAIFailure() {
        lastOpenAIFailure = Date()
    }

    /// Check if Gemini should be retried
    func shouldRetryGemini() -> Bool {
        guard let lastFailure = lastGeminiFailure else {
            return true // No previous failure, so retry
        }

        let now = Date()
        return now.timeIntervalSince(lastFailure) > failureTimeout
    }

    /// Check if OpenAI should be retried
    func shouldRetryOpenAI() -> Bool {
        guard let lastFailure = lastOpenAIFailure else {
            return true // No previous failure, so retry
        }

        let now = Date()
        return now.timeIntervalSince(lastFailure) > failureTimeout
    }

    /// Clean JSON response to ensure it's valid JSON
    private func cleanJSONResponse(_ content: String) -> String {
        // Remove any markdown code block formatting
        var cleaned = content

        // Remove ```json and ``` markers if present
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")

        // Trim whitespace and newlines
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle multiple JSON objects in response - extract the largest/most complete one
        if cleaned.contains("}{") {
            // Split by }{ pattern to find separate JSON objects
            let jsonObjects = cleaned.components(separatedBy: "}{")

            // Reconstruct complete JSON objects
            var completeObjects: [String] = []
            for (index, part) in jsonObjects.enumerated() {
                var jsonObject = part
                if index > 0 && !jsonObject.hasPrefix("{") {
                    jsonObject = "{" + jsonObject
                }
                if index < jsonObjects.count - 1 && !jsonObject.hasSuffix("}") {
                    jsonObject = jsonObject + "}"
                }
                completeObjects.append(jsonObject.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            // Find the largest JSON object (likely the most complete response)
            if let largestObject = completeObjects.max(by: { $0.count < $1.count }) {
                cleaned = largestObject
                print("🔧 Multiple JSON objects detected, using largest: \(largestObject.prefix(100))...")
            }
        }

        // If the content doesn't start with { or [, try to find the JSON part
        if !cleaned.hasPrefix("{") && !cleaned.hasPrefix("[") {
            // Look for the first occurrence of { or [
            if let jsonStart = cleaned.firstIndex(where: { $0 == "{" || $0 == "[" }) {
                cleaned = String(cleaned[jsonStart...])
            }
        }

        // Extract only the first complete JSON object if there are multiple
        if cleaned.hasPrefix("{") {
            var braceCount = 0
            var endIndex = cleaned.startIndex

            for (index, char) in cleaned.enumerated() {
                let currentIndex = cleaned.index(cleaned.startIndex, offsetBy: index)
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        endIndex = cleaned.index(after: currentIndex)
                        break
                    }
                }
            }

            if endIndex > cleaned.startIndex {
                cleaned = String(cleaned[..<endIndex])
            }
        }

        // If still no valid JSON start, return a default error response
        if !cleaned.hasPrefix("{") && !cleaned.hasPrefix("[") {
            print("⚠️ OpenAI returned non-JSON response: \(content)")
            // Return a default JSON response for validation
            return """
            {
                "isValid": false,
                "confidence": 0.0,
                "message": "Unable to process response from AI service",
                "missingElements": ["Invalid response format"]
            }
            """
        }

        return cleaned
    }
}

// MARK: - Unified Response Model

/// Unified response structure for both AI services
struct AIResponse {
    let text: String?

    init(text: String?) {
        self.text = text
    }
}

// MARK: - Custom Errors

enum AIServiceError: LocalizedError {
    case recentFailure
    case allKeysFailed
    case imageProcessingFailed
    case noResponseContent

    var errorDescription: String? {
        switch self {
        case .recentFailure:
            return "AI service recently failed, waiting before retry"
        case .allKeysFailed:
            return "All AI service keys failed"
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
            return "Gemini API recently failed, waiting before retry"
        case .allKeysFailed:
            return "All Gemini API keys failed"
        }
    }
}
