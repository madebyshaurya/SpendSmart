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
import Shimmer
// Import the receipt validation service
import Foundation
// Import the image storage service
import UIKit

struct NewExpenseView: View {
    let onReceiptAdded: (Receipt) -> Void
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
    @State private var showPaywall = false
    @EnvironmentObject var appState: AppState

    // Enhanced streaming loading states
    @State private var streamingProgress: AIStreamingProgress?
    @State private var animatedProgress: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0.0
    @State private var shimmerOffset: CGFloat = -200
    @State private var typingText = ""
    @State private var typingIndex = 0
    @State private var showTypingIndicator = false
    
    // Full-screen processing state
    @State private var showFullScreenProcessing = false
    @State private var processingStartTime: Date?

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
            ZStack {
                BackgroundGradientView()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("New Expense")
                            .font(.instrumentSerifItalic(size: 32))
                            .foregroundColor(.primary)
                        
                        Text("Scan a receipt to track your expenses")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    if !capturedImages.isEmpty || selectedImage != nil {
                        // Modern image display
                        ZStack {
                            if !capturedImages.isEmpty {
                                // Multi-image carousel with modern design
                                TabView(selection: $currentImageIndex) {
                                    ForEach(0..<capturedImages.count, id: \.self) { index in
                                        Image(uiImage: capturedImages[index])
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                                            .padding(20)
                                            .tag(index)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                .frame(height: 350)
                                
                                // Modern counter overlay
                                VStack {
                                    HStack {
                                        Spacer()
                                        Text("\(currentImageIndex + 1) of \(capturedImages.count)")
                                            .font(.instrumentSans(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(.ultraThinMaterial, in: Capsule())
                                            .padding(.trailing, 20)
                                            .padding(.top, 10)
                                    }
                                    Spacer()
                                }
                            } else if let image = selectedImage {
                                // Single image with modern styling
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                                    .padding(20)
                                    .frame(height: 350)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    } else {
                        // Modern empty state
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 120, height: 120)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "receipt")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundColor(.blue)
                            }

                            VStack(spacing: 12) {
                                Text("Ready to Scan")
                                    .font(.instrumentSans(size: 24, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("Tap the camera button below to capture your receipt or choose from gallery")
                                    .font(.instrumentSans(size: 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                        .padding(.vertical, 60)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
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
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(step.color)
                                    .scaleEffect(pulseScale)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                            pulseScale = 1.2
                                        }
                                    }
                            }
                            .frame(width: 120, height: 120)

                            // Step Title (single line to avoid cutoff)
                            Text(step.rawValue)
                                .font(.instrumentSans(size: 22, weight: .semibold))
                                .foregroundColor(step.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .multilineTextAlignment(.center)
                                .shimmering(
                                    active: true,
                                    animation: .easeInOut(duration: 2.0).repeatForever(autoreverses: false)
                                )

                            // Step Description
                            Text(step.description)
                                .font(.instrumentSans(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 32)
                        }
                        .padding(.vertical, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal, 16)
                    }
                    .transition(.opacity)
                }

                // Enhanced Streaming Loading View
                if isAddingExpense, let progress = streamingProgress {
                    EnhancedStreamingLoadingView(progress: progress)
                        .transition(.opacity.combined(with: .scale))
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
                                                                        HStack(spacing: 8) {
                                            Image(systemName: "camera.viewfinder")
                                                .font(.system(size: 18, weight: .medium))
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
                                                                        HStack(spacing: 8) {
                                            Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .medium))
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
                        // MARK: - Receipt Limit Check
                        // Check if user can add receipt before processing
                        guard appState.canAddReceipt else {
                            print("🚫 [NewExpenseView] Receipt limit reached, showing paywall")
                            HapticFeedbackManager.shared.warning()
                            showPaywall = true
                            return
                        }

                        isAddingExpense = true
                        Task {
                            do {
                                // Initialize streaming progress
                                streamingProgress = AIStreamingProgress(
                                    stage: .initializing,
                                    progress: 0.0,
                                    message: "Initializing AI processing...",
                                    partialText: ""
                                )
                                
                                // Start with initializing stage
                                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                
                                // Update to analyzing stage
                                streamingProgress = AIStreamingProgress(
                                    stage: .analyzing,
                                    progress: 0.2,
                                    message: "Analyzing receipt image...",
                                    partialText: ""
                                )
                                
                                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                
                                // Update to extracting stage
                                streamingProgress = AIStreamingProgress(
                                    stage: .extracting,
                                    progress: 0.4,
                                    message: "Extracting receipt data...",
                                    partialText: ""
                                )

                                var receipt: Receipt?
                                var imageURLs: [String] = []

                                if !capturedImages.isEmpty {
                                    // Process multiple images
                                    receipt = await extractDataFromImage(receiptImage: capturedImages[0])

                                    // Update to processing stage
                                    streamingProgress = AIStreamingProgress(
                                        stage: .processing,
                                        progress: 0.6,
                                        message: "Processing...",
                                        partialText: ""
                                    )

                                    // Upload images only if AI processing was successful
                                    if let _ = receipt {
                                        for (index, image) in capturedImages.enumerated() {
                                            let imageURL = await uploadImage(image)
                                            if imageURL != "placeholder_url" {
                                                imageURLs.append(imageURL)
                                            }

                                            // Update progress for each image
                                            let imageProgress = 0.6 + (0.2 * Double(index + 1) / Double(capturedImages.count))
                                            streamingProgress = AIStreamingProgress(
                                                stage: .processing,
                                                progress: imageProgress,
                                                message: "Uploading...",
                                                partialText: ""
                                            )
                                        }

                                        // Set all image URLs
                                        receipt?.image_urls = imageURLs
                                    }
                                } else if let selectedImage = selectedImage {
                                    // Process single image
                                    receipt = await extractDataFromImage(receiptImage: selectedImage)

                                    // Check if validation failed
                                    if receipt == nil {
                                        streamingProgress = AIStreamingProgress(
                                            stage: .error,
                                            progress: 1.0,
                                            message: "Invalid receipt detected",
                                            partialText: ""
                                        )
                                        
                                        // Show invalid receipt toast
                                        await MainActor.run {
                                            toastManager.show(
                                                message: "Please try a clearer image or different receipt",
                                                type: .error,
                                                duration: 4.0
                                            )
                                        }

                                        try await Task.sleep(nanoseconds: 1_000_000_000)
                                        isAddingExpense = false
                                        streamingProgress = nil
                                        return
                                    }

                                    // Update to processing stage
                                    streamingProgress = AIStreamingProgress(
                                        stage: .processing,
                                        progress: 0.7,
                                        message: "Uploading receipt image...",
                                        partialText: ""
                                    )

                                    // Only upload image if AI processing was successful
                                    if let _ = receipt {
                                        let imageURL = await uploadImage(selectedImage)
                                        receipt?.image_urls = [imageURL]
                                    }
                                }

                                // Update to validating stage
                                streamingProgress = AIStreamingProgress(
                                    stage: .validating,
                                    progress: 0.9,
                                    message: "Validating receipt data...",
                                    partialText: ""
                                )

                                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                                // Complete
                                streamingProgress = AIStreamingProgress(
                                    stage: .complete,
                                    progress: 1.0,
                                    message: "Receipt processed successfully!",
                                    partialText: ""
                                )

                                try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds

                                if let receipt = receipt {
                                    onReceiptAdded(receipt)
                                    dismiss()
                                } else {
                                    streamingProgress = AIStreamingProgress(
                                        stage: .error,
                                        progress: 1.0,
                                        message: "Unable to extract receipt data",
                                        partialText: ""
                                    )

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
                                    streamingProgress = nil
                                }
                            } catch {
                                streamingProgress = AIStreamingProgress(
                                    stage: .error,
                                    progress: 1.0,
                                    message: "Error processing receipt",
                                    partialText: ""
                                )

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
                                streamingProgress = nil
                            }
                        }
                    } label: {
                                                                HStack(spacing: 8) {
                                            Image(systemName: !capturedImages.isEmpty ? "doc.viewfinder" : "plus.circle")
                                                .font(.system(size: 18, weight: .medium))
                                            Text(!capturedImages.isEmpty ? "Process Receipt" : "Add Expense")
                                                .font(.spaceGrotesk(size: 18, weight: .medium))

                                            // Add subtle sparkle icon for Process Receipt
                                            if !capturedImages.isEmpty {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .opacity(0.9)
                                                    .shimmering(
                                                        active: true,
                                                        animation: .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                                                    )
                                            }
                                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.blue.gradient)
                                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                        )
                        .foregroundColor(.white)
                        // Add subtle press animation
                        .scaleEffect(isAddingExpense ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAddingExpense)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .disabled(isAddingExpense)
                    .onTapGesture {
                        if !capturedImages.isEmpty {
                            // Show full-screen processing for receipt processing
                            processingStartTime = Date()
                            showFullScreenProcessing = true
                        }
                    }
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(appState)
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
            .fullScreenCover(isPresented: $showFullScreenProcessing) {
                FullScreenProcessingView(
                    capturedImages: capturedImages,
                    onReceiptAdded: onReceiptAdded,
                    onDismiss: {
                        showFullScreenProcessing = false
                        processingStartTime = nil
                    },
                    onError: { error in
                        showFullScreenProcessing = false
                        processingStartTime = nil
                        // Show error toast
                        DispatchQueue.main.async {
                            // Handle error display
                        }
                    }
                )
                .environmentObject(appState)
            }
            .toast(toastManager: toastManager)
        }
        }
    }
    
    // MARK: - Helper Functions
    func uploadImage(_ image: UIImage) async -> String {
        // Use the ImageStorageService to handle image uploads with fallback options
        return await ImageStorageService.shared.uploadImage(image)
    }

    // Helper function to get user-friendly error messages
    private func getErrorMessage(from error: Error) -> String {
        // Check for new AIServiceError first
        if let aiError = error as? AIServiceError {
            switch aiError {
            case .authenticationFailed:
                return "Authentication failed. Please sign in again."
            case .rateLimited:
                return "Service temporarily unavailable. Please try again in a few minutes."
            case .serverError:
                return "Processing service is currently busy. Please try again later."
            case .requestFailed(let message):
                return "Request failed: \(message)"
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


    // MARK: - AI Data Extraction
    private func extractDataFromImage(receiptImage: UIImage) async -> Receipt? {
        print("🔍 [extractDataFromImage] Starting receipt processing...")
        print("🔍 [extractDataFromImage] Image size: \(receiptImage.size)")
        
        // Check backend status
        let backendStatus = await BackendAPIService.shared.getBackendStatus()
        print("🔍 [extractDataFromImage] Backend URL: \(backendStatus.url)")
        print("🔍 [extractDataFromImage] Using localhost: \(backendStatus.isLocalhost)")
        
        do {
            // Use the new single receipt processing endpoint
            print("🔍 [extractDataFromImage] Calling aiService.processReceipt...")
            let result = try await aiService.processReceipt(image: receiptImage)
            
            print("🔍 [extractDataFromImage] AI response received:")
            print("🔍 [extractDataFromImage] - isValid: \(result.isValid)")
            print("🔍 [extractDataFromImage] - message: \(result.message ?? "nil")")
            print("🔍 [extractDataFromImage] - storeName: \(result.storeName ?? "nil")")
            print("🔍 [extractDataFromImage] - totalAmount: \(result.totalAmount ?? 0.0)")
            print("🔍 [extractDataFromImage] - items count: \(result.items.count)")
            
            // Check if receipt is valid
            guard result.isValid else {
                print("❌ [extractDataFromImage] Receipt validation failed: \(result.message ?? "Unknown error")")
                return nil
            }
            
            print("✅ [extractDataFromImage] Receipt is valid, converting to Receipt object...")
            
            // Convert the processing result to a Receipt object
            return await NewExpenseView.convertProcessingResultToReceipt(result, appState: appState)
            
        } catch {
            print("❌ [extractDataFromImage] AI processing failed: \(error.localizedDescription)")
            print("❌ [extractDataFromImage] Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ [extractDataFromImage] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ [extractDataFromImage] Error userInfo: \(nsError.userInfo)")
            }
            return nil
        }
    }

    static func convertProcessingResultToReceipt(_ result: ReceiptProcessingResult, appState: AppState) async -> Receipt? {
        guard let storeName = result.storeName,
              let purchaseDateString = result.purchaseDate,
              let totalAmount = result.totalAmount,
              let currency = result.currency else {
            print("❌ [convertProcessingResultToReceipt] Missing required fields")
            return nil
        }
        
        // Parse purchase date
            let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let purchaseDate = dateFormatter.date(from: purchaseDateString) else {
            print("❌ [convertProcessingResultToReceipt] Invalid date format: \(purchaseDateString)")
                    return nil
        }
        
        // Convert items
        let receiptItems = result.items.map { item in
                    ReceiptItem(
                        id: UUID(),
                        name: item.name,
                        price: item.price,
                        category: item.category,
                        originalPrice: item.originalPrice ?? item.price,
                        discountDescription: item.discountDescription ?? "",
                        isDiscount: item.isDiscount
                )
        }
        
        // Create receipt
        // Convert user ID - try guestUserId first, then auth token, then fallback to random UUID
        let userId = appState.guestUserId ?? UUID(uuidString: BackendAPIService.shared.getAuthToken() ?? "") ?? UUID()
        
        // Prepare other values
        let receiptName = result.receiptName ?? storeName
        let storeAddress = result.storeAddress ?? ""
        let paymentMethod = result.paymentMethod ?? "Unknown"
        let logoSearchTerm = result.logoSearchTerm ?? storeName
        let totalTax = result.totalTax ?? 0.0
        
        let receipt = Receipt(
            id: UUID(),
            user_id: userId,
            image_urls: [], // Will be set later when images are uploaded
            total_amount: totalAmount,
            items: receiptItems,
            store_name: storeName,
            store_address: storeAddress,
            receipt_name: receiptName,
            purchase_date: purchaseDate,
            currency: currency,
            payment_method: paymentMethod,
            total_tax: totalTax,
            logo_search_term: logoSearchTerm
        )

            return receipt
    }

    // MARK: - Streaming Progress View
    @ViewBuilder
    private func streamingProgressView(progress: AIStreamingProgress) -> some View {
        VStack(spacing: 30) {
            // Clean, modern loading design without shadows
            VStack(spacing: 24) {
                // Animated icon with clean design
                ZStack {
                    // Subtle background circle
                    Circle()
                        .fill(progress.stage.color.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    // Main icon
                    Image(systemName: progress.stage.systemImage)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(progress.stage.color)
                        .scaleEffect(pulseScale)
                }
                .frame(width: 100, height: 100)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseScale = 1.1
                    }
                }
                
                // Stage title
                Text(progress.stage.displayName)
                    .font(.spaceGrotesk(size: 24, weight: .bold))
                    .foregroundColor(progress.stage.color)
                
                // Progress bar with clean design
                VStack(spacing: 12) {
                    HStack {
                        Text("Processing...")
                            .font(.spaceGrotesk(size: 16))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(progress.progressPercentage)%")
                            .font(.spaceGrotesk(size: 16, weight: .medium))
                            .foregroundColor(progress.stage.color)
                    }
                    
                    // Clean progress bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(progress.stage.color)
                            .frame(width: max(0, UIScreen.main.bounds.width - 80) * animatedProgress, height: 6)
                            .animation(.easeInOut(duration: 0.8), value: animatedProgress)
                    }
                }
                .padding(.horizontal, 20)
                
                // Status message
                Text(progress.message)
                    .font(.spaceGrotesk(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Accurate time estimate
                if !progress.isComplete {
                    Text(accurateTimeEstimate)
                        .font(.spaceGrotesk(size: 14))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 20)
        }
        .onChange(of: progress.progress) { _, newProgress in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = newProgress
            }
        }
    }
    
    private var accurateTimeEstimate: String {
        guard let startTime = processingStartTime else { return "Processing..." }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let totalStages = AIStreamingStage.allCases.count
        let currentStageIndex = AIStreamingStage.allCases.firstIndex(of: streamingProgress?.stage ?? .initializing) ?? 0
        
        // Calculate remaining time based on actual elapsed time and stage progress
        let averageTimePerStage = elapsed / Double(currentStageIndex + 1)
        let remainingStages = totalStages - currentStageIndex - 1
        let estimatedRemaining = averageTimePerStage * Double(remainingStages)
        
        if estimatedRemaining > 0 {
            let minutes = Int(estimatedRemaining / 60)
            let seconds = Int(estimatedRemaining.truncatingRemainder(dividingBy: 60))
            
            if minutes > 0 {
                return "About \(minutes)m \(seconds)s remaining"
            } else {
                return "About \(seconds)s remaining"
            }
        }
        return "Almost done..."
    }
}


// MARK: - Full Screen Processing View
struct FullScreenProcessingView: View {
    let capturedImages: [UIImage]
    let onReceiptAdded: (Receipt) -> Void
    let onDismiss: () -> Void
    let onError: (String) -> Void
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var streamingProgress: AIStreamingProgress?
    @State private var animatedProgress: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var processingStartTime: Date?
    @State private var isProcessing = false
    
    private let aiService = AIService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "667eea"),
                        Color(hex: "764ba2")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Processing Receipt")
                            .font(.instrumentSans(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("We're analyzing your receipt to extract all the details")
                            .font(.instrumentSans(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                    
                    // Processing content
                    if let progress = streamingProgress {
                        ScrollView {
                            VStack(spacing: 30) {
                                // Clean processing view
                                VStack(spacing: 24) {
                                    // Animated icon
                                    ZStack {
                                        Circle()
                                            .fill(progress.stage.color.opacity(0.2))
                                            .frame(width: 100, height: 100)
                                        
                                        Image(systemName: progress.stage.systemImage)
                                            .font(.system(size: 40, weight: .medium))
                                            .foregroundColor(.white)
                                            .scaleEffect(pulseScale)
                                    }
                                    .frame(width: 120, height: 120)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                            pulseScale = 1.1
                                        }
                                    }
                                    
                                    // Stage title
                                    Text(progress.stage.displayName)
                                        .font(.instrumentSans(size: 22, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    // Progress bar
                                    VStack(spacing: 12) {
                                        HStack {
                                            Text("Processing...")
                                                .font(.instrumentSans(size: 14))
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Spacer()
                                            
                                            Text("\(progress.progressPercentage)%")
                                                .font(.instrumentSans(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(0.3))
                                                .frame(height: 8)
                                            
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white)
                                                .frame(width: max(0, UIScreen.main.bounds.width - 80) * animatedProgress, height: 8)
                                                .animation(.easeInOut(duration: 0.8), value: animatedProgress)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    // Status message
                                    Text(progress.message)
                                        .font(.instrumentSans(size: 14))
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                    
                                    // Time estimate
                                    if !progress.isComplete {
                                        Text(accurateTimeEstimate)
                                            .font(.instrumentSans(size: 12))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                .padding(.vertical, 40)
                                .padding(.horizontal, 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color.white.opacity(0.1))
                                        .background(.ultraThinMaterial)
                                )
                                .padding(.horizontal, 20)
                            }
                            .padding(.vertical, 20)
                        }
                    } else {
                        // Initial loading state
                        VStack(spacing: 30) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("Preparing to process your receipt...")
                                .font(.instrumentSans(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                    .font(.spaceGrotesk(size: 16, weight: .medium))
                }
            }
        }
        .onAppear {
            processingStartTime = Date()
            startProcessing()
        }
        .onChange(of: streamingProgress?.progress) { _, newProgress in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = newProgress ?? 0.0
            }
        }
    }
    
    private var accurateTimeEstimate: String {
        guard let startTime = processingStartTime else { return "Processing..." }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let totalStages = AIStreamingStage.allCases.count
        let currentStageIndex = AIStreamingStage.allCases.firstIndex(of: streamingProgress?.stage ?? .initializing) ?? 0
        
        // Calculate remaining time based on actual elapsed time and stage progress
        let averageTimePerStage = elapsed / Double(currentStageIndex + 1)
        let remainingStages = totalStages - currentStageIndex - 1
        let estimatedRemaining = averageTimePerStage * Double(remainingStages)
        
        if estimatedRemaining > 0 {
            let minutes = Int(estimatedRemaining / 60)
            let seconds = Int(estimatedRemaining.truncatingRemainder(dividingBy: 60))
            
            if minutes > 0 {
                return "About \(minutes)m \(seconds)s remaining"
            } else {
                return "About \(seconds)s remaining"
            }
        }
        return "Almost done..."
    }
    
    private func startProcessing() {
        guard !capturedImages.isEmpty else {
            onError("No images to process")
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                // Start with initializing stage
                await MainActor.run {
                    streamingProgress = AIStreamingProgress(
                        stage: .initializing,
                        progress: 0.0,
                        message: "Initializing AI processing...",
                        partialText: ""
                    )
                }
                
                // Upload images
                var imageUrls: [String] = []
                for (_, image) in capturedImages.enumerated() {
                    await MainActor.run {
                        streamingProgress = AIStreamingProgress(
                            stage: .analyzing,
                            progress: 0.2,
                            message: "Uploading...",
                            partialText: ""
                        )
                    }
                    
                    let imageUrl = await ImageStorageService.shared.uploadImage(image)
                    imageUrls.append(imageUrl)
                }
                
                // Process with AI
                await MainActor.run {
                    streamingProgress = AIStreamingProgress(
                        stage: .extracting,
                        progress: 0.4,
                        message: "Extracting receipt data...",
                        partialText: ""
                    )
                }
                
                await MainActor.run {
                    streamingProgress = AIStreamingProgress(
                        stage: .processing,
                        progress: 0.7,
                        message: "Processing information...",
                        partialText: ""
                    )
                }
                
                // Process receipt with AI
                let receipt = try await processReceiptWithAI(imageUrls: imageUrls)
                
                await MainActor.run {
                    streamingProgress = AIStreamingProgress(
                        stage: .validating,
                        progress: 0.9,
                        message: "Validating results...",
                        partialText: ""
                    )
                }
                
                // Save to database
                let savedReceipt = try await saveReceipt(receipt)
                
                await MainActor.run {
                    streamingProgress = AIStreamingProgress(
                        stage: .complete,
                        progress: 1.0,
                        message: "Receipt processed successfully!",
                        partialText: ""
                    )
                }
                
                // Wait a moment to show completion
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    onReceiptAdded(savedReceipt)
                    onDismiss()
                }
                
            } catch {
                await MainActor.run {
                    streamingProgress = AIStreamingProgress(
                        stage: .error,
                        progress: 0.0,
                        message: "Error processing receipt: \(error.localizedDescription)",
                        partialText: ""
                    )
                }
                
                // Wait a moment then show error
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    onError(error.localizedDescription)
                }
            }
        }
    }
    
    private func processReceiptWithAI(imageUrls: [String]) async throws -> Receipt {
        // Use the first image for processing
        guard let firstImage = capturedImages.first else {
            throw NSError(domain: "FullScreenProcessingView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No images to process"])
        }
        
        // Use the new single receipt processing endpoint
        let result = try await aiService.processReceipt(image: firstImage)
        
        // Check if receipt is valid
        guard result.isValid else {
            throw NSError(domain: "FullScreenProcessingView", code: -2, userInfo: [NSLocalizedDescriptionKey: result.message ?? "Invalid receipt detected"])
        }
        
        // Convert the processing result to a Receipt object
        guard let receipt = await NewExpenseView.convertProcessingResultToReceipt(result, appState: appState) else {
            throw NSError(domain: "FullScreenProcessingView", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert receipt data"])
        }
        
        // Update the receipt with all image URLs
        var updatedReceipt = receipt
        updatedReceipt.image_urls = imageUrls
        
        return updatedReceipt
    }
    
    private func saveReceipt(_ receipt: Receipt) async throws -> Receipt {
        if appState.useLocalStorage {
            LocalStorageService.shared.addReceipt(receipt)
            return receipt
        } else {
            return try await supabase.createReceipt(receipt)
        }
    }
}
