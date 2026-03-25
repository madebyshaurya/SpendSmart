import Foundation
import UIKit

@MainActor
final class VersionUpdateManager: ObservableObject {
    static let shared = VersionUpdateManager()
    
    @Published var isChecking: Bool = false
    @Published var lastCheckDate: Date?
    @Published var lastError: Error?
    
    private let bundleId: String
    private let currentVersion: String
    private let iTunesSearchURL = "https://itunes.apple.com/lookup"
    private let checkInterval: TimeInterval = 3600
    private let remindInterval: TimeInterval = 604800
    
    private init() {
        self.bundleId = Bundle.main.bundleIdentifier ?? "com.shauryag.SpendSmartAppStore"
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    func checkForUpdates(force: Bool = false) async -> VersionCheckResult {
        guard !isChecking else { return .upToDate }
        if !force && !shouldCheck() { return .upToDate }
        
        isChecking = true
        defer { isChecking = false }
        
        do {
            let info = try await fetchInfo()
            lastCheckDate = Date()
            UserDefaults.standard.set(lastCheckDate, forKey: "lastVersionCheck")
            
            if info.isUpdateAvailable {
                if info.isForced { return .forcedUpdateRequired(info) }
                if let remindDate = UserDefaults.standard.object(forKey: "remindLaterDate") as? Date, Date() < remindDate {
                    return .remindLater(remindDate)
                }
                return .updateAvailable(info)
            }
            return .upToDate
        } catch {
            lastError = error
            return .error(error)
        }
    }
    
    func handleAction(_ action: VersionUpdateAction, version: String, isForced: Bool = false) {
        switch action {
        case .updateNow:
            openAppStore()
        case .remindLater:
            if !isForced {
                UserDefaults.standard.set(Date().addingTimeInterval(remindInterval), forKey: "remindLaterDate")
            }
        case .dismiss:
            break
        }
    }
    
    private func openAppStore() {
        Task {
            if let info = try? await fetchInfo(), let urlString = info.appStoreURL, let url = URL(string: urlString) {
                await UIApplication.shared.open(url)
            } else if let url = URL(string: "https://apps.apple.com/app/id\(bundleId)") {
                await UIApplication.shared.open(url)
            }
        }
    }
    
    private func fetchInfo() async throws -> VersionInfo {
        let forced = await checkForced()
        guard let url = URL(string: "\(iTunesSearchURL)?bundleId=\(bundleId)") else { throw VersionCheckError.invalidResponse }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(AppStoreResponse.self, from: data)
        guard let result = response.results.first else { throw VersionCheckError.appNotFound }
        
        let releaseDate = ISO8601DateFormatter().date(from: result.currentVersionReleaseDate)
        var notes = result.releaseNotes
        if forced.isForced, let msg = forced.message {
            notes = notes != nil ? "⚠️ \(msg)\n\n\(notes!)" : "⚠️ \(msg)"
        }
        
        return VersionInfo(
            currentVersion: currentVersion,
            latestVersion: result.version,
            releaseNotes: notes,
            releaseDate: releaseDate,
            appStoreURL: result.trackViewUrl,
            minimumOSVersion: result.minimumOsVersion,
            isForced: forced.isForced
        )
    }
    
    private func checkForced() async -> (isForced: Bool, message: String?) {
        do {
            let backendURL = await BackendConfig.shared.activeBackendURL
            guard let url = URL(string: "\(backendURL)/api/version/check-forced-update") else { return (false, nil) }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["bundleId": bundleId, "currentVersion": currentVersion])
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return (json["isForced"] as? Bool ?? false, json["message"] as? String)
            }
        } catch {}
        return (false, nil)
    }
    
    private func shouldCheck() -> Bool {
        if let last = UserDefaults.standard.object(forKey: "lastVersionCheck") as? Date, Date().timeIntervalSince(last) < checkInterval { return false }
        if let remind = UserDefaults.standard.object(forKey: "remindLaterDate") as? Date, Date() < remind { return false }
        return true
    }
}
