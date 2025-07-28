//
//  ReceiptValidationService.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-17.
//

import Foundation
import UIKit
import GoogleGenerativeAI
import Vision

class ReceiptValidationService {
    static let shared = ReceiptValidationService()

    // Use the shared AI service (supports both Gemini and OpenAI)
    private let aiService = AIService.shared

    private init() {}

    /// Validates if an image contains a valid receipt
    /// - Parameter image: The image to validate
    /// - Returns: A tuple containing a boolean indicating if the image is a valid receipt and a message
    func validateReceiptImage(_ image: UIImage) async -> (isValid: Bool, message: String) {
        // First try the AI-based validation
        do {
            let systemPrompt = """
            You are a receipt validation system. Your task is to determine if an image contains a valid receipt.

            A valid receipt should have most of these elements:
            1. Store/merchant name
            2. Date of purchase
            3. List of items purchased with prices
            4. Total amount
            5. Payment information

            Respond with a JSON object containing:
            1. "isValid": boolean (true if it's a valid receipt, false otherwise)
            2. "confidence": number between 0 and 1 (how confident you are in your assessment)
            3. "message": string (explanation of why it is or isn't a valid receipt)
            4. "missingElements": array of strings (what elements are missing if it's not valid)

            Be strict in your validation. If the image is blurry, doesn't contain clear text, or is not a receipt at all (e.g., a random photo, screenshot, etc.), mark it as invalid.
            """

            let config = GenerationConfig(
                temperature: 0.2,
                topP: 0.95,
                topK: 40,
                maxOutputTokens: 2048,
                responseMIMEType: "application/json"
            )

            let prompt = "Analyze this image and determine if it contains a valid receipt. Respond with the JSON format specified in your instructions."
            let response = try await aiService.generateContent(
                prompt: prompt,
                image: image,
                systemInstruction: systemPrompt,
                config: config
            )

            if let jsonString = response.text {
                return parseValidationResponse(jsonString)
            }
        } catch {
            print("Error validating receipt with AI: \(error)")
            // Fall through to the fallback method
        }

        // Fallback to basic image validation if AI validation fails
        return await fallbackValidateReceiptImage(image)
    }

    /// Fallback method to validate receipt images using basic image processing
    private func fallbackValidateReceiptImage(_ image: UIImage) async -> (isValid: Bool, message: String) {
        // Check if the image has a reasonable aspect ratio for a receipt
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio > 2.0 || aspectRatio < 0.3 {
            return (false, "The image doesn't have the typical dimensions of a receipt. Please capture a clearer photo of your receipt.")
        }

        // Check if the image has enough text content to be a receipt
        let textDetectionResult = await detectTextInImage(image)
        if !textDetectionResult.hasText {
            return (false, "No text was detected in the image. Please capture a clearer photo of your receipt.")
        }

        // If we have a reasonable amount of text and the image has receipt-like dimensions, consider it valid
        if textDetectionResult.textBlocks > 5 {
            return (true, "Receipt validated successfully")
        } else {
            return (false, "The image doesn't appear to contain enough text to be a receipt. Please capture a clearer photo showing all receipt details.")
        }
    }

    /// Detects text in an image using Vision framework
    private func detectTextInImage(_ image: UIImage) async -> (hasText: Bool, textBlocks: Int) {
        return await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: (false, 0))
                return
            }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: (false, 0))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    continuation.resume(returning: (false, 0))
                    return
                }

                // Count text blocks with reasonable confidence
                let textBlocks = observations.filter { $0.confidence > 0.5 }.count
                continuation.resume(returning: (true, textBlocks))
            }

            // Configure the text recognition request
            request.recognitionLevel = .accurate

            do {
                try requestHandler.perform([request])
            } catch {
                print("Error detecting text: \(error)")
                continuation.resume(returning: (false, 0))
            }
        }
    }

    /// Validates multiple receipt images
    /// - Parameter images: Array of images to validate
    /// - Returns: A tuple containing a boolean indicating if all images are valid receipts and a message
    func validateReceiptImages(_ images: [UIImage]) async -> (allValid: Bool, message: String) {
        guard !images.isEmpty else {
            return (false, "No images provided")
        }

        // For efficiency, we'll only validate the first image in detail
        // This is a simplification - in a production app, you might want to validate all images
        let (isValid, message) = await validateReceiptImage(images[0])

        return (isValid, message)
    }

    private func parseValidationResponse(_ jsonString: String) -> (isValid: Bool, message: String) {
        guard let data = jsonString.data(using: .utf8) else {
            return (false, "Failed to process validation response")
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isValid = json["isValid"] as? Bool,
               let message = json["message"] as? String {
                return (isValid, message)
            } else {
                return (false, "Invalid validation response format")
            }
        } catch {
            print("Error parsing validation response: \(error)")
            return (false, "Error parsing validation response")
        }
    }
}
