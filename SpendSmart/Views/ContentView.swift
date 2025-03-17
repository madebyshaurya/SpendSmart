//
//  ContentView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-12.
//

import SwiftUI
import AuthenticationServices
import Supabase

struct ContentView: View {
    @State var isLoggedIn = false
    @State var userEmail: String = ""
    
    var body: some View {
        if isLoggedIn {
            DashboardView(email: userEmail, onSignOut: {
                isLoggedIn = false
                userEmail = ""
            })
        } else {
            LaunchScreen(isLoggedIn: $isLoggedIn, userEmail: $userEmail)
        }
    }
}

#Preview {
    ContentView()
}
