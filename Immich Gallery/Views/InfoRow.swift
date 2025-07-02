//
//  InfoRow.swift
//  Immich Gallery
//
//  Created by mensadi-labs Kumar on 2025-06-29.
//

import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
} 