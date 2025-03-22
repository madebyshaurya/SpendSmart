//
//  SectionHeaderView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//

import SwiftUI

struct SectionHeaderView: View {
    var title: String
    var icon: String
    var color: Color? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color ?? Color(hex: "3B82F6"))
                .font(.system(size: 12))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color ?? Color(hex: "3B82F6"))
        }
    }
}
