//
//  VersionUpdateManager.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import Foundation
import UIKit

/// Manager for checking app version updates and handling user interactions
@MainActor
final class VersionUpdateManager: ObservableObject, @unchecked Sendable {
    static let shared = VersionUpdateManager()
    
    // MARK: - Published Properties
    @Published var isChecking: Bool = false
    @Published var lastCheckDate: Date?
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    private let bundleId: String
    private let currentVersion: String
    private let iTunesSearchURL = "https://itunes.apple.com/lookup"
    private var currentTask: Task<VersionCheckResult, Never>?
    
    // Check frequency settings
    private let minimumCheckInterval: TimeInterval = 1 * 60 * 60 // 1 hour
    private let remindLaterInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // MARK: - Initialization
    private init() {
        // Use the correct bundle ID from the project
        self.bundleId = Bundle.main.bundleIdentifier ?? "com.shauryag.SpendSmartAppStore"
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        print("📱 Version Update Manager initialized with bundle ID: \(bundleId), current version: \(currentVersion)")
    }
    
    deinit {
        currentTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Check for app updates with smart timing
    /// - Parameter force: If true, bypasses timing checks and forces an update check
    /// - Returns: VersionCheckResult indicating the outcome
    @MainActor
    func checkForUpdates(force: Bool = false) async -> VersionCheckResult {
        // Cancel any existing check
        currentTask?.cancel()
        
        // Don't check if already checking
        guard !isChecking else {
            print("⏳ Already checking for updates, skipping...")
            return .upToDate
        }
        
        // Check if we should skip based on timing
        if !force && !shouldCheckForUpdates() {
            print("⏳ Skipping version check - too soon since last check")
            return .upToDate
        }
        
        isChecking = true
        defer { isChecking = false }
        
        // Create new task with proper return type
        currentTask = Task {
            do {
                let versionInfo = try await fetchLatestVersionInfo()
                
                // Check if task was cancelled
                if Task.isCancelled { 
                    return .error(VersionCheckError.networkError)
                }
                
                lastCheckDate = Date()
                lastError = nil
                
                // Update last check date in UserDefaults
                UserDefaults.standard.set(lastCheckDate, forKey: "lastVersionCheck")
                print("✅ Version check completed at \(lastCheckDate?.description ?? "unknown")")
                
                if versionInfo.isUpdateAvailable {
                    if versionInfo.isForced {
                        return .forcedUpdateRequired(versionInfo)
                    }
                    
                    if let remindDate = UserDefaults.standard.object(forKey: "remindLaterDate") as? Date,
                       Date() < remindDate {
                        return .remindLater(remindDate)
                    }
                    
                    return .updateAvailable(versionInfo)
                } else {
                    return .upToDate
                }
            } catch {
                // Check if task was cancelled
                if Task.isCancelled { 
                    return .error(VersionCheckError.networkError)
                }
                
                lastError = error
                print("❌ Version check error: \(error.localizedDescription)")
                return .error(error)
            }
        }
        
        // Wait for task to complete and return its result
        return await currentTask?.value ?? .error(VersionCheckError.networkError)
    }
    
    func handleUserAction(_ action: VersionUpdateAction, for version: String, isForced: Bool = false) {
        switch action {
        case .updateNow:
            openAppStore()
        case .remindLater:
            if !isForced {
                UserDefaults.standard.set(Date().addingTimeInterval(remindLaterInterval), forKey: "remindLaterDate")
            }
        case .dismiss:
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
                        UIApplication.shared.open(url) { success in
                            if !success {
                                print("❌ Failed to open App Store URL")
                                // Fallback to generic App Store URL
                                let fallbackURL = "https://apps.apple.com/app/id\(self.bundleId)"
                                if let url = URL(string: fallbackURL) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error fetching App Store URL: \(error.localizedDescription)")
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
    
    /// Fetch the latest version information from the App Store
    func fetchLatestVersionInfo() async throws -> VersionInfo {
        guard !bundleId.isEmpty else {
            print("❌ Error: Empty bundle ID")
            throw VersionCheckError.invalidBundleId
        }
        
        let forcedUpdateInfo = await checkForcedUpdate()
        
        let urlString = "\(iTunesSearchURL)?bundleId=\(bundleId)"
        guard let url = URL(string: urlString) else {
            print("❌ Error: Invalid URL - \(urlString)")
            throw VersionCheckError.invalidResponse
        }
        
        print("🔍 Making API request to: \(urlString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check if task was cancelled
            if Task.isCancelled { throw VersionCheckError.networkError }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 Raw API Response: \(responseString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Error: Invalid HTTP response")
                throw VersionCheckError.networkError
            }
            
            print("📡 HTTP Status Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Error: HTTP \(httpResponse.statusCode)")
                throw VersionCheckError.networkError
            }
            
            do {
                let appStoreResponse = try JSONDecoder().decode(AppStoreResponse.self, from: data)
                print("✅ Successfully decoded response")
                print("📊 Result count: \(appStoreResponse.resultCount)")
                
                guard let appResult = appStoreResponse.results.first else {
                    print("❌ Error: No results found in response")
                    throw VersionCheckError.appNotFound
                }
                
                print("📱 Found app in App Store:")
                print("   - Version: \(appResult.version)")
                print("   - Bundle ID: \(appResult.bundleId)")
                print("   - Release Date: \(appResult.currentVersionReleaseDate)")
                if let notes = appResult.releaseNotes {
                    print("   - Release Notes: \(notes)")
                }
                
                // Parse release date
                let dateFormatter = ISO8601DateFormatter()
                let releaseDate = dateFormatter.date(from: appResult.currentVersionReleaseDate)
                
                var releaseNotes = appResult.releaseNotes
                if forcedUpdateInfo.isForced, let forceMessage = forcedUpdateInfo.message {
                    releaseNotes = releaseNotes != nil ? "⚠️ \(forceMessage)\n\n\(releaseNotes!)" : "⚠️ \(forceMessage)"
                }
                
                return VersionInfo(
                    currentVersion: currentVersion,
                    latestVersion: appResult.version,
                    releaseNotes: releaseNotes,
                    releaseDate: releaseDate,
                    appStoreURL: appResult.trackViewUrl,
                    minimumOSVersion: appResult.minimumOsVersion,
                    isForced: forcedUpdateInfo.isForced
                )
            } catch {
                print("❌ Error decoding response: \(error)")
                throw VersionCheckError.parsingError
            }
        } catch {
            print("❌ Network error: \(error)")
            throw VersionCheckError.networkError
        }
    }
    
    private func checkForcedUpdate() async -> (isForced: Bool, message: String?) {
        do {
            let backendURL = await BackendConfig.shared.activeBackendURL
            guard let url = URL(string: "\(backendURL)/api/version/check-forced-update") else {
                return (false, nil)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "bundleId": bundleId,
                "currentVersion": currentVersion
            ])
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return (json["isForced"] as? Bool ?? false, json["message"] as? String)
            }
        } catch {}
        
        return (false, nil)
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
}
