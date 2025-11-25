//
//  ReceiptValidationService.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-17.
//

import Foundation
import UIKit
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
        // Use the new single receipt processing endpoint
        do {
            let result = try await aiService.processReceipt(image: image)
            
            return (result.isValid, result.message ?? "Receipt validation completed")
            
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
}
