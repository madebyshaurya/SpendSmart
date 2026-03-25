import SwiftUI

// MARK: - Chat View Model

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messageText = ""
    @Published var messages: [ChatMessage] = []
    @Published var isThinking = false
    @Published var forceChartsEnabled = false
    @AppStorage("chatMessageCount") private var chatMessageCount = 0
    @AppStorage("chatCountDate") private var chatCountDate = ""
    @Published var isRateLimited = false
    private let freeDailyLimit = 5

    private let haptics = HapticManager.shared

    let quickPrompts = [
        "How much did I spend this month?",
        "What are my active subscriptions?",
        "Show me my top 5 expenses",
        "How much on coffee vs transport?",
        "Any recurring payments coming up?",
        "What's my biggest expense recently?",
        "Total spent on groceries?"
    ]

    func checkChatLimit() -> Bool {
        guard !SubscriptionManager.shared.isPlus else { return true }
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if chatCountDate != today {
            chatCountDate = today
            chatMessageCount = 0
        }
        if chatMessageCount >= freeDailyLimit {
            isRateLimited = true
            return false
        }
        chatMessageCount += 1
        return true
    }

    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard checkChatLimit() else { return }

        let content = messageText
        let userMsg = ChatMessage(role: .user, content: content)
        messages.append(userMsg)
        messageText = ""
        isThinking = true
        haptics.light()

        Task {
            do {
                // Convert messages to history format
                let history = messages.dropLast().map { [
                    "role": $0.role == .user ? "user" : "assistant",
                    "content": $0.content
                ] }

                let response = try await BackendAPIService.shared.chatWithExpenses(
                    message: content,
                    history: history,
                    forceCharts: forceChartsEnabled
                )

                let aiMsg = ChatMessage(
                    role: .assistant,
                    content: response.text,
                    chart: response.chart
                )

                await MainActor.run {
                    // Extra haptic when chart is present
                    if response.chart != nil {
                        haptics.ascendingSuccess()
                        // Second haptic for chart
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            self.haptics.light()
                        }
                    } else {
                        haptics.ascendingSuccess()
                    }
                    messages.append(aiMsg)
                    isThinking = false
                }
            } catch {
                await MainActor.run {
                    haptics.error()
                    let errorMsg = ChatMessage(role: .assistant, content: "Sorry, I encountered an error: \(error.localizedDescription)")
                    messages.append(errorMsg)
                    isThinking = false
                }
            }
        }
    }
}
