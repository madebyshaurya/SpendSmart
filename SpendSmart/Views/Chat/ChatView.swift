import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @StateObject private var haptics = HapticManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Welcome Message
                        if viewModel.messages.isEmpty {
                            welcomeView
                        }
                        
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                        
                        if viewModel.isThinking {
                            thinkingIndicator
                        }
                    }
                    .padding(.vertical)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .modifier(ScrollEdgeEffectModifier())
                .background(Color.brandBackground)
                .onChange(of: viewModel.messages.count) {
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation(.spring(response: 0.3)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            .onTapGesture {
                isInputFocused = false
            }
            
            // Quick Prompts Horizontal Scroll
            quickPromptsView
            
            // Input Area
            inputArea
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brandVibrantBlue, Color.brandDeepNavy],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Assistant")
                    .font(.manrope(size: 18, weight: .bold))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text("Ask anything about your spending")
                    .font(.manrope(size: 12, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            Color.brandSurface
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 40)
            
            ZStack {
                Circle()
                    .fill(Color.brandAccentLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Color.brandVibrantBlue)
                        .symbolEffect(.breathe)
            }
            
            VStack(spacing: 8) {
                Text("Hi, I'm your AI assistant!")
                    .font(.instrumentSerifItalic(size: 24))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text("Ask me anything about your\nexpenses and subscriptions")
                    .multilineTextAlignment(.center)
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)
                    .lineSpacing(4)
            }
            
            // Example questions
            VStack(alignment: .leading, spacing: 8) {
                Text("Try asking:")
                    .font(.manrope(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
                
                ForEach(["How much did I spend this week?", "What's my biggest expense?", "Show me grocery spending"], id: \.self) { example in
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.brandVibrantBlue)
                        
                        Text(example)
                            .font(.manrope(size: 13, weight: .medium))
                            .foregroundStyle(Color.brandTextSecondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Thinking Indicator
    
    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.brandVibrantBlue)
                        .frame(width: 8, height: 8)
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.brandSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )
            )
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Quick Prompts
    
    private var quickPromptsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.quickPrompts, id: \.self) { prompt in
                    Button {
                        haptics.buttonPress()
                        viewModel.messageText = prompt
                        isInputFocused = false
                        viewModel.sendMessage()
                    } label: {
                        Text(prompt)
                            .font(.manrope(size: 12, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.brandAccentLight)
                            )
                            .foregroundStyle(Color.brandVibrantBlue)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color.brandSurface)
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: 10) {
            if viewModel.isRateLimited {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                    Text("5 free messages today. Upgrade for unlimited.")
                        .font(.manrope(size: 13, weight: .medium))
                    Spacer()
                    Button("View Plans") {
                        SubscriptionManager.shared.presentPaywall(trigger: .settingsUpgrade)
                    }
                    .font(.manrope(size: 13, weight: .bold))
                    .foregroundColor(.brandVibrantBlue)
                }
                .foregroundColor(.brandTextSecondary)
                .padding(12)
                .background(Color.brandSurface)
            }

            // Charts toggle chip row
            HStack {
                chartsToggleChip
                Spacer()
            }
            .padding(.horizontal, 4)

            // Text input and send button row
            HStack(spacing: 12) {
                // Text field
                HStack(spacing: 10) {
                    TextField("Ask about your spending...", text: $viewModel.messageText)
                        .font(.manrope(size: 15))
                        .foregroundStyle(Color.brandTextPrimary)
                        .focused($isInputFocused)
                        .disabled(viewModel.isThinking || viewModel.isRateLimited)
                        .onSubmit {
                            isInputFocused = false
                            viewModel.sendMessage()
                        }
                    
                    if !viewModel.messageText.isEmpty {
                        Button {
                            viewModel.messageText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.brandTextTertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.brandSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                )
                
                // Send button
                Button {
                    haptics.buttonPress()
                    isInputFocused = false
                    viewModel.sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.messageText.isEmpty || viewModel.isThinking ? Color.brandBorder : Color.brandVibrantBlue)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(viewModel.messageText.isEmpty || viewModel.isThinking || viewModel.isRateLimited)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            Color.brandBackground
                .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
        )
    }
    
    // MARK: - Charts Toggle Chip
    
    private var chartsToggleChip: some View {
        Button {
            haptics.buttonPress()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.forceChartsEnabled.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Charts")
                    .font(.manrope(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(viewModel.forceChartsEnabled ? Color.brandVibrantBlue : Color.brandSurface)
            )
            .foregroundStyle(viewModel.forceChartsEnabled ? .white : Color.brandTextSecondary)
            .overlay(
                Capsule()
                    .stroke(viewModel.forceChartsEnabled ? Color.clear : Color.brandBorder, lineWidth: 1)
            )
        }
        .scaleEffect(viewModel.forceChartsEnabled ? 1.05 : 1.0)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
                
                Text(message.content)
                    .font(.manrope(size: 15, weight: .regular))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.brandVibrantBlue, Color.brandRoyalBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .clipShape(MessageBubbleShape(isFromUser: true))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // AI label
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                        Text("AI")
                            .font(.manrope(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.brandVibrantBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.brandAccentLight)
                    )
                    
                    // Message content (with Markdown support)
                    Text(.init(message.content))
                        .font(.manrope(size: 15, weight: .regular))
                        .foregroundStyle(Color.brandTextPrimary)
                        .lineSpacing(4)
                    
                    // Chart bubble if present
                    if let chart = message.chart, chart.hasValidData {
                        ChartBubble(chart: chart, height: 180)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.brandSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                )
                .clipShape(MessageBubbleShape(isFromUser: false))
                
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Message Bubble Shape

struct MessageBubbleShape: Shape {
    let isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 20
        let tailSize: CGFloat = 8
        
        var path = Path()
        
        if isFromUser {
            // User message - tail on right
            path.addRoundedRect(
                in: CGRect(x: 0, y: 0, width: rect.width - tailSize/2, height: rect.height),
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
        } else {
            // AI message - tail on left
            path.addRoundedRect(
                in: CGRect(x: tailSize/2, y: 0, width: rect.width - tailSize/2, height: rect.height),
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
        }
        
        return path
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - iOS 26 Availability Wrapper

private struct ScrollEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content
        }
    }
}

#Preview {
    ChatView()
}
