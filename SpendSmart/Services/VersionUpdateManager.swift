//
//  VersionUpdateManager.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import Foundation
import UIKit

/// Manager for checking app version updates and handling user interactions
class VersionUpdateManager: ObservableObject {
    static let shared = VersionUpdateManager()
    
    // MARK: - Published Properties
    @Published var isChecking: Bool = false
    @Published var lastCheckDate: Date?
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    private let bundleId: String
    private let currentVersion: String
    private let iTunesSearchURL = "https://itunes.apple.com/lookup"
    
    // Check frequency settings
    private let minimumCheckInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let remindLaterInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // MARK: - Initialization
    private init() {
        self.bundleId = Bundle.main.bundleIdentifier ?? ""
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // MARK: - Public Methods
    
    /// Check for app updates with smart timing
    /// - Parameter force: If true, bypasses timing checks and forces an update check
    /// - Returns: VersionCheckResult indicating the outcome
    @MainActor
    func checkForUpdates(force: Bool = false) async -> VersionCheckResult {
        // Don't check if already checking
        guard !isChecking else {
            return .upToDate
        }
        
        // Check if we should skip based on timing
        if !force && !shouldCheckForUpdates() {
            return .upToDate
        }
        
        isChecking = true
        defer { isChecking = false }
        
        do {
            let versionInfo = try await fetchLatestVersionInfo()
            lastCheckDate = Date()
            lastError = nil
            
            // Update last check date in UserDefaults
            UserDefaults.standard.set(lastCheckDate, forKey: "lastVersionCheck")
            
            if versionInfo.isUpdateAvailable {
                // Check if this version was previously skipped
                if let skippedVersion = UserDefaults.standard.string(forKey: "skippedVersion"),
                   skippedVersion == versionInfo.latestVersion {
                    return .skipped(skippedVersion)
                }
                
                // Check if user chose "remind later" and it's not time yet
                if let remindDate = UserDefaults.standard.object(forKey: "remindLaterDate") as? Date,
                   Date() < remindDate {
                    return .remindLater(remindDate)
                }
                
                return .updateAvailable(versionInfo)
            } else {
                return .upToDate
            }
        } catch {
            lastError = error
            return .error(error)
        }
    }
    
    /// Handle user action on version update alert
    /// - Parameters:
    ///   - action: The action taken by the user
    ///   - version: The version being acted upon
    func handleUserAction(_ action: VersionUpdateAction, for version: String) {
        switch action {
        case .updateNow:
            openAppStore()
        case .remindLater:
            let remindDate = Date().addingTimeInterval(remindLaterInterval)
            UserDefaults.standard.set(remindDate, forKey: "remindLaterDate")
        case .skipVersion:
            UserDefaults.standard.set(version, forKey: "skippedVersion")
        case .dismiss:
            // Do nothing, just dismiss
            break
        }
    }
    
    /// Open the App Store to the app's page
    private func openAppStore() {
        Task {
            do {
                let versionInfo = try await fetchLatestVersionInfo()
                if let urlString = versionInfo.appStoreURL,
                   let url = URL(string: urlString) {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                }
            } catch {
                // Fallback to generic App Store URL
                let fallbackURL = "https://apps.apple.com/app/id\(bundleId)"
                if let url = URL(string: fallbackURL) {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Determine if we should check for updates based on timing and user preferences
    private func shouldCheckForUpdates() -> Bool {
        // Check if enough time has passed since last check
        if let lastCheck = UserDefaults.standard.object(forKey: "lastVersionCheck") as? Date {
            let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
            if timeSinceLastCheck < minimumCheckInterval {
                return false
            }
        }
        
        // Check if user chose "remind later" and it's not time yet
        if let remindDate = UserDefaults.standard.object(forKey: "remindLaterDate") as? Date,
           Date() < remindDate {
            return false
        }
        
        return true
    }
    
    /// Fetch the latest version information from the App Store
    private func fetchLatestVersionInfo() async throws -> VersionInfo {
        guard !bundleId.isEmpty else {
            throw VersionCheckError.invalidBundleId
        }
        
        let urlString = "\(iTunesSearchURL)?bundleId=\(bundleId)"
        guard let url = URL(string: urlString) else {
            throw VersionCheckError.invalidResponse
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VersionCheckError.networkError
        }
        
        let appStoreResponse = try JSONDecoder().decode(AppStoreResponse.self, from: data)
        
        guard let appResult = appStoreResponse.results.first else {
            throw VersionCheckError.appNotFound
        }
        
        // Parse release date
        let dateFormatter = ISO8601DateFormatter()
        let releaseDate = dateFormatter.date(from: appResult.currentVersionReleaseDate)
        
        return VersionInfo(
            currentVersion: currentVersion,
            latestVersion: appResult.version,
            releaseNotes: appResult.releaseNotes,
            releaseDate: releaseDate,
            appStoreURL: appResult.trackViewUrl
        )
    }
}
