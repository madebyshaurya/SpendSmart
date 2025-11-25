//
//  MultiImageCaptureView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-10.
//

import SwiftUI
import AVFoundation
import UIKit
import VisionKit

// Camera components

// Camera preview view with loading indicator
fileprivate struct CameraPreviewView: View {
    @ObservedObject var cameraController: CameraController

    var body: some View {
        // Camera preview layer
        CameraPreviewLayer(cameraController: cameraController)
            .ignoresSafeArea()
    }
}

// UIViewRepresentable for camera preview layer
fileprivate struct CameraPreviewLayer: UIViewRepresentable {
    @ObservedObject var cameraController: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .darkGray
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let session = cameraController.captureSession, uiView.videoPreviewLayer.session != session {
            print("Updating preview layer with session")
            DispatchQueue.main.async {
                uiView.videoPreviewLayer.session = session
            }
        }
    }

    // Custom UIView subclass that uses AVCaptureVideoPreviewLayer as its backing layer
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// Camera controller class to handle AVFoundation camera operations
fileprivate class CameraController: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    @Published var isInitialized = false
    @Published var isCapturing = false

    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoOutput: AVCapturePhotoOutput?
    var photoCaptureCompletionBlock: ((UIImage?) -> Void)?

    // Initialize the camera session immediately when the controller is created
    override init() {
        super.init()
        setupCameraSession()
    }

    private func setupCameraSession() {
        // Create a capture session
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        self.captureSession = session

        // Configure the session in the background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Get the back camera
            guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                return
            }

            // Create and add camera input
            do {
                let input = try AVCaptureDeviceInput(device: backCamera)
                if session.canAddInput(input) {
                    session.addInput(input)
                }

                // Create and add photo output
                let output = AVCapturePhotoOutput()
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    self.photoOutput = output

                    // Start the session
                    session.startRunning()

                    // Update UI on main thread
                    DispatchQueue.main.async {
                        self.isInitialized = true
                    }
                }
            } catch {
                print("Failed to set up camera: \(error.localizedDescription)")
            }
        }
    }

    func prepare(completionHandler: @escaping (Error?) -> Void) {
        // If the session is already running, just call the completion handler
        if captureSession?.isRunning == true {
            completionHandler(nil)
            return
        }

        // Otherwise, start the session if it's not running
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.async {
                    self.isInitialized = true
                    completionHandler(nil)
                }
            }
        } else {
            // If there's no session, set up a new one
            setupCameraSession()
            completionHandler(nil)
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCaptureCompletionBlock = completion
        isCapturing = true

        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.isCapturing = false
        }

        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            photoCaptureCompletionBlock?(nil)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCaptureCompletionBlock?(nil)
            return
        }

        photoCaptureCompletionBlock?(image)
    }

    func stopSession() {
        captureSession?.stopRunning()
    }
}

