//
//  Badge.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-01.
//

import SwiftUI

struct Badge: View {
    let text: String
    let color: Color
    let minWidth: CGFloat?
    
    init(_ text: String, color: Color, minWidth: CGFloat? = 70) {
        self.text = text
        self.color = color
        self.minWidth = minWidth
    }
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(minWidth: minWidth)
            .background(color)
            .cornerRadius(6)
    }
}
