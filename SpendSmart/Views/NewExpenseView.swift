//
//  NewExpenseView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-19.
//

import SwiftUI
import PhotosUI
import AVFoundation
import Vision
import GoogleGenerativeAI
import Supabase
// Import the receipt validation service
import Foundation
// Import the image storage service
import UIKit

struct NewExpenseView: View {
    var onReceiptAdded: (Receipt) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showMultiCamera = false
    @State private var selectedImage: UIImage?
    @State private var capturedImages: [UIImage] = []
    @State private var isAddingExpense = false // For loading indicator
    @State private var progressStep: ProcessingStep?
    @State private var rotationDegrees: Double = 0
    @State private var showImageCarousel = false
    @State private var currentImageIndex = 0
    @State private var showInvalidReceiptAlert = false
    @State private var invalidReceiptMessage = ""
    @EnvironmentObject var appState: AppState

    // Use the shared AI service (supports both Gemini and OpenAI)
    private let aiService = AIService.shared

    // Toast manager for error notifications
    @StateObject private var toastManager = ToastManager()

    enum ProcessingStep: String, CaseIterable {
        case validatingReceipt = "Validating Receipt"
        case extractingText = "Extracting Text"
        case analyzingReceipt = "Analyzing Receipt"
        case savingToDatabase = "Saving to Database"
        case complete = "Complete!"
        case error = "Error Processing Receipt"
        case invalidReceipt = "Invalid Receipt"

        var systemImage: String {
            switch self {
            case .validatingReceipt:
                return "checkmark.shield"
            case .extractingText:
                return "text.viewfinder"
            case .analyzingReceipt:
                return "doc.text.magnifyingglass"
            case .savingToDatabase:
                return "arrow.down.doc"
            case .complete:
                return "checkmark.circle"
            case .error, .invalidReceipt:
                return "exclamationmark.triangle"
            }
        }

        var description: String {
            switch self {
            case .validatingReceipt:
                return "Validating receipt..."
            case .extractingText:
                return "Reading receipt details..."
            case .analyzingReceipt:
                return "Analyzing receipt data..."
            case .savingToDatabase:
                return "Adding to your expenses..."
            case .complete:
                return "Receipt processed successfully!"
            case .error:
                return "Sorry, couldn't process this receipt"
            case .invalidReceipt:
                return "This doesn't appear to be a valid receipt"
            }
        }

        var color: Color {
            switch self {
            case .validatingReceipt:
                return .cyan
            case .extractingText:
                return .blue
            case .analyzingReceipt:
                return .purple
            case .savingToDatabase:
                return .green
            case .complete:
                return .green
            case .error, .invalidReceipt:
                return .red
            }
        }
    }


    var body: some View {
        NavigationView {
            VStack {
                if !capturedImages.isEmpty || selectedImage != nil {
                    // Image carousel or single image display
                    ZStack {
                        if !capturedImages.isEmpty {
                            // Multi-image carousel
                            TabView(selection: $currentImageIndex) {
                                ForEach(0..<capturedImages.count, id: \.self) { index in
                                    Image(uiImage: capturedImages[index])
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(12)
                                        .padding()
                                        .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                            .frame(height: 300)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(colorScheme == .dark ? Color(hex: "282828") : Color(hex: "F0F0F0"))
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            )
                            .overlay(
                                // Image counter pill
                                Text("\(currentImageIndex + 1)/\(capturedImages.count)")
                                    .font(.instrumentSans(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.6))
                                    )
                                    .padding(8),
                                alignment: .topTrailing
                            )
                        } else if let image = selectedImage {
                            // Single image display
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(colorScheme == .dark ? Color(hex: "282828") : Color(hex: "F0F0F0"))
                                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                )
                        }
                    }
                    .padding()
                    .transition(.opacity)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "receipt")
                            .font(.system(size: 64))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "DDDDDD") : Color(hex: "555555"))

