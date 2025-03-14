//
//  Supabase.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-12.
//

import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: supabaseURL)!,
    supabaseKey: supabaseAnonKey
)
