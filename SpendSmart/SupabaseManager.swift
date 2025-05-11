//
//  SupabaseManager.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-12.
//

import Foundation
import Supabase

// Create a Supabase client instance
let supabase = SupabaseClient(
    supabaseURL: URL(string: supabaseURL)!,
    supabaseKey: supabaseAnonKey
)