                        Text("Select a Receipt Image")
                            .font(.instrumentSans(size: 28, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Text("Take a photo of your receipt or select one from your gallery")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "AAAAAA") : Color(hex: "666666"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 40)
                    .transition(.opacity)
                }

                if isAddingExpense, let step = progressStep {
                    ZStack {
                        VStack(spacing: 25) {
                            // Progress Circle
                            ZStack {
                                // Track Circle
                                Circle()
                                    .stroke(lineWidth: 15)
                                    .opacity(0.1)
                                    .foregroundColor(step.color)

                                // Progress Circle
                                Circle()
                                    .trim(from: 0.0, to: min(CGFloat(ProcessingStep.allCases.firstIndex(of: step)! + 1) / CGFloat(ProcessingStep.allCases.count - 1), 1.0))
                                    .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                                    .foregroundColor(step.color)
                                    .rotationEffect(Angle(degrees: 270.0))
                                    .animation(.easeInOut(duration: 0.6), value: step)

                                // Rotating Trim
                                Circle()
                                    .trim(from: 0.0, to: 0.2)
                                    .stroke(style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                    .foregroundColor(step.color.opacity(0.7))
                                    .rotationEffect(Angle(degrees: rotationDegrees))
                                    .onAppear {
                                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                            rotationDegrees = 360
                                        }
                                    }

                                // Icon
                                Image(systemName: step.systemImage)
                                    .font(.system(size: 40))
                                    .foregroundColor(step.color)
                                    .transition(.scale.combined(with: .opacity))
                                    .id(step) // Force view recreation for transition
                            }
                            .frame(width: 180, height: 180)

                            // Status Text
                            VStack(spacing: 10) {
                                Text(step.rawValue)
                                    .font(.instrumentSans(size: 24, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)

                                Text(step.description)
                                    .font(.instrumentSans(size: 16))
                                    .foregroundColor(colorScheme == .dark ? Color(hex: "BBBBBB") : Color(hex: "555555"))
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity)
                                    .id(step.description) // Force view recreation for transition
                            }
                            .padding(.horizontal, 20)
                        }
                        .opacity(isAddingExpense ? 1 : 0)
                        .offset(y: isAddingExpense ? 0 : 50)
                        .animation(.easeInOut(duration: 0.3), value: isAddingExpense)
                    }
                    .transition(.opacity)
                }

                Spacer()

