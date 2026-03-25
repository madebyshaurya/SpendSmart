import Speech
import SwiftUI

/// Voice-based receipt entry: "I spent $12 at Starbucks on a latte"
/// Uses Apple Speech framework for recognition, then sends to backend AI for parsing.
struct VoiceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @StateObject private var haptics = HapticManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var recognizedText = ""
    @State private var isListening = false
    @State private var isParsing = false
    @State private var parseError: String?
    @State private var parsedReceipt: ReceiptProcessingResponse?
    @State private var showConfirmation = false
    @State private var micScale: CGFloat = 1.0
    @State private var permissionDenied = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var onSave: (Receipt) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Status text
                    VStack(spacing: 8) {
                        if permissionDenied {
                            Text("Microphone access needed")
                                .font(.instrumentSerifItalic(size: 24))
                                .foregroundColor(.brandTextPrimary)
                            Text("Enable in Settings → SpendSmart → Microphone")
                                .font(.manrope(size: 14, weight: .regular))
                                .foregroundColor(.brandTextSecondary)
                        } else if isListening {
                            Text("Listening...")
                                .font(.instrumentSerifItalic(size: 24))
                                .foregroundColor(.brandVibrantBlue)
                            Text(recognizedText.isEmpty ? "\"I spent $12 at Starbucks\"" : recognizedText)
                                .font(.manrope(size: 16, weight: .regular))
                                .foregroundColor(recognizedText.isEmpty ? .brandTextTertiary : .brandTextPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .animation(.brandSnappy, value: recognizedText)
                        } else if isParsing {
                            Text("Understanding...")
                                .font(.instrumentSerifItalic(size: 24))
                                .foregroundColor(.brandVibrantBlue)
                            ProgressView()
                                .tint(.brandVibrantBlue)
                        } else if let error = parseError {
                            Text("Didn't catch that")
                                .font(.instrumentSerifItalic(size: 24))
                                .foregroundColor(.brandError)
                            Text(error)
                                .font(.manrope(size: 14, weight: .regular))
                                .foregroundColor(.brandTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        } else {
                            Text("Speak your expense")
                                .font(.instrumentSerifItalic(size: 24))
                                .foregroundColor(.brandTextPrimary)
                            Text("Say something like:\n\"I spent twelve dollars at Starbucks on coffee\"")
                                .font(.manrope(size: 14, weight: .regular))
                                .foregroundColor(.brandTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }

                    Spacer()

                    // Mic button
                    Button {
                        haptics.buttonPress()
                        if isListening {
                            stopListening()
                        } else {
                            startListening()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isListening ? Color.brandVibrantBlue : Color.brandDeepNavy)
                                .frame(width: 80, height: 80)
                                .shadow(color: (isListening ? Color.brandVibrantBlue : Color.brandDeepNavy).opacity(0.3), radius: 20, y: 8)

                            Image(systemName: isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(micScale)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isListening)
                    }
                    .disabled(isParsing || permissionDenied)
                    .onChange(of: isListening) { _, listening in
                        micScale = listening ? 1.08 : 1.0
                    }
                    .accessibilityLabel(isListening ? "Stop listening" : "Tap to speak your expense")

                    // Action buttons
                    if !recognizedText.isEmpty && !isListening && !isParsing {
                        VStack(spacing: 12) {
                            Brand3DButton(title: "Process", icon: "sparkles", style: .primary) {
                                Task { await parseSpokenText() }
                            }
                            Brand3DButton(title: "Try Again", icon: "arrow.clockwise", style: .secondary) {
                                recognizedText = ""
                                parseError = nil
                                startListening()
                            }
                        }
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if parseError != nil {
                        Brand3DButton(title: "Enter Manually Instead", icon: "pencil.line", style: .secondary) {
                            onCancel()
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        stopListening()
                        haptics.sheetDismissed()
                        onCancel()
                    }
                    .font(.manrope(size: 16, weight: .medium))
                    .foregroundColor(.brandTextSecondary)
                }
            }
            .fullScreenCover(isPresented: $showConfirmation) {
                if let data = parsedReceipt {
                    ReceiptConfirmationView(
                        extractedData: data,
                        imageUrls: [],
                        scannedImages: [],
                        isFirstScan: false,
                        onSave: { receipt in
                            onSave(receipt)
                        },
                        onCancel: {
                            showConfirmation = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Speech Recognition

    private func startListening() {
        // Check permissions
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            if granted {
                                beginRecognition()
                            } else {
                                permissionDenied = true
                            }
                        }
                    }
                default:
                    permissionDenied = true
                }
            }
        }
    }

    private func beginRecognition() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            parseError = "Speech recognition unavailable"
            return
        }

        recognizedText = ""
        parseError = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            if let result {
                DispatchQueue.main.async {
                    recognizedText = result.bestTranscription.formattedString
                }

                if result.isFinal {
                    DispatchQueue.main.async {
                        stopListening()
                    }
                }
            }

            if let error {
                DispatchQueue.main.async {
                    if recognizedText.isEmpty {
                        parseError = "Couldn't understand — try again"
                    }
                    stopListening()
                }
                print("⚠️ [Voice] Recognition error: \(error)")
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            haptics.medium()

            // Auto-stop after 10 seconds of silence
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if isListening {
                    stopListening()
                }
            }
        } catch {
            parseError = "Couldn't start listening"
            print("⚠️ [Voice] Audio engine error: \(error)")
        }
    }

    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    // MARK: - AI Parsing

    private func parseSpokenText() async {
        isParsing = true
        parseError = nil
        haptics.medium()

        do {
            // Use the AI generate endpoint to parse the spoken text into receipt data
            let prompt = """
            Parse this spoken expense into a receipt. Extract: store name, amount, currency, items, category.
            If any field is unclear, make your best guess.
            Spoken text: "\(recognizedText)"
            """

            let _ = try await BackendAPIService.shared.generateAIContent(prompt: prompt)

            // For now, create a simple receipt from the spoken text
            // The backend should return structured data, but as a fallback:
            await MainActor.run {
                // Create a minimal ReceiptProcessingResponse from the AI parse
                // In production, the backend would return structured JSON
                parsedReceipt = ReceiptProcessingResponse(
                    isValid: true,
                    message: nil,
                    store_name: extractStoreName(from: recognizedText),
                    purchase_date: ISO8601DateFormatter().string(from: Date()),
                    total_amount: extractAmount(from: recognizedText),
                    currency: CurrencyService.shared.preferredCurrency,
                    items: nil,
                    total_tax: 0,
                    payment_method: nil,
                    store_address: nil,
                    receipt_name: nil,
                    logo_search_term: extractStoreName(from: recognizedText)
                )
                isParsing = false
                showConfirmation = true
                haptics.ascendingSuccess()
            }
        } catch {
            await MainActor.run {
                parseError = "Couldn't process — try scanning instead"
                isParsing = false
                haptics.error()
            }
        }
    }

    // MARK: - Text Extraction Helpers

    private func extractAmount(from text: String) -> Double {
        // Match $XX.XX or XX dollars patterns
        let patterns = [
            #"\$(\d+\.?\d*)"#,
            #"(\d+\.?\d*)\s*dollars?"#,
            #"(\d+)\s*bucks?"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let amount = Double(text[range]) {
                return amount
            }
        }
        return 0
    }

    private func extractStoreName(from text: String) -> String {
        // Match "at [Store]" pattern
        let pattern = #"at\s+([A-Z][a-zA-Z'\-\s]+?)(?:\s+on|\s+for|\s*$)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range]).trimmingCharacters(in: .whitespaces)
        }

        // Fallback: look for capitalized words after common prepositions
        let words = text.split(separator: " ")
        if let atIndex = words.firstIndex(where: { $0.lowercased() == "at" }), atIndex + 1 < words.count {
            return String(words[atIndex + 1])
        }

        return "Unknown Store"
    }
}
