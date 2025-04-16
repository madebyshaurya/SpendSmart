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

    init() {
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
    }

    // Reset app state
    func resetState() {
        isLoggedIn = false
        userEmail = ""
        isGuestUser = false
        useLocalStorage = false
        guestUserId = nil

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: isGuestUserKey)
        UserDefaults.standard.removeObject(forKey: guestUserIdKey)
    }

    // Set up guest mode
    func enableGuestMode(userId: UUID? = nil) {
        isLoggedIn = true
        isGuestUser = true
        useLocalStorage = true
        userEmail = "Guest User"
        guestUserId = userId

        print("✅ Guest mode enabled with ID: \(userId?.uuidString ?? "none")")
    }
}
