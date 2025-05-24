//
//  ImageStorageService.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-15.
//

import Foundation
import UIKit

/// A service for storing images using multiple providers with fallback options
class ImageStorageService {
    static let shared = ImageStorageService()

    // Storage providers
    enum Provider: String {
        case imgBB = "ImgBB"
        case local = "Local Storage"
    }

    // API keys for ImgBB
    private let imgBBAPIKeys = [
        imgBBAPIKey,   // Primary API key
        imgBBAPIKey2,  // Secondary API key
        imgBBAPIKey3   // Tertiary API key
    ]   
    private var currentImgBBKeyIndex = 0

    // Track ImgBB failures
    private var lastImgBBFailure: Date?
    private let failureTimeout: TimeInterval = 300 // 5 minutes before retrying ImgBB after failure

    private init() {
        // Nothing to initialize - we'll always use ImgBB with local storage as fallback
    }

    /// Upload an image using ImgBB with local storage as fallback
    /// - Parameter image: The UIImage to upload
    /// - Returns: A URL string where the image is stored
    func uploadImage(_ image: UIImage) async -> String {
        // First, resize the image to reduce memory usage and upload time
        let resizedImage = resizeImage(image, targetSize: CGSize(width: 1000, height: 1000))

        // Further compress the image to reduce size
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            print("Failed to convert image to data")
            return await saveImageLocally(image)
        }

        // Try to upload to ImgBB
        print("Trying to upload image using ImgBB...")
        if let url = await uploadToImgBB(imageData) {
            print("Successfully uploaded image to ImgBB")
            return url
        }

