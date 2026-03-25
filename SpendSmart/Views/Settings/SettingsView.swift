import Charts
import Combine
import PopupView
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var localStorage = LocalReceiptStorage.shared
    @StateObject private var haptics = HapticManager.shared
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @AppStorage("userEmoji") private var userEmoji: String = "😊"
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @State private var showEmojiPicker = false
    @State private var showCurrencyPicker = false
    @State private var showSyncConfirmation = false
    @State private var showExportSheet = false
    @State private var showShareSheet = false
    @State private var showDeleteAccountSheet = false
    
    // Callback for upgrade button - allows parent to handle paywall after dismissing settings
    var onUpgradeTapped: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                SettingsProfileSection(
                    viewModel: viewModel,
                    userEmoji: $userEmoji,
                    showEmojiPicker: $showEmojiPicker,
                    onHaptic: { haptics.buttonPress() }
                )
                SettingsUsageSection(subscriptionManager: subscriptionManager)
                SettingsStorageSection(
                    subscriptionManager: subscriptionManager,
                    localStorage: localStorage,
                    showSyncConfirmation: $showSyncConfirmation,
                    onHaptic: { haptics.buttonPress() },
                    onUpgradeTapped: onUpgradeTapped
                )
                SettingsDataExportSection(
                    subscriptionManager: subscriptionManager,
                    showExportSheet: $showExportSheet,
                    onHaptic: { haptics.buttonPress() }
                )
                subscriptionSection
                preferencesSection
                accountSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        haptics.buttonPress()
                        dismiss()
                    }
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandVibrantBlue)
                }
            }
            .alert("Delete Account?", isPresented: $viewModel.showDeleteConfirmation) {
                TextField("Type DELETE ACCOUNT", text: $viewModel.deleteConfirmationText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button("Delete", role: .destructive) {
                    viewModel.deleteAccount(appState: appState)
                }
                .disabled(!viewModel.isDeleteConfirmed)

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. Type DELETE ACCOUNT to confirm.")
            }
            .alert("Before you delete", isPresented: $viewModel.showDeleteWarning) {
                Button("I Understand", role: .destructive) {
                    viewModel.showDeleteConfirmation = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "All receipts saved in the cloud will be permanently deleted, and your local receipts will be cleared. Your SpendSmart access will be removed on this account; manage any active subscription in the App Store."
                )
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selectedCurrency: $currencyCode)
            }
            .sheet(isPresented: $showExportSheet) {
                DataExportSheet(
                    isExporting: $viewModel.isExporting,
                    onExport: { format in
                        Task {
                            await viewModel.exportData(format: format, currencyCode: currencyCode, localStorage: localStorage)
                        }
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = viewModel.exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .onChange(of: viewModel.exportedFileURL) {
            if viewModel.exportedFileURL != nil {
                showExportSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showShareSheet = true
                }
            }
        }
        .popup(isPresented: $viewModel.showToast) {
            toastView
        } customize: {
            $0
                .type(.floater())
                .position(.top)
                .animation(.spring())
                .autohideIn(2.5)
        }
    }

    // MARK: - Sections

    private var preferencesSection: some View {
        Section("Preferences") {
            // Notifications
            NavigationLink {
                NotificationSettingsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.brandWarning)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.manrope(size: 15, weight: .medium))
                            .foregroundStyle(Color.brandTextPrimary)
                        Text("Spending alerts & reminders")
                            .font(.manrope(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Haptics toggle
            Toggle(isOn: $hapticsEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.brandVibrantBlue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haptic Feedback")
                            .font(.manrope(size: 15, weight: .medium))
                        Text("Feel taps and vibrations")
                            .font(.manrope(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(Color.brandVibrantBlue)
            .onChange(of: hapticsEnabled) { _, newValue in
                if newValue {
                    // Give a little demo haptic when enabled
                    haptics.success()
                }
            }
            
            // Currency picker button
            Button {
                haptics.buttonPress()
                showCurrencyPicker = true
            } label: {
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.brandVibrantBlue)
                            .frame(width: 24)
                        
                        Text("Currency")
                            .font(.manrope(size: 15, weight: .medium))
                            .foregroundStyle(Color.brandTextPrimary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text(CurrencyData.flag(for: currencyCode))
                        Text(currencyCode)
                            .font(.manrope(size: 14, weight: .medium))
                            .foregroundStyle(Color.brandTextSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Subscription Section
    
    private var subscriptionSection: some View {
        Section {
            if subscriptionManager.isPlus {
                // Plus user - show status
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.brandPrimary)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("SpendSmart Plus")
                                .font(.manrope(size: 16, weight: .semibold))
                                .foregroundStyle(Color.brandTextPrimary)
                            
                            Text("Active")
                                .font(.manrope(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.brandSuccess)
                                .clipShape(Capsule())
                        }
                        
                        if let expirationDate = subscriptionManager.subscriptionStatus.expirationDate {
                            Text(subscriptionManager.subscriptionStatus.willRenew ? "Renews \(expirationDate.formatted(date: .abbreviated, time: .omitted))" : "Expires \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.manrope(size: 13))
                                .foregroundStyle(Color.brandTextSecondary)
                        } else {
                            Text("Unlimited scans")
                                .font(.manrope(size: 13))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                
                // Manage subscription
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Manage Subscription")
                            .foregroundStyle(Color.brandVibrantBlue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                // Free user - show upgrade prompt
                Button {
                    haptics.buttonPress()
                    // Use callback if provided, otherwise show paywall directly
                    if let onUpgradeTapped = onUpgradeTapped {
                        onUpgradeTapped()
                    } else {
                        subscriptionManager.presentPaywall(trigger: .settingsUpgrade)
                    }
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.brandAccentLight)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.brandVibrantBlue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to Plus")
                                .font(.manrope(size: 16, weight: .semibold))
                                .foregroundStyle(Color.brandTextPrimary)
                            
                            Text(subscriptionManager.scansUsedText)
                                .font(.manrope(size: 13))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                // Restore purchases
                Button {
                    Task {
                        try? await subscriptionManager.restorePurchases()
                    }
                } label: {
                    HStack {
                        Text("Restore Purchases")
                            .foregroundStyle(Color.brandVibrantBlue)
                        Spacer()
                        if subscriptionManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                }
                .disabled(subscriptionManager.isLoading)
            }
        } header: {
            Text("Subscription")
        }
    }

    private var accountSection: some View {
        Section {
            Button(role: .destructive) {
                haptics.destructive()
                viewModel.signOut(appState: appState)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.brandError)
                        .frame(width: 24)
                    
                    Text("Sign Out")
                        .font(.manrope(size: 15, weight: .medium))
                        .foregroundStyle(Color.brandError)
                }
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                haptics.destructive()
                showDeleteAccountSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.brandError)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Account")
                            .font(.manrope(size: 15, weight: .medium))
                            .foregroundStyle(Color.brandError)
                        
                        Text("Permanently remove all data")
                            .font(.manrope(size: 12, weight: .regular))
                            .foregroundStyle(Color.brandTextSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Actions")
        }
        .sheet(isPresented: $showDeleteAccountSheet) {
            DeleteAccountSheet {
                viewModel.deleteAccount(appState: appState)
            }
            .presentationDetents([.large])
        }
    }


    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                HStack {
                    Text("Build")
                    Spacer()
                    Text(build)
                        .foregroundStyle(.secondary)
                }
            }
            
            // User ID
            if let userId = SupabaseManager.shared.session?.user.id {
                Button {
                    UIPasteboard.general.string = userId.uuidString
                    haptics.success()
                    viewModel.presentToast("User ID Copied")
                } label: {
                    HStack {
                        Text("User ID")
                        Spacer()
                        Text(userId.uuidString.prefix(8) + "...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Check for Updates
            Button {
                haptics.buttonPress()
                Task { await viewModel.checkForUpdates() }
            } label: {
                HStack {
                    Text("Check for Updates")
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Color.brandVibrantBlue)
                }
            }
        } header: {
            Text("About")
        }
    }

    private var toastView: some View {
        HStack(spacing: 12) {
            Image(
                systemName: viewModel.isToastError
                    ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
            )
            .foregroundColor(.white)
            Text(viewModel.toastMessage ?? "")
                .font(.manrope(size: 16))
                .foregroundColor(.white)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(
            (viewModel.isToastError ? Color.red : Color.green).opacity(0.9)
        )
        .cornerRadius(30)
        .padding(.top, 60)
    }
}

#Preview {
    SettingsView()
}

// MARK: - Usage Ring View

struct UsageRingView: View {
    let used: Int
    let limit: Int? // nil = unlimited (Plus user)
    
    @State private var animatedProgress: CGFloat = 0
    
    private var progress: CGFloat {
        guard let limit = limit, limit > 0 else { return 1.0 }
        return CGFloat(used) / CGFloat(limit)
    }
    
    private var ringColor: Color {
        guard let limit = limit else { return Color.brandSuccess }
        let remaining = limit - used
        if remaining == 0 {
            return Color.brandError
        } else if remaining <= 2 {
            return Color.brandWarning
        } else {
            return Color.brandVibrantBlue
        }
    }
    
    private var gradientColors: [Color] {
        guard let limit = limit else {
            return [Color.brandSuccess, Color.brandSuccess.opacity(0.7)]
        }
        let remaining = limit - used
        if remaining == 0 {
            return [Color.brandError, Color.brandError.opacity(0.7)]
        } else if remaining <= 2 {
            return [Color.brandWarning, Color.brandWarning.opacity(0.7)]
        } else {
            return [Color.brandVibrantBlue, Color.brandSkyBlue]
        }
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.brandBorder, lineWidth: 10)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Center content
            VStack(spacing: 2) {
                if limit != nil {
                    Text("\(used)")
                        .font(.manrope(size: 28, weight: .bold))
                        .foregroundStyle(ringColor)
                    Text("used")
                        .font(.manrope(size: 11))
                        .foregroundStyle(Color.brandTextTertiary)
                } else {
                    Image(systemName: "infinity")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.brandSuccess)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: used) { _, _ in
            withAnimation(.spring(duration: 0.5)) {
                animatedProgress = progress
            }
        }
    }
}

#Preview("Usage Ring - Full") {
    HStack(spacing: 20) {
        UsageRingView(used: 5, limit: 5)
            .frame(width: 100, height: 100)
        UsageRingView(used: 3, limit: 5)
            .frame(width: 100, height: 100)
        UsageRingView(used: 0, limit: nil)
            .frame(width: 100, height: 100)
    }
    .padding()
}

// MARK: - Emoji Picker View

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss
    
    // Popular emojis organized by category
    private let emojiCategories: [(name: String, emojis: [String])] = [
        ("Smileys", ["😊", "😄", "😁", "🥰", "😎", "🤓", "😇", "🤩", "😋", "🤗", "🙂", "😌", "😏", "🥳", "🤠", "🧐"]),
        ("People", ["👋", "🙌", "👏", "🤝", "👍", "✌️", "🤞", "💪", "🧠", "👀", "🦸", "🦹", "🧑‍💻", "👨‍💼", "👩‍🎨", "🧑‍🚀"]),
        ("Animals", ["🐶", "🐱", "🐼", "🦊", "🦁", "🐯", "🐻", "🐨", "🐸", "🦄", "🐝", "🦋", "🐙", "🦀", "🐬", "🦅"]),
        ("Nature", ["🌸", "🌺", "🌻", "🌹", "🌴", "🌵", "🍀", "🌈", "⭐️", "🌙", "☀️", "🔥", "💧", "❄️", "🌊", "⚡️"]),
        ("Food", ["🍎", "🍕", "🍔", "🌮", "🍣", "🍩", "🧁", "🍪", "☕️", "🍵", "🥤", "🍷", "🎂", "🍦", "🥑", "🍋"]),
        ("Activities", ["⚽️", "🏀", "🎾", "🎮", "🎨", "🎬", "🎤", "🎸", "📚", "✈️", "🚀", "🎯", "🏆", "🎪", "🎭", "🎢"]),
        ("Objects", ["💡", "💎", "🔮", "🎁", "🎈", "🎀", "💰", "💳", "📱", "💻", "⌚️", "📷", "🔑", "❤️", "💜", "💙"])
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Current selection preview
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.brandAccentLight)
                                .frame(width: 80, height: 80)
                            Text(selectedEmoji)
                                .font(.system(size: 44))
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    // Emoji categories
                    ForEach(emojiCategories, id: \.name) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.name)
                                .font(.manrope(size: 14, weight: .semibold))
                                .foregroundStyle(Color.brandTextSecondary)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                                ForEach(category.emojis, id: \.self) { emoji in
                                    Button {
                                        HapticManager.shared.selection()
                                        selectedEmoji = emoji
                                        dismiss()
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedEmoji == emoji ? Color.brandAccentLight : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandVibrantBlue)
                }
            }
        }
    }
}

#Preview("Emoji Picker") {
    EmojiPickerView(selectedEmoji: .constant("😊"))
}

// MARK: - Currency Picker View

struct CurrencyPickerView: View {
    @Binding var selectedCurrency: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredCurrencies: [CurrencyData.Currency] {
        if searchText.isEmpty {
            return CurrencyData.all
        }
        let query = searchText.lowercased()
        return CurrencyData.all.filter {
            $0.code.lowercased().contains(query) ||
            $0.name.lowercased().contains(query) ||
            $0.country.lowercased().contains(query)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCurrencies, id: \.code) { currency in
                    Button {
                        selectedCurrency = currency.code
                        HapticManager.shared.selection()
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Text(currency.flag)
                                .font(.system(size: 28))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(currency.code)
                                        .font(.manrope(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.brandTextPrimary)
                                    
                                    Text(currency.symbol)
                                        .font(.ibmPlexMono(size: 14))
                                        .foregroundStyle(Color.brandTextTertiary)
                                }
                                
                                Text(currency.name)
                                    .font(.manrope(size: 13))
                                    .foregroundStyle(Color.brandTextSecondary)
                            }
                            
                            Spacer()
                            
                            if selectedCurrency == currency.code {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.brandVibrantBlue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search currencies")
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandVibrantBlue)
                }
            }
        }
    }
}

