//
//  DocumentScannerView.swift
//  SpendSmart
//
//  Created by Claude Code on 2025-01-09.
//

import SwiftUI
import VisionKit
import UIKit

@available(iOS 13.0, *)
struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var scannedImages: [UIImage]
    @Environment(\.dismiss) var dismiss
    
    var onCompletion: (([UIImage]) -> Void)?
    var onError: ((Error) -> Void)?
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed for document scanner
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: DocumentScannerView
        
        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }
        
        // MARK: - VNDocumentCameraViewControllerDelegate Methods
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            print("Document scan completed with \(scan.pageCount) pages")
            
            var scannedImages: [UIImage] = []
            
            // Extract all scanned pages
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                scannedImages.append(image)
            }
            
            // Update binding and call completion
            DispatchQueue.main.async {
                self.parent.scannedImages = scannedImages
                self.parent.onCompletion?(scannedImages)
                self.parent.dismiss()
            }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanning failed with error: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                self.parent.onError?(error)
                self.parent.dismiss()
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            print("Document scanning cancelled by user")
            
            DispatchQueue.main.async {
                self.parent.dismiss()
            }
        }
    }
}

// MARK: - DocumentScannerError

enum DocumentScannerError: Error, LocalizedError {
    case notAvailable
    case scanningFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Document scanning is not available on this device."
        case .scanningFailed(let underlying):
            return "Scanning failed: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - DocumentScannerAvailability

struct DocumentScannerAvailability {
    static var isAvailable: Bool {
        return VNDocumentCameraViewController.isSupported
    }
    
    static var unavailableReason: String? {
        guard !isAvailable else { return nil }
        return "Document scanning requires iOS 13.0 or later and is not available on this device."
    }
}

// MARK: - Preview

struct DocumentScannerView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentScannerView(
            scannedImages: .constant([]),
            onCompletion: { images in
                print("Scanned \(images.count) images")
            },
            onError: { error in
                print("Scanning error: \(error.localizedDescription)")
            }
        )
    }
}