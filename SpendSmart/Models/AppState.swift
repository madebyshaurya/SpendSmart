//
//  AppState.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//

import SwiftUI

class AppState: ObservableObject {
    // UserDefaults keys
    private let isGuestUserKey = "isGuestUser"
    private let guestUserIdKey = "guestUserId"
    private let isOnboardingCompleteKey = "isOnboardingComplete"
    private let isFirstLoginKey = "isFirstLogin"
    private let lastVersionCheckKey = "lastVersionCheck"
    private let skippedVersionKey = "skippedVersion"
    private let remindLaterDateKey = "remindLaterDate"
    private let lastAvailableVersionKey = "lastAvailableVersion"
    private let lastReleaseNotesKey = "lastReleaseNotes"
    private let lastActiveDateKey = "lastActiveDate"

    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var isGuestUser: Bool = false {
        didSet {
            UserDefaults.standard.set(isGuestUser, forKey: isGuestUserKey)
        }
    }
    @Published var useLocalStorage: Bool = false
    @Published var guestUserId: UUID? = nil {
        didSet {
            if let userId = guestUserId {
                UserDefaults.standard.set(userId.uuidString, forKey: guestUserIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: guestUserIdKey)
            }
        }
    }

    // Onboarding state
    @Published var isOnboardingComplete: Bool = false {
        didSet {
            UserDefaults.standard.set(isOnboardingComplete, forKey: isOnboardingCompleteKey)
        }
    }

    // First login flag to show onboarding only after account creation
    @Published var isFirstLogin: Bool = false {
        didSet {
            UserDefaults.standard.set(isFirstLogin, forKey: isFirstLoginKey)
        }
    }

    // Version update state
    @Published var showVersionUpdateAlert: Bool = false
    @Published var availableVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var isCheckingForUpdates: Bool = false

    init() {
        // Load onboarding state
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: isOnboardingCompleteKey)
        self.isFirstLogin = UserDefaults.standard.bool(forKey: isFirstLoginKey)

        // Try to restore guest mode from UserDefaults
        if UserDefaults.standard.bool(forKey: isGuestUserKey) {
            if let userIdString = UserDefaults.standard.string(forKey: guestUserIdKey),
               let userId = UUID(uuidString: userIdString) {
                print("🔄 Restoring guest mode from UserDefaults with ID: \(userId)")
                self.isLoggedIn = true
                self.isGuestUser = true
                self.useLocalStorage = true
                self.userEmail = "Guest User"
                self.guestUserId = userId
            }
        }
        
        // Restore version update state if available
        if let storedVersion = UserDefaults.standard.string(forKey: lastAvailableVersionKey),
           let storedNotes = UserDefaults.standard.string(forKey: lastReleaseNotesKey) {
            self.availableVersion = storedVersion
            self.releaseNotes = storedNotes
        }
    }

    // Reset app state
    func resetState() {
        isLoggedIn = false
        userEmail = ""
        isGuestUser = false
        useLocalStorage = false
        guestUserId = nil

        // Reset onboarding state if needed
        // Note: We typically don't reset isOnboardingComplete as we don't want
        // to show onboarding again for existing users
        isFirstLogin = false

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: isGuestUserKey)
        UserDefaults.standard.removeObject(forKey: guestUserIdKey)
        UserDefaults.standard.removeObject(forKey: isFirstLoginKey)

        // Reset version update state
        showVersionUpdateAlert = false
        availableVersion = ""
        releaseNotes = ""
        isCheckingForUpdates = false
        
        // Clear stored version info
        UserDefaults.standard.removeObject(forKey: lastAvailableVersionKey)
        UserDefaults.standard.removeObject(forKey: lastReleaseNotesKey)
        UserDefaults.standard.removeObject(forKey: lastActiveDateKey)
    }

    // Set up guest mode
    func enableGuestMode(userId: UUID? = nil) {
        isLoggedIn = true
        isGuestUser = true
        useLocalStorage = true
        userEmail = "Guest User"
        guestUserId = userId

        // Note: We don't set isFirstLogin here because it's managed by the caller
        // This allows us to distinguish between restored sessions and new guest accounts

        print("✅ Guest mode enabled with ID: \(userId?.uuidString ?? "none")")
    }

    // Version update helper methods
    func getLastVersionCheckDate() -> Date? {
        return UserDefaults.standard.object(forKey: lastVersionCheckKey) as? Date
    }

    func setLastVersionCheckDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastVersionCheckKey)
    }

    func getSkippedVersion() -> String? {
        return UserDefaults.standard.string(forKey: skippedVersionKey)
    }

    func setSkippedVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: skippedVersionKey)
    }

    func getRemindLaterDate() -> Date? {
        return UserDefaults.standard.object(forKey: remindLaterDateKey) as? Date
    }

    func setRemindLaterDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: remindLaterDateKey)
    }

    func clearRemindLater() {
        UserDefaults.standard.removeObject(forKey: remindLaterDateKey)
    }
    
    // New version update helper methods
    func shouldCheckForUpdates() -> Bool {
        // Check if we've been in background for more than 30 minutes
        if let lastActiveDate = UserDefaults.standard.object(forKey: lastActiveDateKey) as? Date {
            let timeInBackground = Date().timeIntervalSince(lastActiveDate)
            return timeInBackground > 30 * 60 // 30 minutes
        }
        return false
    }
    
    func updateLastActiveDate() {
        UserDefaults.standard.set(Date(), forKey: lastActiveDateKey)
    }
    
    func storeVersionInfo(version: String, notes: String) {
        UserDefaults.standard.set(version, forKey: lastAvailableVersionKey)
        UserDefaults.standard.set(notes, forKey: lastReleaseNotesKey)
        self.availableVersion = version
        self.releaseNotes = notes
    }
    
    func clearStoredVersionInfo() {
        UserDefaults.standard.removeObject(forKey: lastAvailableVersionKey)
        UserDefaults.standard.removeObject(forKey: lastReleaseNotesKey)
        self.availableVersion = ""
        self.releaseNotes = ""
    }
}