        // If ImgBB fails, save locally as fallback
        print("ImgBB upload failed, saving image locally...")
        return await saveImageLocally(image)
    }

    // MARK: - Helper Methods

    /// Track ImgBB failure
    private func trackImgBBFailure() {
        lastImgBBFailure = Date()
    }

    /// Check if ImgBB should be retried
    private func shouldRetryImgBB() -> Bool {
        guard let lastFailure = lastImgBBFailure else {
            return true // No previous failure, so retry
        }

        let now = Date()
        return now.timeIntervalSince(lastFailure) > failureTimeout
    }

    // MARK: - Provider Implementations

    /// Upload an image to ImgBB
    /// - Parameter imageData: The image data to upload
    /// - Returns: URL string if successful, nil otherwise
    private func uploadToImgBB(_ imageData: Data) async -> String? {
        // Check if we should retry ImgBB based on previous failures
        if !shouldRetryImgBB() {
            print("Skipping ImgBB upload due to recent failure")
            return nil
        }

        // Check if image size is too large (imgBB has a 32MB limit, but we'll use 10MB to be safe)
        if imageData.count > 10 * 1024 * 1024 {
            print("Image too large for ImgBB (\(imageData.count / 1024 / 1024)MB)")
            return nil
        }

        // Try each API key until one works or all fail
        for keyAttempt in 0..<imgBBAPIKeys.count {
            // Rotate through available API keys
            let keyIndex = (currentImgBBKeyIndex + keyAttempt) % imgBBAPIKeys.count
            let apiKey = imgBBAPIKeys[keyIndex]

            print("Trying ImgBB upload with API key \(keyIndex + 1) of \(imgBBAPIKeys.count)")

            guard let url = URL(string: "https://api.imgbb.com/1/upload") else {
                print("Invalid URL for ImgBB upload")
                continue
            }

            // Create multipart form data
            let boundary = UUID().uuidString

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            // Increase timeout to handle larger images
            request.timeoutInterval = 60

            var body = Data()

            // Add API key
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(apiKey)\r\n".data(using: .utf8)!)

            // Add image data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)

            // Add expiration parameter (30 days)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"expiration\"\r\n\r\n".data(using: .utf8)!)
            body.append("2592000\r\n".data(using: .utf8)!) // 30 days in seconds

            // Close the boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            // Implement retry logic
            let maxRetries = 2
            var retryCount = 0
            var lastError: Error?

            while retryCount <= maxRetries {
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("Error: Not an HTTP response from ImgBB")
                        retryCount += 1
                        if retryCount > maxRetries {
                            break
                        }
                        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * retryCount)) // Exponential backoff
                        continue
                    }

                    // Log the response status code for debugging
                    print("ImgBB API response status: \(httpResponse.statusCode) with key \(keyIndex + 1)")

                    // Check for rate limiting or server errors
                    if httpResponse.statusCode == 429 {
                        print("ImgBB rate limit exceeded for key \(keyIndex + 1)")
                        // Don't retry on rate limit, try next key
                        break
                    } else if httpResponse.statusCode >= 500 {
                        print("ImgBB server error: \(httpResponse.statusCode)")
                        retryCount += 1
                        if retryCount > maxRetries {
                            break
                        }
                        try await Task.sleep(nanoseconds: UInt64(2_000_000_000 * retryCount)) // Longer wait for server errors
                        continue
                    } else if httpResponse.statusCode != 200 {
                        // Try to parse error message
                        if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorMsg = errorJson["error"] as? [String: Any],
                           let message = errorMsg["message"] as? String {
                            print("ImgBB API error with key \(keyIndex + 1): \(message)")
                        } else {
                            print("ImgBB API error with key \(keyIndex + 1), status code: \(httpResponse.statusCode)")
                        }
                        retryCount += 1
                        if retryCount > maxRetries {
                            break
                        }
                        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * retryCount))
                        continue
                    }

                    // Parse the successful response
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let success = json["success"] as? Bool,
                           success,
                           let responseData = json["data"] as? [String: Any] {

                            // Prefer the direct URL which doesn't have the ImgBB page wrapper
                            if let directUrl = responseData["image"] as? [String: Any],
                               let url = directUrl["url"] as? String {
                                print("Image uploaded successfully to ImgBB with key \(keyIndex + 1): \(url)")

                                // Update the current key index to start with this successful key next time
                                currentImgBBKeyIndex = keyIndex

                                return url
                            } else if let url = responseData["url"] as? String {
                                print("Image uploaded successfully to ImgBB with key \(keyIndex + 1): \(url)")

                                // Update the current key index to start with this successful key next time
                                currentImgBBKeyIndex = keyIndex

                                return url
                            }
                        }

                        print("Failed to parse ImgBB response with key \(keyIndex + 1): \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                        retryCount += 1
                        if retryCount > maxRetries {
                            break
                        }
                        continue
                    } catch {
                        print("JSON parsing error for ImgBB with key \(keyIndex + 1): \(error)")
                        lastError = error
                        retryCount += 1
                        if retryCount > maxRetries {
                            break
                        }
                        continue
                    }
                } catch {
                    print("ImgBB upload error with key \(keyIndex + 1): \(error)")
                    lastError = error
                    retryCount += 1
                    if retryCount > maxRetries {
                        break
                    }
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * retryCount))
                }
            }

            // If we get here, this key failed - try the next one
            if let error = lastError {
                print("All ImgBB upload attempts with key \(keyIndex + 1) failed with error: \(error)")
            } else {
                print("All ImgBB upload attempts with key \(keyIndex + 1) failed")
            }
        }

        // If we get here, all keys failed
        print("All ImgBB API keys failed to upload the image")

        // Rotate to the next key for next time
        currentImgBBKeyIndex = (currentImgBBKeyIndex + 1) % imgBBAPIKeys.count

        // Track the failure
        trackImgBBFailure()

        return nil
    }



    /// Save an image to local storage
    /// - Parameter image: The UIImage to save
    /// - Returns: A local URL string
    private func saveImageLocally(_ image: UIImage) async -> String {
        // Create a unique filename based on timestamp and random number
        let timestamp = Date().timeIntervalSince1970
        let randomNum = Int.random(in: 10000...99999)
        let filename = "receipt_\(Int(timestamp))_\(randomNum).jpg"

        // Get the documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to access documents directory")
            return "placeholder_url"
        }

        // Create a URL for the file
        let fileURL = documentsDirectory.appendingPathComponent(filename)

        // Compress the image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("Failed to convert image to data for local storage")
            return "placeholder_url"
        }

        do {
            // Write the image data to the file
            try imageData.write(to: fileURL)

            // Create a URL scheme that can be used within the app
            // Format: "local://receipt_123456789_12345.jpg"
            let localURLString = "local://\(filename)"
            print("Image saved locally: \(localURLString)")

            return localURLString
        } catch {
            print("Error saving image locally: \(error)")
            return "placeholder_url"
        }
    }

    /// Helper function to resize images before upload
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Use the smaller ratio to ensure the image fits within the target size
        let scaleFactor = min(widthRatio, heightRatio)

        // If the image is already smaller than the target size, return it as is
        if scaleFactor > 1 {
            return image
        }

        let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let renderer = UIGraphicsImageRenderer(size: scaledSize)

        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }

        return scaledImage
    }
}
