//
//  ProfileImageView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-31.
//

import SwiftUI

struct ProfileImageView: View {
    let userId: String
    let authType: SavedUser.AuthType
    let size: CGFloat
    let profileImageData: Data?
    
    @State private var profileImage: UIImage?
    
    init(userId: String, authType: SavedUser.AuthType, size: CGFloat = 20, profileImageData: Data? = nil) {
        self.userId = userId
        self.authType = authType
        self.size = size
        self.profileImageData = profileImageData
    }
    
    var body: some View {
        Group {
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Fallback to SF Symbol
                Image(systemName: authType == .apiKey ? "key.fill" : "person.fill")
                    .foregroundColor(authType == .apiKey ? .orange : .blue)
                    .font(.title3)
                    .frame(width: size, height: size)
            }
        }
        .onAppear {
            loadProfileImage()
        }
    }
    
    private func loadProfileImage() {
        // First try to use saved profile image data
        if let profileImageData = profileImageData,
           let image = UIImage(data: profileImageData) {
            self.profileImage = image
            return
        }
        
    }
}

#Preview {
    ProfileImageView(
        userId: "test-user-id",
        authType: .jwt,
        size: 40,
        profileImageData: nil
    )
}