// MARK: - Currency Data

struct CurrencyData {
    struct Currency {
        let code: String
        let symbol: String
        let name: String
        let country: String
        let flag: String
    }
    
    static func flag(for code: String) -> String {
        all.first { $0.code == code }?.flag ?? "🌍"
    }
    
    static let all: [Currency] = [
        // Popular currencies first
        Currency(code: "USD", symbol: "$", name: "US Dollar", country: "United States", flag: "🇺🇸"),
        Currency(code: "EUR", symbol: "€", name: "Euro", country: "European Union", flag: "🇪🇺"),
        Currency(code: "GBP", symbol: "£", name: "British Pound", country: "United Kingdom", flag: "🇬🇧"),
        Currency(code: "JPY", symbol: "¥", name: "Japanese Yen", country: "Japan", flag: "🇯🇵"),
        Currency(code: "CAD", symbol: "$", name: "Canadian Dollar", country: "Canada", flag: "🇨🇦"),
        Currency(code: "AUD", symbol: "$", name: "Australian Dollar", country: "Australia", flag: "🇦🇺"),
        Currency(code: "CHF", symbol: "Fr", name: "Swiss Franc", country: "Switzerland", flag: "🇨🇭"),
        Currency(code: "CNY", symbol: "¥", name: "Chinese Yuan", country: "China", flag: "🇨🇳"),
        Currency(code: "INR", symbol: "₹", name: "Indian Rupee", country: "India", flag: "🇮🇳"),
        Currency(code: "MXN", symbol: "$", name: "Mexican Peso", country: "Mexico", flag: "🇲🇽"),
        Currency(code: "BRL", symbol: "R$", name: "Brazilian Real", country: "Brazil", flag: "🇧🇷"),
        Currency(code: "KRW", symbol: "₩", name: "South Korean Won", country: "South Korea", flag: "🇰🇷"),
        Currency(code: "SGD", symbol: "$", name: "Singapore Dollar", country: "Singapore", flag: "🇸🇬"),
        Currency(code: "HKD", symbol: "$", name: "Hong Kong Dollar", country: "Hong Kong", flag: "🇭🇰"),
        Currency(code: "NZD", symbol: "$", name: "New Zealand Dollar", country: "New Zealand", flag: "🇳🇿"),
        Currency(code: "SEK", symbol: "kr", name: "Swedish Krona", country: "Sweden", flag: "🇸🇪"),
        Currency(code: "NOK", symbol: "kr", name: "Norwegian Krone", country: "Norway", flag: "🇳🇴"),
        Currency(code: "DKK", symbol: "kr", name: "Danish Krone", country: "Denmark", flag: "🇩🇰"),
        Currency(code: "ZAR", symbol: "R", name: "South African Rand", country: "South Africa", flag: "🇿🇦"),
        Currency(code: "RUB", symbol: "₽", name: "Russian Ruble", country: "Russia", flag: "🇷🇺"),
        Currency(code: "TRY", symbol: "₺", name: "Turkish Lira", country: "Turkey", flag: "🇹🇷"),
        Currency(code: "PLN", symbol: "zł", name: "Polish Zloty", country: "Poland", flag: "🇵🇱"),
        Currency(code: "THB", symbol: "฿", name: "Thai Baht", country: "Thailand", flag: "🇹🇭"),
        Currency(code: "IDR", symbol: "Rp", name: "Indonesian Rupiah", country: "Indonesia", flag: "🇮🇩"),
        Currency(code: "MYR", symbol: "RM", name: "Malaysian Ringgit", country: "Malaysia", flag: "🇲🇾"),
        Currency(code: "PHP", symbol: "₱", name: "Philippine Peso", country: "Philippines", flag: "🇵🇭"),
        Currency(code: "CZK", symbol: "Kč", name: "Czech Koruna", country: "Czech Republic", flag: "🇨🇿"),
        Currency(code: "ILS", symbol: "₪", name: "Israeli Shekel", country: "Israel", flag: "🇮🇱"),
        Currency(code: "AED", symbol: "د.إ", name: "UAE Dirham", country: "United Arab Emirates", flag: "🇦🇪"),
        Currency(code: "SAR", symbol: "﷼", name: "Saudi Riyal", country: "Saudi Arabia", flag: "🇸🇦"),
        Currency(code: "TWD", symbol: "NT$", name: "Taiwan Dollar", country: "Taiwan", flag: "🇹🇼"),
        Currency(code: "VND", symbol: "₫", name: "Vietnamese Dong", country: "Vietnam", flag: "🇻🇳"),
        Currency(code: "ARS", symbol: "$", name: "Argentine Peso", country: "Argentina", flag: "🇦🇷"),
        Currency(code: "CLP", symbol: "$", name: "Chilean Peso", country: "Chile", flag: "🇨🇱"),
        Currency(code: "COP", symbol: "$", name: "Colombian Peso", country: "Colombia", flag: "🇨🇴"),
        Currency(code: "EGP", symbol: "£", name: "Egyptian Pound", country: "Egypt", flag: "🇪🇬"),
        Currency(code: "PKR", symbol: "₨", name: "Pakistani Rupee", country: "Pakistan", flag: "🇵🇰"),
        Currency(code: "NGN", symbol: "₦", name: "Nigerian Naira", country: "Nigeria", flag: "🇳🇬"),
        Currency(code: "BDT", symbol: "৳", name: "Bangladeshi Taka", country: "Bangladesh", flag: "🇧🇩"),
        Currency(code: "UAH", symbol: "₴", name: "Ukrainian Hryvnia", country: "Ukraine", flag: "🇺🇦"),
        Currency(code: "RON", symbol: "lei", name: "Romanian Leu", country: "Romania", flag: "🇷🇴"),
        Currency(code: "HUF", symbol: "Ft", name: "Hungarian Forint", country: "Hungary", flag: "🇭🇺"),
        Currency(code: "PEN", symbol: "S/", name: "Peruvian Sol", country: "Peru", flag: "🇵🇪"),
        Currency(code: "KES", symbol: "KSh", name: "Kenyan Shilling", country: "Kenya", flag: "🇰🇪"),
        Currency(code: "QAR", symbol: "﷼", name: "Qatari Riyal", country: "Qatar", flag: "🇶🇦"),
        Currency(code: "KWD", symbol: "د.ك", name: "Kuwaiti Dinar", country: "Kuwait", flag: "🇰🇼"),
        Currency(code: "BHD", symbol: ".د.ب", name: "Bahraini Dinar", country: "Bahrain", flag: "🇧🇭"),
        Currency(code: "OMR", symbol: "﷼", name: "Omani Rial", country: "Oman", flag: "🇴🇲"),
    ]
}