                if !isAddingExpense {

                    VStack(spacing: 16) {
                        // Capture options
                        HStack(spacing: 20) {
                            // Camera button (always multi-image)
                            Button {
                                showMultiCamera = true
                                // Removed first-time guide as requested
                            } label: {
                                HStack {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 18))
                                    Text("Camera")
                                        .font(.instrumentSans(size: 18, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .foregroundColor(.white)
                            }

                            // Gallery button
                            Button {
                                showImagePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 18))
                                    Text("Gallery")
                                        .font(.instrumentSans(size: 18, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.green.gradient)
                                )
                                .foregroundColor(.white)
                            }
                        }

                        // Multi-image info text
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text("Take multiple photos for long receipts")
                                .font(.instrumentSans(size: 14))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                if !capturedImages.isEmpty || selectedImage != nil {
                    Button {
                        isAddingExpense = true
                        Task {
                            do {
                                // Start with unified receipt validation and processing
                                withAnimation {
                                    progressStep = .validatingReceipt
                                }

                                // Show validating state for better UX
                                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

                                withAnimation {
                                    progressStep = .analyzingReceipt
                                }

                                // Process the receipt
                                try await Task.sleep(nanoseconds: 500_000_000)

                                var receipt: Receipt?
                                var imageURLs: [String] = []

                                if !capturedImages.isEmpty {
                                    // Process multiple images
                                    // For now, we'll use the first image for text extraction
                                    receipt = await extractDataFromImage(receiptImage: capturedImages[0])

                                    // Check if validation failed
                                    if receipt == nil {
                                        // Show invalid receipt toast
                                        await MainActor.run {
                                            toastManager.show(
                                                message: "Invalid receipt",
                                                type: .error
                                            )
                                        }

                                        try await Task.sleep(nanoseconds: 1_000_000_000)
                                        isAddingExpense = false
                                        progressStep = nil
                                        return
                                    }

                                    // Only upload images if AI processing was successful
                                    withAnimation {
                                        progressStep = .savingToDatabase
                                    }

                                    // Upload all images
                                    for (_, image) in capturedImages.enumerated() {
                                        let imageURL = await uploadImage(image)
                                        if imageURL != "placeholder_url" {
                                            imageURLs.append(imageURL)
                                        }

                                        // Update progress for each image
                                        withAnimation {
                                            rotationDegrees += 30
                                        }
                                    }

                                    // Set all image URLs
                                    receipt?.image_urls = imageURLs
                                } else if let selectedImage = selectedImage {
                                    // Process single image
                                    receipt = await extractDataFromImage(receiptImage: selectedImage)

                                    // Check if validation failed
                                    if receipt == nil {
                                        // Show invalid receipt toast
                                        await MainActor.run {
                                            toastManager.show(
                                                message: "Invalid receipt",
                                                type: .error
                                            )
                                        }

                                        try await Task.sleep(nanoseconds: 1_000_000_000)
                                        isAddingExpense = false
                                        progressStep = nil
                                        return
                                    }

                                    // Only upload image if AI processing was successful
                                    withAnimation {
                                        progressStep = .savingToDatabase
                                    }

                                    let imageURL = await uploadImage(selectedImage)
                                    receipt?.image_urls = [imageURL]
                                }

                                try await Task.sleep(nanoseconds: 200_000_000)

                                withAnimation {
                                    progressStep = .complete
                                }

                                try await Task.sleep(nanoseconds: 400_000_000)

                                if let receipt = receipt {
                                    onReceiptAdded(receipt)
                                    dismiss()
                                } else {
                                    withAnimation {
                                        progressStep = .error
                                    }

                                    // Show specific error toast
                                    await MainActor.run {
                                        toastManager.show(
                                            message: "Unable to extract receipt data. Please ensure the image is clear and contains a valid receipt.",
                                            type: .error,
                                            duration: 5.0
                                        )
                                    }

                                    try await Task.sleep(nanoseconds: 500_000_000)
                                    isAddingExpense = false
                                    progressStep = nil
                                }
                            } catch {
                                withAnimation {
                                    progressStep = .error
                                }

                                // Show specific error toast based on error type
                                await MainActor.run {
                                    let errorMessage = getErrorMessage(from: error)
                                    toastManager.show(
                                        message: errorMessage,
                                        type: .error,
                                        duration: 6.0
                                    )
                                }

                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                isAddingExpense = false
                                progressStep = nil
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: !capturedImages.isEmpty ? "doc.viewfinder" : "plus.circle")
                                .font(.system(size: 18))
                            Text(!capturedImages.isEmpty ? "Process Receipt" : "Add Expense")
                                .font(.spaceGrotesk(size: 18))

                            // Add subtle sparkle icon for Process Receipt
                            if !capturedImages.isEmpty {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .opacity(0.9)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            ZStack {
                                // 3D effect with shadow
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(!capturedImages.isEmpty ?
                                          Color(hex: "6D28D9") : Color.orange.opacity(0.7))
                                    .offset(y: 3)
                                    .opacity(0.6)

                                // Main button background
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(!capturedImages.isEmpty ?
                                          LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: "8B5CF6"), Color(hex: "6D28D9")]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                          ) : LinearGradient(
                                            gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.7)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                          ))
                            }
                        )
                        .foregroundColor(.white)
                        // Add subtle press animation
                        .scaleEffect(isAddingExpense ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAddingExpense)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .disabled(isAddingExpense)
                }
            }
            }
            .padding()

            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showImagePicker) {
                // Always use MultiImagePicker for multiple images
                MultiImagePicker(images: $capturedImages)
            }
            .sheet(isPresented: $showMultiCamera) {
                MultiImageCaptureView(capturedImages: $capturedImages)
            }
            .alert("Invalid Receipt", isPresented: $showInvalidReceiptAlert) {
                Button("OK", role: .cancel) {
                    // Clear images if they're invalid
                    capturedImages = []
                    selectedImage = nil
                }
            } message: {
                Text(invalidReceiptMessage.isEmpty ? "The images you provided don't appear to contain valid receipts. Please try again with clear photos of actual receipts." : invalidReceiptMessage)
            }
            .toast(toastManager: toastManager)
        }
    }


    func uploadImage(_ image: UIImage) async -> String {
        // Use the ImageStorageService to handle image uploads with fallback options
        return await ImageStorageService.shared.uploadImage(image)
    }

    // Helper function to get user-friendly error messages
    private func getErrorMessage(from error: Error) -> String {
        // Check for new AIServiceError first
        if let aiError = error as? AIServiceError {
            switch aiError {
            case .recentFailure:
                return "Service temporarily unavailable. Please try again in a few minutes."
            case .allKeysFailed:
                return "Processing service is currently busy. Please try again later."
            case .imageProcessingFailed:
                return "Failed to process image. Please try with a different image."
            case .noResponseContent:
                return "Service returned no content. Please try again."
            }
        }
        // Keep backward compatibility with legacy GeminiAPIError
        else if let geminiError = error as? GeminiAPIError {
            switch geminiError {
            case .recentFailure:
                return "Service temporarily unavailable. Please try again in a few minutes."
            case .allKeysFailed:
                return "Processing service is currently busy. Please try again later."
            }
        } else {
            // Check for specific error patterns in the error description
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("503") || errorDescription.contains("overloaded") || errorDescription.contains("unavailable") {
                return "Service is busy. Retrying..."
            } else if errorDescription.contains("429") || errorDescription.contains("rate limit") {
                return "Too many requests. Please wait a moment and try again."
            } else if errorDescription.contains("401") || errorDescription.contains("403") || errorDescription.contains("unauthorized") {
                return "Service authentication issue. Retrying..."
            } else if errorDescription.contains("400") || errorDescription.contains("bad request") {
                return "Invalid image format. Please try with a different image."
            } else if errorDescription.contains("network") || errorDescription.contains("internet") {
                return "Network connection issue. Please check your internet and try again."
            } else if errorDescription.contains("timeout") {
                return "Request timed out. Please try again with a clearer image."
            } else {
                return "Processing failed. Please try again."
            }
        }
    }

    // Helper function to resize images before upload
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

    // This function is now handled by ImageStorageService
    // Keeping this function signature for backward compatibility
    private func saveImageLocally(_ image: UIImage) async -> String {
        return await ImageStorageService.shared.uploadImage(image)
    }

    // Helper function to load an image from a URL string (supports both remote and local URLs)
    static func loadImage(from urlString: String) async -> UIImage? {
        // Check if it's a local URL
        if urlString.hasPrefix("local://") {
            // Extract the filename
            let filename = String(urlString.dropFirst("local://".count))

            // Get the documents directory
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Failed to access documents directory")
                return nil
            }

            // Create a URL for the file
            let fileURL = documentsDirectory.appendingPathComponent(filename)

            do {
                // Load the image data from the file
                let imageData = try Data(contentsOf: fileURL)
                return UIImage(data: imageData)
            } catch {
                print("Error loading local image: \(error)")
                return nil
            }
        } else if urlString == "placeholder_url" {
            // Return a placeholder image
            return UIImage(systemName: "doc.text.image")
        } else {
            // It's a remote URL
            guard let url = URL(string: urlString) else {
                print("Invalid URL: \(urlString)")
                return nil
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return UIImage(data: data)
            } catch {
                print("Error loading remote image: \(error)")
                return nil
            }
        }
    }


    func extractDataFromImage(receiptImage: UIImage) async -> Receipt? {
        do {
            let systemPrompt = """
            ### **SpendSmart Receipt Extraction and Validation System**

            #### **CRITICAL: Receipt Validation First**
            Before extracting any data, you MUST validate if this image contains a valid receipt:
            - A valid receipt should have: store name, date, items with prices, and total amount
            - If the image is blurry, unclear, not a receipt, or missing critical elements, return validation failure
            - If validation fails, return ONLY: {"isValid": false, "message": "Invalid receipt detected"}
            - If validation passes, proceed with full data extraction

            #### **Extraction Rules (only if validation passes):**
            - No missing values – every field must be correctly populated.
            - Ensure calculations are accurate – total_amount = sum(items) + total_tax.
            - When calculating total_amount, use the actual price paid (after discounts), not the original price.
            - For items redeemed with points or free items, use price = 0 in the calculation.
            - Detect currency based on store location or tax rate.
            - Extract payment method if present (e.g., "Credit Card", "Cash", "Mobile Payment").
            - Carefully identify discounts, free items, and special pricing:
              * For items with discounts, set originalPrice to the pre-discount price
              * Set discountDescription to explain the discount (e.g., "Points Redeemed", "Loyalty Discount")
              * For items that represent a discount, set isDiscount to true
              * For free items (price = 0), include why they're free in discountDescription
              * For nominal pricing (e.g., $0.01), note this in discountDescription

            #### **Store Name and Logo Search Term:**
            - ALWAYS set the receipt_name field to be the same as the store_name. The store name should be the title of the receipt.
            - Create a logo_search_term field that contains ONLY the core brand name for logo API searches.
            - The logo_search_term MUST be a generic, widely-recognizable brand identifier by:
              * Using only the main brand name without any location, store number, or descriptive text
              * Removing ALL location identifiers (e.g., "Walmart Supercenter #1234" → "Walmart")
              * Removing ALL branch/store numbers (e.g., "Target Store #0456" → "Target")
              * Removing ALL descriptors like "Restaurant", "Store", "Market", "Shop" (e.g., "McDonald's Restaurant" → "McDonald's")
              * Removing ALL location references like street names, cities, "Downtown", "Airport" (e.g., "Starbucks - Main St" → "Starbucks")
              * Using the parent company name for subsidiaries (e.g., "Taco Bell Express" → "Taco Bell")
              * Standardizing to the most common brand format (e.g., "McDonald's Corp" → "McDonald's")
            - CRITICAL: The logo_search_term should be suitable for searching logo APIs and must be a recognizable brand name only.
            - Examples:
              * "Walmart Supercenter #1234 - Downtown" → logo_search_term: "Walmart"
              * "Target Store #0456 Main Street" → logo_search_term: "Target"
              * "McDonald's Restaurant - Airport Terminal" → logo_search_term: "McDonald's"
              * "Starbucks Coffee Company - Union Square" → logo_search_term: "Starbucks"
              * "7-Eleven Store #4285 Broadway" → logo_search_term: "7-Eleven"
              * "CVS Pharmacy #9876" → logo_search_term: "CVS"
              * "Whole Foods Market - Midtown" → logo_search_term: "Whole Foods"

            #### **Item Categorization:**
            Each item must be placed in the most appropriate category:
            - Groceries → Food, beverages, household essentials, cleaning supplies, snacks, dairy, bakery items, frozen foods, and fresh produce.
            - Dining → Any prepared meals, fast food, takeout, restaurant purchases, coffee shops, and catering.
            - Shopping → Clothing, electronics, accessories, home decor, appliances, books, and general retail items.
            - Health → Medicine, supplements, pharmacy purchases, hygiene products, skincare, and personal care items.
            - Transport → Gasoline, electric vehicle charging, public transit fares, tolls, ride-sharing services, and parking fees.
            - Services → Repairs, maintenance, haircuts, subscriptions (e.g., streaming, software), utilities, and professional services.
            - Entertainment → Movie tickets, gaming, concerts, amusement parks, hobbies, toys, and streaming rentals.
            - Other → Only if no category fits. Avoid overusing this category.

            #### **Quality Check Before Output:**
            - Ensure totals are correct – verify sum of items + tax.
            - Use logical tax rates based on region/currency.
            - Extract store name, address, and date accurately.
            - IMPORTANT: Filter out any gibberish or unclear items. Only include items that are clearly identifiable from the receipt.
            - For items with unclear names, try to interpret them based on context or price.
            - If an item appears to be a discount, points redemption, or free item, mark it correctly with isDiscount=true.
            - For items that are clearly part of a points redemption system, ensure they are properly marked.
            - Verify that receipt_name matches store_name and that logo_search_term is properly optimized.

            Goal: Fully automate receipt scanning for a seamless user experience. NEVER return null values - use reasonable defaults instead (0 for numbers, empty strings for text, current date for dates). Be aware that items such as paper cups or ketchup may sometimes be free items and may not have any price beside them - use 0.0 for these prices.
            """

            let config = GenerationConfig(
              temperature: 1,
              topP: 0.95,
              topK: 40,
              maxOutputTokens: 8192,
              responseMIMEType: "application/json"
            )

            let structuredSchema = """
            {
              "type": "object",
              "properties": {
                "isValid": {
                  "type": "boolean"
                },
                "message": {
                  "type": "string"
                },
                "id": {
                  "type": "string"
                },
                "user_id": {
                  "type": "string"
                },
                "image_url": {
                  "type": "string"
                },
                "total_amount": {
                  "type": "number"
                },
                "total_tax": {
                  "type": "number"
                },
                "currency": {
                  "type": "string"
                },
                "payment_method": {
                  "type": "string"
                },
                "purchase_date": {
                  "type": "string",
                  "format": "date"
                },
                "store_name": {
                  "type": "string"
                },
                "store_address": {
                  "type": "string"
                },
                "receipt_name": {
                  "type": "string"
                },
                "logo_search_term": {
                  "type": "string"
                },
                "items": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "id": {
                        "type": "string"
                      },
                      "name": {
                        "type": "string"
                      },
                      "price": {
                        "type": "number"
                      },
                      "category": {
                        "type": "string"
                      },
                      "originalPrice": {
                        "type": "number"
                      },
                      "discountDescription": {
                        "type": "string"
                      },
                      "isDiscount": {
                        "type": "boolean"
                      }
                    },
                    "required": [
                      "id",
                      "name",
                      "price",
                      "category"
                    ]
                  }
                }
              },
              "required": [
                "isValid"
              ]
            }
            """

            let prompt = "Extract all receipt details from this image and return in this format: \(structuredSchema)."
            let response = try await aiService.generateContent(
                prompt: prompt,
                image: receiptImage,
                systemInstruction: systemPrompt,
                config: config
            )
            print(response.text ?? "No response received")

            // TODO: Parse response.text JSON into a Receipt object.
            let parsedReceipt = parseReceipt(from: response.text)  // Implement this parsing function
            return parsedReceipt
        } catch {
            print("Error extracting data from image: \(error)")
            return nil
        }
    }

    func parseReceipt(from jsonString: String?) -> Receipt? {
        guard let jsonString = jsonString, let data = jsonString.data(using: .utf8) else {
            print("Invalid JSON string")
            return nil  // ✅ Ensure the function returns nil if jsonString is invalid
        }

        do {
            // First, check if the JSON is an array or a single object
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd" // Matches the format in JSON
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Try to determine if we have an array or a single object
            let json = try JSONSerialization.jsonObject(with: data)

            // Handle the case where the response is an array
            var receiptData: Data
            if let jsonArray = json as? [Any], !jsonArray.isEmpty {
                print("Detected JSON array, extracting first item")
                // Extract the first item from the array
                if let firstItem = jsonArray.first,
                   let firstItemData = try? JSONSerialization.data(withJSONObject: firstItem) {
                    receiptData = firstItemData
                } else {
                    print("Failed to extract first item from JSON array")
                    return nil
                }
            } else if let jsonObject = json as? [String: Any] {
                // Check if this is a schema wrapper (OpenAI sometimes returns schema format)
                if let properties = jsonObject["properties"] as? [String: Any] {
                    print("Detected schema wrapper, extracting properties")
                    print("Properties keys: \(properties.keys)")
                    // Extract the actual receipt data from properties
                    let propertiesData = try JSONSerialization.data(withJSONObject: properties)
                    receiptData = propertiesData
                } else {
                    print("Using original JSON object")
                    print("JSON keys: \(jsonObject.keys)")
                    // It's already a single object, use the original data
                    receiptData = data
                }
            } else {
                print("Using original data as fallback")
                // It's already a single object, use the original data
                receiptData = data
            }

            // Now decode the single receipt object
            let parsedData = try decoder.decode(TemporaryReceipt.self, from: receiptData)

            // Check if validation failed
            if let isValid = parsedData.isValid, !isValid {
                print("Receipt validation failed: \(parsedData.message ?? "Invalid receipt")")
                return nil
            }

            // Calculate total amount if missing by summing items
            let calculatedTotalAmount: Double
            if let totalAmount = parsedData.total_amount {
                calculatedTotalAmount = totalAmount
                print("Using provided total amount: \(calculatedTotalAmount)")
            } else {
                // Sum all item prices
                calculatedTotalAmount = parsedData.items.reduce(0) { total, item in
                    print("Adding item: \(item.name) - $\(item.price)")
                    return total + item.price
                }
                print("Calculated total amount from items: \(calculatedTotalAmount)")
            }

            print("Parsed data summary:")
            print("- Store name: \(parsedData.store_name ?? "nil")")
            print("- Total amount: \(parsedData.total_amount ?? 0)")
            print("- Items count: \(parsedData.items.count)")
            print("- Currency: \(parsedData.currency ?? "nil")")
            print("- Logo search term: \(parsedData.logo_search_term ?? "nil")")

            // Set default values for missing fields
            let currentDate = Date()
            if let purchaseDate = parsedData.purchase_date {
                print("Date: \(purchaseDate)")
                print("IS08601 Date: \(purchaseDate.ISO8601Format())")
            }

            // Filter out gibberish items (single character names or very short names that aren't common abbreviations)
            let filteredItems = parsedData.items.filter { item in
                // Keep items that are marked as discounts
                if item.isDiscount {
                    return true
                }

                // Filter out single character items that aren't common abbreviations
                if item.name.count <= 1 {
                    return false
                }

                // Filter out items with names that are just punctuation or special characters
                let nonPunctuationChars = item.name.filter { !$0.isPunctuation && !$0.isSymbol }
                if nonPunctuationChars.isEmpty {
                    return false
                }

                return true
            }

            // Recalculate total if needed after filtering
            let finalTotalAmount: Double
            if filteredItems.count < parsedData.items.count {
                // Some items were filtered out, recalculate the total
                finalTotalAmount = filteredItems.reduce(0) { total, item in
                    return total + item.price
                } + (parsedData.total_tax ?? 0.0)
            } else {
                finalTotalAmount = calculatedTotalAmount
            }

            // Determine the user ID based on whether we're in guest mode or not
            let userId: UUID
            if appState.isGuestUser {
                // Use the guest user ID if available, otherwise generate a new one
                userId = appState.guestUserId ?? UUID()
            } else {
                // Use the authenticated user's ID
                userId = supabase.auth.currentUser?.id ?? UUID()
            }

            let receipt = Receipt(
                id: UUID(),
                user_id: userId,
                image_urls: [],
                total_amount: finalTotalAmount,
                items: filteredItems.map { item in
                    ReceiptItem(
                        id: UUID(),
                        name: item.name,
                        price: item.price,
                        category: item.category,
                        originalPrice: item.originalPrice,
                        discountDescription: item.discountDescription,
                        isDiscount: item.isDiscount
                    )
                },
                store_name: parsedData.store_name ?? "Unknown Store",
                store_address: parsedData.store_address ?? "",
                receipt_name: parsedData.receipt_name ?? "Receipt",
                purchase_date: parsedData.purchase_date ?? currentDate,
                currency: parsedData.currency ?? "USD",
                payment_method: parsedData.payment_method ?? "Unknown",
                total_tax: parsedData.total_tax ?? 0.0,
                logo_search_term: parsedData.logo_search_term
            )

            return receipt
        } catch {
            print("JSON Parsing Error: \(error)")
            return nil  // ✅ Ensure the function returns nil if parsing fails
        }
    }


    // Temporary struct to decode the JSON structure before transforming it into a `Receipt` object
    private struct TemporaryReceipt: Codable {
        var isValid: Bool?
        var message: String?
        var total_amount: Double?
        var total_tax: Double?
        var currency: String?
        var payment_method: String?
        var purchase_date: Date?
        var store_name: String?
        var store_address: String?
        var receipt_name: String?
        var logo_search_term: String?
        var items: [TemporaryReceiptItem]

        // Add coding keys to handle all fields
        enum CodingKeys: String, CodingKey {
            case isValid, message, total_amount, total_tax, currency, payment_method, purchase_date, store_name, store_address, receipt_name, logo_search_term, items
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Handle validation fields
            isValid = try container.decodeIfPresent(Bool.self, forKey: .isValid)
            message = try container.decodeIfPresent(String.self, forKey: .message)

            // Handle nested values that might be wrapped in schema format
            total_amount = Self.extractValue(from: container, key: .total_amount)
            total_tax = Self.extractValue(from: container, key: .total_tax)
            currency = Self.extractStringValue(from: container, key: .currency)
            payment_method = Self.extractStringValue(from: container, key: .payment_method)
            purchase_date = try container.decodeIfPresent(Date.self, forKey: .purchase_date)
            store_name = Self.extractStringValue(from: container, key: .store_name)
            store_address = Self.extractStringValue(from: container, key: .store_address)
            receipt_name = Self.extractStringValue(from: container, key: .receipt_name)
            logo_search_term = Self.extractStringValue(from: container, key: .logo_search_term)

            // Items is required, but we'll provide an empty array if missing
            items = try container.decodeIfPresent([TemporaryReceiptItem].self, forKey: .items) ?? []
        }

        // Helper methods to extract values that might be wrapped in schema format
        static func extractValue(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
            return try? container.decodeIfPresent(Double.self, forKey: key)
        }

        static func extractStringValue(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> String? {
            return try? container.decodeIfPresent(String.self, forKey: key)
        }
    }

    private struct TemporaryReceiptItem: Codable {
        var name: String
        var price: Double
        var category: String
        var originalPrice: Double?
        var discountDescription: String?
        var isDiscount: Bool
        var id: String?

        // Add coding keys to make originalPrice, discountDescription, and isDiscount optional in JSON
        enum CodingKeys: String, CodingKey {
            case name, price, category, originalPrice, discountDescription, isDiscount, id
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Required fields with fallbacks
            do {
                name = try container.decode(String.self, forKey: .name)
            } catch {
                name = "Unknown Item"
            }

            do {
                price = try container.decode(Double.self, forKey: .price)
            } catch {
                price = 0.0
            }

            do {
                category = try container.decode(String.self, forKey: .category)
            } catch {
                category = "Other"
            }

            // Optional fields with defaults
            originalPrice = try container.decodeIfPresent(Double.self, forKey: .originalPrice)
            discountDescription = try container.decodeIfPresent(String.self, forKey: .discountDescription)
            isDiscount = try container.decodeIfPresent(Bool.self, forKey: .isDiscount) ?? false
            id = try container.decodeIfPresent(String.self, forKey: .id)
        }
    }

}

struct ImageCaptureView: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImageCaptureView

        init(_ parent: ImageCaptureView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}

// Preview
struct NewExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        NewExpenseView(onReceiptAdded: { _ in })
            .preferredColorScheme(.dark)
    }
}