// Custom button style for scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct MultiImageCaptureView: View {
    @Binding var capturedImages: [UIImage]
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var cameraController = CameraController()
    @State private var isFlashOn = false
    @State private var showPreview = false
    @State private var previewImage: UIImage?
    @State private var showingGuide = true
    @State private var showingConfirmation = false
    @State private var animateCapture = false
    @State private var animateFlash = false
    
    // Document scanner integration
    @State private var showingDocumentScanner = false
    @State private var scannerImages: [UIImage] = []
    
    // Enhanced preview system
    @State private var showingEnhancedPreview = false
    @State private var previewOriginalImage: UIImage?
    @State private var previewProcessedImage: UIImage?
    @State private var previewResult: ImageProcessingResult?
    @State private var documentScanMode = false

    // Animation properties
    @State private var captureScale: CGFloat = 1.0
    @State private var thumbnailOffset: CGFloat = 100

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraController: cameraController)
                .ignoresSafeArea()
                .overlay(
                    // Flash overlay
                    Rectangle()
                        .fill(Color.white)
                        .ignoresSafeArea()
                        .opacity(animateFlash ? 0.3 : 0)
                )

            // UI overlay
            VStack {
                controlBar
                    .padding(16)
                    .glassCompatRect(cornerRadius: 24, interactive: true)
                    .padding()

                Spacer()

                // No receipt guide overlay

                // Bottom controls
                VStack(spacing: 20) {
                    // Thumbnail gallery of captured images
                    if !capturedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(0..<capturedImages.count, id: \.self) { index in
                                    Image(uiImage: capturedImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        .onTapGesture {
                                            previewImage = capturedImages[index]
                                            showPreview = true
                                        }
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.5).combined(with: .offset(x: thumbnailOffset)),
                                            removal: .opacity
                                        ))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 90)
                        .glassCompatRect(cornerRadius: 12)
                        .padding(.horizontal, 8)
                    }

                    HStack(spacing: 50) {
                        // Done button
                        Button {
                            showingConfirmation = true
                        } label: {
                            Text("Done")
                                .font(.instrumentSans(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .opacity(capturedImages.isEmpty ? 0.5 : 1)
                        }
                        .disabled(capturedImages.isEmpty)

                        // Capture button
                        Button {
                            capturePhoto()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .scaleEffect(captureScale)

                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 80, height: 80)
                            }
                        }
                        .buttonStyle(MultiImageScaleButtonStyle())
                    }
                    .padding(.bottom, 30)
                }
                .padding(.bottom)
            }

            // Image preview overlay
            if showPreview, let previewImage = previewImage {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showPreview = false
                        }

                    VStack {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .padding()

                        HStack(spacing: 40) {
                            Button {
                                if let index = capturedImages.firstIndex(where: { $0 == previewImage }) {
                                    capturedImages.remove(at: index)
                                }
                                showPreview = false
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .font(.instrumentSans(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                            }
                            .glassCompatCapsule(tint: .red, interactive: true)

                            Button {
                                showPreview = false
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Keep")
                                }
                                .font(.instrumentSans(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                            }
                            .glassCompatCapsule(tint: .green, interactive: true)
                        }
                        .padding(.bottom, 30)
                    }
                }
                .transition(.opacity)
            }

            // Confirmation dialog - Redesigned to be more minimalistic and elegant
            if showingConfirmation {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingConfirmation = false
                        }

                    VStack(spacing: 16) {
                        Text("\(capturedImages.count) image\(capturedImages.count == 1 ? "" : "s") captured")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.top, 8)

                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal, 8)

                        HStack(spacing: 16) {
                            Button {
                                showingConfirmation = false
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                    Text("Continue")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                            }
                            .glassCompatCapsule(interactive: true)

                            Button {
                                dismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14))
                                    Text("Done")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                            }
                            .glassCompatCapsule(tint: .blue, interactive: true)
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.8))
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 40)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            cameraController.prepare { _ in }
        }
        .onDisappear {
            cameraController.stopSession()
        }
        .sheet(isPresented: $showingDocumentScanner) {
            DocumentScannerView(
                scannedImages: $scannerImages,
                onCompletion: { images in
                    handleScannedImages(images)
                },
                onError: { error in
                    print("Document scanning error: \(error.localizedDescription)")
                }
            )
        }
        .sheet(isPresented: $showingEnhancedPreview) {
            if let originalImage = previewOriginalImage,
               let processedImage = previewProcessedImage,
               let result = previewResult {
                EnhancedReceiptPreviewView(
                    originalImage: originalImage,
                    processedImage: processedImage,
                    processingResult: result,
                    onAccept: { finalImage in
                        withAnimation {
                            capturedImages.append(finalImage)
                            thumbnailOffset = 100
                        }
                        resetPreviewState()
                    },
                    onReject: {
                        resetPreviewState()
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var controlBar: some View {
        HStack {
            let dismissLabel = {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
            }
            
            Button(action: { dismiss() }, label: dismissLabel)
                .glassCompatCircle(interactive: true)

            Spacer()
            
            if DocumentScannerAvailability.isAvailable {
                let scannerLabel = {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                }
                
                Button(action: { showingDocumentScanner = true }, label: scannerLabel)
                    .glassCompatCircle(tint: .blue, interactive: true)
            }

            let flashLabel = {
                Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
            }

            Button(action: { isFlashOn.toggle() }, label: flashLabel)
                .glassCompatCircle(interactive: true)
        }
    }
    
    // MARK: - Document Scanner Methods
    
    private func resetPreviewState() {
        previewOriginalImage = nil
        previewProcessedImage = nil
        previewResult = nil
        showingEnhancedPreview = false
    }
    
    private func handleScannedImages(_ images: [UIImage]) {
        Task {
            // Process through multi-part receipt processor first
            let multiPartResult = await MultiPartReceiptProcessor.shared.processMultiPartReceipt(images)
            
            if multiPartResult.processedImages.count == 1,
               let singleImage = multiPartResult.processedImages.first,
               let originalImage = images.first {
                
                // Show preview for single processed image (likely stitched or cropped)
                let result = multiPartResult.toImageProcessingResult()
                
                await MainActor.run {
                    previewOriginalImage = originalImage
                    previewProcessedImage = singleImage
                    previewResult = result
                    showingEnhancedPreview = true
                }
            } else {
                // Multiple separate images - add them directly with confidence indicators
                await MainActor.run {
                    for image in multiPartResult.processedImages {
                        withAnimation {
                            capturedImages.append(image)
                            thumbnailOffset = 100 // Reset for next animation
                        }
                    }
                }
                print("Successfully processed \(multiPartResult.processedImages.count) separate images")
            }
            
            // Clear scanner images
            await MainActor.run {
                scannerImages.removeAll()
            }
        }
    }

    private func capturePhoto() {
        // Animate the capture button
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            captureScale = 0.8
            animateFlash = true
        }

        // Reset the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                captureScale = 1.0
            }
        }

        // Reset flash animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateFlash = false
        }

        // Capture the photo
        cameraController.capturePhoto { image in
            guard let image = image else { return }

            // Process image with analysis and show preview
            Task {
                let (processedImage, result) = await ReceiptImageProcessor.shared.processImageWithAnalysis(image, processingType: "Camera Capture")
                
                await MainActor.run {
                    previewOriginalImage = image
                    previewProcessedImage = processedImage
                    previewResult = result
                    showingEnhancedPreview = true
                }
            }
        }
    }
}

// Custom button style for scale animation
fileprivate struct MultiImageScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}



struct MultiImageCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        MultiImageCaptureView(capturedImages: .constant([]))
    }
}
