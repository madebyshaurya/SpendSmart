import Combine
import SwiftUI
import UIKit

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var showDeleteWarning = false
    @Published var showDeleteConfirmation = false
    @Published var userEmail: String = "Loading..."
    @Published var displayName: String = "Loading..."
    @Published var deleteConfirmationText: String = ""
    @Published var isEditingName = false
    @Published var pendingDisplayName: String = ""
    @Published var isSavingDisplayName = false
    @Published var showToast = false
    @Published var toastMessage: String? = nil
    @Published var isToastError = false

    private let supabase = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    var isDeleteConfirmed: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == "DELETE ACCOUNT"
    }

    init() {
        supabase.$session
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchUser()
            }
            .store(in: &cancellables)

        supabase.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.updateDisplayName(with: profile)
            }
            .store(in: &cancellables)

        fetchUser()
        Task { await supabase.refreshProfile() }
    }

    func fetchUser() {
        if let email = supabase.session?.user.email, !email.isEmpty {
            userEmail = email
        } else {
            userEmail = "Guest"
        }

        updateDisplayName(with: supabase.profile)
    }

    func beginEditingName() {
        pendingDisplayName = displayName == "Loading..." ? "" : displayName
        isEditingName = true
    }

    func cancelEditingName() {
        isEditingName = false
        pendingDisplayName = ""
    }

    func saveDisplayName() {
        let trimmed = pendingDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            presentToast("Name cannot be empty", isError: true)
            return
        }
        isSavingDisplayName = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let profile = try await self.supabase.upsertProfileName(trimmed)
                await MainActor.run {
                    self.displayName = self.sanitizedDisplayName(
                        from: profile.full_name ?? trimmed)
                    self.isEditingName = false
                    self.pendingDisplayName = ""
                    self.presentToast("Name updated")
                }
            } catch {
                await MainActor.run {
                    self.presentToast("Unable to update name", isError: true)
                }
            }
            await MainActor.run {
                self.isSavingDisplayName = false
            }
        }
    }

    func signOut(appState: AppState) {
        Task {
            try? await supabase.signOut()
            appState.resetState()
        }
    }

    func deleteAccount(appState: AppState) {
        Task {
            do {
                try await supabase.deleteAccount()
                try? await supabase.signOut()
                clearLocalData()
                clearAppleNameCache()
                appState.clearOnboardingStateForCurrentUser()
                appState.resetState()
                presentToast("Account deleted")
            } catch {
                presentToast("Error deleting account: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func clearAppleNameCache() {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix("apple_name_") {
            defaults.removeObject(forKey: key)
        }
    }

    private func clearLocalData() {
        LocalReceiptStorage.shared.clearAllReceipts()
        SubscriptionManager.shared.resetScanUsage()
        
        // Clear all UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()
    }

    private func updateDisplayName(with profile: Profile?) {
        if let stored = profile?.full_name,
            !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            displayName = sanitizedDisplayName(from: stored)
        } else if userEmail != "Guest" {
            displayName = fallbackName(fromEmail: userEmail)
        } else {
            displayName = "SpendSmart User"
        }
    }

    private func fallbackName(fromEmail email: String) -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "SpendSmart User" }
        if let atIndex = trimmed.firstIndex(of: "@") {
            let namePart = trimmed[..<atIndex]
            if !namePart.isEmpty {
                return String(namePart)
            }
        }
        return trimmed
    }

    private func sanitizedDisplayName(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "SpendSmart User" }
        if let atIndex = trimmed.firstIndex(of: "@") {
            let namePart = trimmed[..<atIndex]
            if !namePart.isEmpty {
                return String(namePart)
            }
        }
        return trimmed
    }

    func presentToast(_ message: String, isError: Bool = false) {
        toastMessage = message
        isToastError = isError
        showToast = true
    }

    // MARK: - Export

    @Published var isExporting = false
    @Published var exportedFileURL: URL?

    func exportData(format: ExportFormat, currencyCode: String, localStorage: LocalReceiptStorage) async {
        isExporting = true

        var allReceipts: [Receipt] = localStorage.getAllReceipts()
        if let cloudReceipts = try? await SupabaseManager.shared.fetchReceipts(page: 1, limit: 1000) {
            var seenIds = Set(allReceipts.map { $0.id })
            for receipt in cloudReceipts {
                if !seenIds.contains(receipt.id) {
                    allReceipts.append(receipt)
                    seenIds.insert(receipt.id)
                }
            }
        }

        allReceipts.sort { $0.purchase_date > $1.purchase_date }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = currencyCode

        switch format {
        case .csv:
            exportedFileURL = createCSV(receipts: allReceipts, dateFormatter: dateFormatter, currencyFormatter: currencyFormatter)
        case .json:
            exportedFileURL = createJSON(receipts: allReceipts)
        }

        isExporting = false
    }

    private func createCSV(receipts: [Receipt], dateFormatter: DateFormatter, currencyFormatter: NumberFormatter) -> URL? {
        var csv = "Date,Store,Total,Tax,Savings,Payment Method,Items Count,Currency\n"

        for receipt in receipts {
            let date = dateFormatter.string(from: receipt.purchase_date)
            let store = receipt.store_name.replacingOccurrences(of: ",", with: ";")
            let total = String(format: "%.2f", receipt.total_amount)
            let tax = String(format: "%.2f", receipt.total_tax)
            let savings = String(format: "%.2f", receipt.savings)
            let payment = receipt.payment_method.replacingOccurrences(of: ",", with: ";")
            let items = "\(receipt.items.count)"
            let currency = receipt.currency

            csv += "\(date),\(store),\(total),\(tax),\(savings),\(payment),\(items),\(currency)\n"
        }

        let fileName = "SpendSmart_Export_\(Date().formatted(.dateTime.year().month().day())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }

    private func createJSON(receipts: [Receipt]) -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(receipts)
            let fileName = "SpendSmart_Export_\(Date().formatted(.dateTime.year().month().day())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - Updates

    func checkForUpdates() async {
        let result = await VersionUpdateManager.shared.checkForUpdates(force: true)
        switch result {
        case .updateAvailable(let info):
            if let urlString = info.appStoreURL, let url = URL(string: urlString) {
                await UIApplication.shared.open(url)
            }
        case .upToDate:
            presentToast("App is up to date")
        case .error:
            presentToast("Error checking for updates", isError: true)
        default:
            break
        }
    }
}
