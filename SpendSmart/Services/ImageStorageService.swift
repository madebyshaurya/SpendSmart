//
//  ImageStorageService.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-15.
//  Updated for Backend API Integration on 2025-07-29.
//

import Foundation
import UIKit

/// A service for storing images through the SpendSmart backend API
class ImageStorageService {
    static let shared = ImageStorageService()

    // Storage providers
    enum Provider: String {
        case imgBB = "ImgBB"
        case local = "Local Storage"
    }

    // Backend API service for making requests
    private let backendAPI = BackendAPIService.shared

    private init() {}

    /// Upload an image using the backend API with local storage as fallback
    /// - Parameter image: The UIImage to upload
    /// - Returns: A URL string where the image is stored
    func uploadImage(_ image: UIImage) async -> String {
        // First, resize the image to reduce memory usage and upload time
        let resizedImage = resizeImage(image, targetSize: CGSize(width: 1000, height: 1000))

        do {
            print("Trying to upload image using backend API...")
            let response = try await backendAPI.uploadImage(resizedImage)
            print("Successfully uploaded image via backend API")
            return response.url
        } catch {
            print("Backend API upload failed: \(error.localizedDescription)")
            print("Falling back to local storage...")
            return await saveImageLocally(resizedImage)
        }
    }

    /// Upload multiple images using the backend API with local storage as fallback
    /// - Parameter images: Array of UIImages to upload
    /// - Returns: Array of URL strings where the images are stored
    func uploadImages(_ images: [UIImage]) async -> [String] {
        // Resize all images first
        let resizedImages = images.map { resizeImage($0, targetSize: CGSize(width: 1000, height: 1000)) }

        do {
            print("Trying to upload \(images.count) images using backend API...")
            let response = try await backendAPI.uploadImages(resizedImages)
            print("Successfully uploaded \(images.count) images via backend API")
            return response.images.compactMap { $0.success ? $0.url : nil }
        } catch {
            print("Backend API bulk upload failed: \(error.localizedDescription)")
            print("Falling back to individual local storage...")

            // Fall back to saving each image locally
            var urls: [String] = []
            for image in resizedImages {
                let url = await saveImageLocally(image)
                urls.append(url)
            }
            return urls
        }
    }

    // MARK: - Helper Methods

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
