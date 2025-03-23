//
//  NewExpenseView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-19.
//

import SwiftUI

struct NewExpenseView: View {
    var onReceiptAdded: (Receipt) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("TODO: Add new expense form here")
        }
    }
}
