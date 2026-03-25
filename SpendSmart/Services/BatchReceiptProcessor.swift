import Foundation
import UIKit

/// Processes multiple receipt images in parallel, each as a separate receipt.
/// Uses a concurrency limit of 3 to avoid overwhelming the Vercel backend.
@MainActor
final class BatchReceiptProcessor: ObservableObject {

    // MARK: - Types

    enum ItemStatus {
        case pending
        case processing
        case success(ReceiptProcessingResponse, imageUrls: [String])
        case failed(String)
    }

    struct BatchItem: Identifiable {
        let id = UUID()
        let image: UIImage
        var status: ItemStatus = .pending
        var retryCount: Int = 0
    }

    // MARK: - Published State

    @Published var items: [BatchItem] = []
    @Published var isProcessing = false
    @Published var isCancelled = false

    var processedCount: Int { items.filter { if case .success = $0.status { return true }; return false }.count }
    var failedCount: Int { items.filter { if case .failed = $0.status { return true }; return false }.count }
    var totalCount: Int { items.count }
    var allDone: Bool { items.allSatisfy { if case .pending = $0.status { return false }; if case .processing = $0.status { return false }; return true } }

    private static let maxConcurrent = 3
    private static let maxRetries = 2

    // MARK: - Process Batch

    /// Process all images as separate receipts with concurrency limit of 3.
    func processBatch(images: [UIImage]) async {
        items = images.map { BatchItem(image: $0) }
        isProcessing = true
        isCancelled = false

        // Process with concurrency limit
        let maxConcurrent = Self.maxConcurrent
        let maxRetries = Self.maxRetries
        let images = items.map { $0.image }

        // Process sequentially in batches of maxConcurrent
        var pendingIndices = Array(items.indices)

        while !pendingIndices.isEmpty && !isCancelled {
            let batch = Array(pendingIndices.prefix(maxConcurrent))
            pendingIndices.removeFirst(min(maxConcurrent, pendingIndices.count))

            // Mark batch as processing
            for index in batch {
                items[index].status = .processing
            }

            // Process batch in parallel
            await withTaskGroup(of: (Int, ItemStatus).self) { group in
                for index in batch {
                    let image = images[index]
                    group.addTask {
                        let result = await self.processOneReceipt(image: image)
                        return (index, result)
                    }
                }

                for await (index, result) in group {
                    items[index].status = result

                    // If failed and retries remaining, re-enqueue
                    if case .failed = result, items[index].retryCount < maxRetries {
                        items[index].retryCount += 1
                        items[index].status = .pending
                        pendingIndices.append(index)
                    }
                }
            }
        }

        isProcessing = false
    }

    /// Retry a single failed item.
    func retryItem(at index: Int) async {
        guard index < items.count, case .failed = items[index].status else { return }
        items[index].status = .processing
        items[index].retryCount += 1
        let result = await processOneReceipt(image: items[index].image)
        items[index].status = result
    }

    /// Cancel processing — already-processed items are kept.
    func cancel() {
        isCancelled = true
    }

    /// Remove a failed or pending item from the batch.
    func removeItem(at index: Int) {
        guard index < items.count else { return }
        items.remove(at: index)
    }

    // MARK: - Single Receipt Processing

    private func processOneReceipt(image: UIImage) async -> ItemStatus {
        do {
            // Process and upload in parallel
            async let aiResult = BackendAPIService.shared.processReceipt(images: [image])
            async let uploadResult = BackendAPIService.shared.uploadImages([image])

            let response = try await aiResult
            let upload = try await uploadResult
            let urls = upload.images.compactMap { $0.success ? $0.url : nil }

            if response.isValid {
                return .success(response, imageUrls: urls)
            } else {
                return .failed(response.message ?? "Could not extract receipt data")
            }
        } catch let error as URLError where error.code == .timedOut {
            return .failed("Request timed out — try again")
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
