import ConfettiSwiftUI
import PhotosUI
import PopupView
import SwiftUI
import StoreKit
import UniformTypeIdentifiers

struct ScannerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    // Track if user has completed their first scan
    @AppStorage("hasCompletedFirstScan") private var hasCompletedFirstScan = false
    @AppStorage("totalScanCount") private var totalScanCount = 0
    @AppStorage("appOpenCount") private var appOpenCount = 0

    // Track if this is the user's very first successful save (for confetti)
    @State private var isFirstEverScan = false
    @State private var confettiCounter = 0

    // Source selection
    @State private var showSourcePicker = true
    @State private var showDocumentScanner = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var showVoiceEntry = false
    @State private var showPreview = false

    // Processing state
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showErrorToast: Bool = false
    @State private var processingTime: TimeInterval?

    // Confirmation flow state
    @State private var showConfirmation = false
    @State private var extractedData: ReceiptProcessingResponse?
    @State private var scannedImages: [UIImage] = []
    @State private var uploadedImageUrls: [String] = []

    // Photo picker
    @State private var selectedPhotos: [PhotosPickerItem] = []

    // Manual entry
    @State private var showManualEntry = false

    // Batch mode
    @State private var isBatchMode = false
    @State private var showBatchConfirmation = false
    @StateObject private var batchProcessor = BatchReceiptProcessor()

    // Scan milestone triggers (after 3rd scan)
    @State private var showPaywallAfterScan = false
    @State private var showNotificationPrompt = false
    @AppStorage("hasPromptedForNotifications") private var hasPromptedForNotifications = false

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var haptics = HapticManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                Color.brandBackground
                    .ignoresSafeArea()

                if isProcessing {
                    processingView
                } else if showPreview {
                    previewView
                } else {
                    sourcePickerView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        haptics.sheetDismissed()
                        dismiss()
                    }
                    .font(.manrope(size: 16, weight: .medium))
                    .foregroundColor(.brandTextSecondary)
                }
            }
            .onAppear {
                // Check if this will be user's first scan (for confetti later)
                isFirstEverScan = !hasCompletedFirstScan

                // If user has already done first scan, go straight to camera
                if hasCompletedFirstScan && subscriptionManager.canScan {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showDocumentScanner = true
                    }
                }
            }
            // Confetti overlay
            .confettiCannon(trigger: $confettiCounter, num: 50, colors: [.brandVibrantBlue, .brandSkyBlue, .brandDeepNavy, .white], rainHeight: 800, radius: 400)
        }
        // Document Scanner Sheet
        .sheet(isPresented: $showDocumentScanner, onDismiss: {
            // When scanner is dismissed without images, show source picker again
            if scannedImages.isEmpty && !isProcessing {
                showSourcePicker = true
            }
        }) {
            DocumentScannerView(
                scannedImages: Binding(
                    get: { [] },
                    set: { images in
                        if !images.isEmpty {
                            haptics.cameraShutter()
                            scannedImages = images
                            showPreview = true
                            showSourcePicker = false
                        }
                        // Always dismiss the scanner - onDismiss will handle showing source picker
                    }
                )
            )
            .ignoresSafeArea()
        }
        // Photo Picker
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 10,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotos) { _, newItems in
            if !newItems.isEmpty {
                Task { await loadPhotos(from: newItems) }
            }
        }
        // File Picker
        .sheet(isPresented: $showFilePicker) {
            DocumentFilePicker { urls in
                if !urls.isEmpty {
                    Task { await processFiles(urls) }
                }
            }
        }
        // Confirmation View
        .fullScreenCover(isPresented: $showConfirmation) {
            if let data = extractedData {
                ReceiptConfirmationView(
                    extractedData: data,
                    imageUrls: uploadedImageUrls,
                    scannedImages: scannedImages,
                    isFirstScan: isFirstEverScan,
                    onSave: { receipt in
                        Task { await saveReceipt(receipt) }
                    },
                    onCancel: {
                        resetState()
                        dismiss()
                    }
                )
            }
        }
        // Manual Entry View
        .fullScreenCover(isPresented: $showManualEntry) {
            ManualReceiptEntryView(
                onSave: { receipt in
                    Task { await saveReceipt(receipt) }
                },
                onCancel: {
                    // Just dismiss, no reset needed
                }
            )
        }
        // Voice Entry View
        .sheet(isPresented: $showVoiceEntry) {
            VoiceEntryView(
                onSave: { receipt in
                    Task { await saveReceipt(receipt) }
                },
                onCancel: {
                    showVoiceEntry = false
                }
            )
        }
        // Batch Confirmation View
        .fullScreenCover(isPresented: $showBatchConfirmation) {
            BatchConfirmationView(
                processor: batchProcessor,
                onSaveAll: { receipts in
                    Task { await saveBatchReceipts(receipts) }
                },
                onCancel: {
                    batchProcessor.cancel()
                    resetState()
                    dismiss()
                }
            )
        }
        // Error Toast
        .popup(isPresented: $showErrorToast) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text(errorMessage ?? "Backend error")
                    .foregroundColor(.white)
                    .font(.manrope(size: 14, weight: .medium))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color.black.opacity(0.85))
            .cornerRadius(30)
            .padding(.top, 60)
        } customize: {
            $0
                .type(.floater())
                .position(.top)
                .animation(.spring())
                .autohideIn(3)
        }
        .onChange(of: showErrorToast) { _, isShowing in
            if isShowing {
                haptics.error()
            }
        }
        .onChange(of: scannedImages) { _, images in
            if showPreview && images.isEmpty {
                showPreview = false
                showSourcePicker = true
            }
        }
        // Paywall after 3rd scan (delayed to let user see their success)
        .sheet(isPresented: $showPaywallAfterScan) {
            PaywallView()
        }
        // Contextual notification permission prompt (native iOS alert)
        .alert("Stay on Track", isPresented: $showNotificationPrompt) {
            Button("Enable") {
                Task {
                    _ = await NotificationManager.shared.requestAuthorization()
                }
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Get weekly spending summaries and smart reminders to scan your receipts.")
        }
    }

    // MARK: - Source Picker View

    private var sourcePickerView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Spacer(minLength: 40)

                // Hero section
                ZStack {
                    MeshGradient.brandHero
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 32))

                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white)
                }
                .shadow(color: Color.brandVibrantBlue.opacity(0.3), radius: 20, x: 0, y: 10)

                // Title and description
                VStack(spacing: 10) {
                    if !hasCompletedFirstScan {
                        Text("Scan Your First Receipt")
                            .font(.instrumentSerifItalic(size: 26))
                            .foregroundColor(.brandTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("Capture a receipt and we'll extract all the details automatically.")
                            .font(.manrope(size: 15, weight: .regular))
                            .foregroundColor(.brandTextSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    } else {
                        Text("Add Receipt")
                            .font(.instrumentSerifItalic(size: 26))
                            .foregroundColor(.brandTextPrimary)

                        Text("Scan or upload your receipt")
                            .font(.manrope(size: 15, weight: .regular))
                            .foregroundColor(.brandTextSecondary)
                    }
                }
                .padding(.horizontal, 24)

                // Source options
                VStack(spacing: 12) {
                    // Scan Receipt Button (Primary)
                    Brand3DButton(title: "Scan Receipt", icon: "camera.fill", style: .primary) {
                        startScanning()
                    }

                    // Upload from Photos
                    Brand3DButton(title: "Choose from Photos", icon: "photo.on.rectangle", style: .secondary) {
                        haptics.buttonPress()
                        if checkScanLimit() {
                            showPhotoPicker = true
                        }
                    }

                    // Import from Files
                    Brand3DButton(title: "Import from Files", icon: "folder", style: .secondary) {
                        haptics.buttonPress()
                        if checkScanLimit() {
                            showFilePicker = true
                        }
                    }

                    // Voice Entry
                    Brand3DButton(title: "Speak It", icon: "mic.fill", style: .secondary) {
                        haptics.buttonPress()
                        if checkScanLimit() {
                            showVoiceEntry = true
                        }
                    }

                    // Batch mode toggle
                    HStack {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isBatchMode ? .brandVibrantBlue : .brandTextTertiary)
                        Text("Batch Mode")
                            .font(.manrope(size: 14, weight: .medium))
                            .foregroundColor(isBatchMode ? .brandVibrantBlue : .brandTextSecondary)
                        Spacer()
                        Toggle("", isOn: $isBatchMode)
                            .labelsHidden()
                            .tint(.brandVibrantBlue)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isBatchMode ? Color.brandVibrantBlue.opacity(0.08) : Color.brandSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isBatchMode ? Color.brandVibrantBlue.opacity(0.3) : Color.brandBorder, lineWidth: 1)
                            )
                    )
                    .animation(.brandSnappy, value: isBatchMode)

                    if isBatchMode {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text("Select multiple photos — each will be processed as a separate receipt")
                                .font(.manrope(size: 12, weight: .regular))
                        }
                        .foregroundColor(.brandVibrantBlue)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Divider with "or" text
                    HStack {
                        Rectangle()
                            .fill(Color.brandBorder)
                            .frame(height: 1)
                        Text("or")
                            .font(.manrope(size: 13, weight: .medium))
                            .foregroundColor(.brandTextTertiary)
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(Color.brandBorder)
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    // Manual Entry Button (FREE - no scan limit check)
                    Brand3DButton(title: "Enter Manually", icon: "pencil.line", style: .secondary) {
                        haptics.buttonPress()
                        showManualEntry = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Multi-page hint
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("Tip: Scan to auto-extract, or enter manually for free")
                        .font(.manrope(size: 12, weight: .medium))
                }
                .foregroundColor(.brandTextTertiary)
                .padding(.top, 16)

                // Weekly usage indicator (for free users)
                if !subscriptionManager.isPlus {
                    weeklyUsageIndicator
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        // Enhanced contextual processing view with step-by-step progress
        ReceiptProcessingView(pageCount: scannedImages.count)
    }

    // MARK: - Preview View

    private var previewView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                VStack(spacing: 6) {
                    Text("Review Photos")
                        .font(.instrumentSerifItalic(size: 26))
                        .foregroundColor(.brandTextPrimary)

                    Text("Swipe to remove or open the grid to compare sizes.")
                        .font(.manrope(size: 14, weight: .regular))
                        .foregroundColor(.brandTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                ReceiptImageStack(
                    images: $scannedImages,
                    onDelete: { index in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            let removalIndex = scannedImages.index(scannedImages.startIndex, offsetBy: index)
                            scannedImages.remove(at: removalIndex)
                        }
                    },
                    showsAddButton: true,
                    addButton: {
                        Button {
                            haptics.buttonPress()
                            showPreview = false
                            showSourcePicker = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Add More")
                                    .font(.manrope(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.brandVibrantBlue)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.brandIceBlue)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.brandBorder, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                )
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    if isBatchMode && scannedImages.count > 1 {
                        Brand3DButton(
                            title: "Process \(scannedImages.count) Receipts",
                            icon: "sparkles",
                            style: .primary
                        ) {
                            Task { await startBatchProcessing() }
                        }
                    } else {
                        Brand3DButton(title: "Process Receipt", icon: "sparkles", style: .primary) {
                            Task { await processScannedImages(scannedImages) }
                        }
                    }

                    Brand3DButton(title: "Discard", icon: "xmark", style: .secondary) {
                        haptics.buttonPress()
                        scannedImages = []
                        showPreview = false
                        showSourcePicker = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer(minLength: 24)
            }
        }
    }

    // MARK: - Weekly Usage Indicator

    private var weeklyUsageIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .medium))
                Text(subscriptionManager.scansUsedText)
                    .font(.manrope(size: 13, weight: .medium))
                Spacer()
                Button {
                    haptics.buttonPress()
                    // Dismiss scanner sheet first, then show paywall
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let trigger: PaywallTrigger = subscriptionManager.canScan ? .settingsUpgrade : .scanLimitReached
                        subscriptionManager.presentPaywall(trigger: trigger)
                    }
                } label: {
                    Text("Upgrade")
                        .font(.manrope(size: 12, weight: .semibold))
                        .foregroundColor(.brandVibrantBlue)
                }
            }
            .foregroundColor(.brandTextSecondary)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.brandBorder)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(usageBarColor)
                        .frame(width: geo.size.width * usageProgress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }

    private var usageProgress: CGFloat {
        let limit = subscriptionManager.subscriptionStatus.tier.weeklyScansLimit ?? 5
        return CGFloat(subscriptionManager.scanUsage.scansThisWeek) / CGFloat(limit)
    }

    private var usageBarColor: Color {
        if usageProgress >= 1.0 {
            return .brandError
        } else if usageProgress >= 0.8 {
            return .brandWarning
        }
        return .brandVibrantBlue
    }

    // MARK: - Actions

    private func checkScanLimit() -> Bool {
        if !subscriptionManager.canScan {
            haptics.warning()
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                subscriptionManager.presentPaywall(trigger: .scanLimitReached)
            }
            return false
        }
        return true
    }

    private func startScanning() {
        haptics.buttonPress()

        if !checkScanLimit() { return }

        showDocumentScanner = true
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }

        await MainActor.run { selectedPhotos = [] }

        if !images.isEmpty {
            await MainActor.run {
                scannedImages = images
                showPreview = true
                showSourcePicker = false
            }
        }
    }

    private func processFiles(_ urls: [URL]) async {
        var images: [UIImage] = []

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            if url.pathExtension.lowercased() == "pdf" {
                // Convert PDF pages to images
                if let pdfImages = extractImagesFromPDF(url: url) {
                    images.append(contentsOf: pdfImages)
                }
            } else if let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) {
                images.append(image)
            }
        }

        if !images.isEmpty {
            await MainActor.run {
                scannedImages = images
                showPreview = true
                showSourcePicker = false
            }
        }
    }

    private func extractImagesFromPDF(url: URL) -> [UIImage]? {
        guard let document = CGPDFDocument(url as CFURL) else { return nil }

        var images: [UIImage] = []
        let pageCount = document.numberOfPages

        for i in 1...pageCount {
            guard let page = document.page(at: i) else { continue }

            let pageRect = page.getBoxRect(.mediaBox)
            let scale: CGFloat = 2.0 // Higher quality
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: scaledSize))

                ctx.cgContext.translateBy(x: 0, y: scaledSize.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                ctx.cgContext.drawPDFPage(page)
            }

            images.append(image)
        }

        return images.isEmpty ? nil : images
    }

    private func processScannedImages(_ images: [UIImage]) async {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            showErrorToast = false
            processingTime = nil
            scannedImages = images
        }

        let startTime = Date()

        do {
            // 1. Process Receipt (AI Extraction) and Upload Images in parallel
            async let aiResult = BackendAPIService.shared.processReceipt(images: images)
            async let uploadResult = BackendAPIService.shared.uploadImages(images)

            let res = try await aiResult
            let uploadRes = try await uploadResult

            let duration = Date().timeIntervalSince(startTime)
            await MainActor.run { processingTime = duration }
            print("⏱️ [Receipt] Processing took: \(duration)s")

            // Extract successful URLs
            let urls = uploadRes.images.compactMap { $0.success ? $0.url : nil }
            await MainActor.run { uploadedImageUrls = urls }

            if urls.isEmpty {
                print("⚠️ [Receipt] Image upload failed, saving without images.")
            }

            if res.isValid {
                // Haptic for successful extraction
                haptics.ascendingSuccess()

                await MainActor.run {
                    // Store extracted data and show confirmation
                    extractedData = res
                    isProcessing = false
                    showConfirmation = true
                }
            } else {
                haptics.error()
                await MainActor.run {
                    errorMessage = res.message ?? "Invalid receipt - couldn't extract data"
                    showErrorToast = true
                    isProcessing = false
                }
            }
        } catch {
            haptics.error()
            await MainActor.run {
                errorMessage = "Processing failed: \(error.localizedDescription)"
                showErrorToast = true
                isProcessing = false
            }
        }
    }

    private func saveReceipt(_ receipt: Receipt) async {
        do {
            // Record the scan (for usage tracking)
            _ = subscriptionManager.checkAndRecordScan()

            // Determine where to save based on subscription status
            if subscriptionManager.hasCloudWriteAccess {
                // Plus users: save to Supabase cloud
                _ = try await SupabaseManager.shared.createReceipt(receipt)
                print("✅ [Receipt] Saved to cloud: \(receipt.store_name)")
            } else {
                // Free users: save locally
                LocalReceiptStorage.shared.saveReceipt(receipt)
                print("✅ [Receipt] Saved locally: \(receipt.store_name)")
            }

            // Mark first scan complete & Request Review
            let wasFirstScan = isFirstEverScan
            await MainActor.run {
                hasCompletedFirstScan = true
                totalScanCount += 1

                // Smart Rating Request: after first scan + at least 3 app opens
                if totalScanCount == 1 && appOpenCount >= 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            AppStore.requestReview(in: scene)
                        }
                    }
                }

                // 3rd scan milestone: Show paywall (if free) and notification prompt (if not prompted)
                if totalScanCount == 3 {
                    // Show paywall after 3rd scan if free user
                    if !subscriptionManager.isPlus {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showPaywallAfterScan = true
                        }
                    }

                    // Prompt for notifications if not already prompted and not authorized
                    if !hasPromptedForNotifications && !NotificationManager.shared.isAuthorized {
                        hasPromptedForNotifications = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showNotificationPrompt = true
                        }
                    }
                }
            }

            // Recompute insights after save
            let allReceipts: [Receipt] = subscriptionManager.hasCloudWriteAccess
                ? (try? await SupabaseManager.shared.fetchReceipts(page: 1, limit: 200)) ?? []
                : LocalReceiptStorage.shared.getAllReceipts()
            InsightsEngine.shared.recompute(receipts: allReceipts)

            // Success haptic
            haptics.chaChing()

            // Trigger confetti for first scan!
            if wasFirstScan {
                await MainActor.run {
                    confettiCounter += 1
                }
                // Wait a moment for confetti to show
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            }

            // Reset state and dismiss
            resetState()
            dismiss()
        } catch {
            haptics.error()
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                showErrorToast = true
            }
        }
    }

    // MARK: - Batch Processing

    private func startBatchProcessing() async {
        haptics.buttonPress()
        await MainActor.run {
            showPreview = false
            showBatchConfirmation = true
        }
        await batchProcessor.processBatch(images: scannedImages)
    }

    private func saveBatchReceipts(_ receipts: [Receipt]) async {
        for receipt in receipts {
            await saveReceipt(receipt)
        }
    }

    private func resetState() {
        extractedData = nil
        scannedImages = []
        uploadedImageUrls = []
        showConfirmation = false
        showBatchConfirmation = false
        selectedPhotos = []
        showPreview = false
        showSourcePicker = true
    }
}