#Preview("Currency Picker") {
    CurrencyPickerView(selectedCurrency: .constant("USD"))
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    
    var icon: String {
        switch self {
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        }
    }
    
    var description: String {
        switch self {
        case .csv: return "Spreadsheet compatible"
        case .json: return "Developer friendly"
        }
    }
}

// MARK: - Data Export Sheet

struct DataExportSheet: View {
    @Binding var isExporting: Bool
    let onExport: (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .csv
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.brandSuccess.opacity(0.15))
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(Color.brandSuccess)
                    }
                    
                    Text("Export Data")
                        .font(.instrumentSerif(size: 24))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    Text("Choose a format for your receipts")
                        .font(.manrope(size: 14, weight: .regular))
                        .foregroundStyle(Color.brandTextSecondary)
                }
                .padding(.top, 20)
                
                // Format options
                VStack(spacing: 12) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            HapticManager.shared.selection()
                            selectedFormat = format
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(selectedFormat == format ? Color.brandVibrantBlue.opacity(0.15) : Color.brandSurface)
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: format.icon)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(selectedFormat == format ? Color.brandVibrantBlue : Color.brandTextSecondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.rawValue)
                                        .font(.manrope(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.brandTextPrimary)
                                    
                                    Text(format.description)
                                        .font(.manrope(size: 12))
                                        .foregroundStyle(Color.brandTextSecondary)
                                }
                                
                                Spacer()
                                
                                if selectedFormat == format {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(Color.brandVibrantBlue)
                                } else {
                                    Circle()
                                        .stroke(Color.brandBorder, lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.brandSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedFormat == format ? Color.brandVibrantBlue : Color.brandBorder, lineWidth: selectedFormat == format ? 2 : 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Export button
                Button {
                    HapticManager.shared.buttonPress()
                    onExport(selectedFormat)
                } label: {
                    HStack(spacing: 10) {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Export as \(selectedFormat.rawValue)")
                                .font(.manrope(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient.brandPrimary)
                    )
                }
                .disabled(isExporting)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.manrope(size: 16, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Data Export") {
    DataExportSheet(isExporting: .constant(false)) { _ in }
}
