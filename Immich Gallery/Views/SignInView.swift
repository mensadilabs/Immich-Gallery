//
//  SignInView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct SignInView: View {
    @ObservedObject var authService: AuthenticationService
    @State private var serverURL = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Immich Gallery")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sign in to your Immich server")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Form
                VStack(spacing: 20) {
                    // Server URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("https://your-immich-server.com", text: $serverURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .onAppear {
                                // Pre-fill with common Immich server URLs
                                if serverURL.isEmpty {
                                    serverURL = "https://"
                                }
                            }
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("your-email@example.com", text: $email)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                    }
                    
                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        SecureField("Enter your password", text: $password)
                    }
                }
                
                // Sign In Button
                Button(action: signIn) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        
                        Text(isLoading ? "Signing In..." : "Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading || serverURL.isEmpty || email.isEmpty || password.isEmpty)
                .opacity((isLoading || serverURL.isEmpty || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                
                // Help text
                VStack(spacing: 8) {
                    Text("Need help?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Make sure your Immich server is running and accessible from this device.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 50)
            .alert("Sign In Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func signIn() {
        guard !serverURL.isEmpty && !email.isEmpty && !password.isEmpty else {
            return
        }
        
        isLoading = true
        
        // Clean up the server URL
        var cleanURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        // Remove trailing slash if present
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        // Validate URL format
        guard URL(string: cleanURL) != nil else {
            isLoading = false
            showError = true
            errorMessage = "Please enter a valid server URL"
            return
        }
        
        authService.signIn(serverURL: cleanURL, email: email, password: password) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if !success {
                    showError = true
                    errorMessage = error ?? "Failed to sign in. Please check your credentials and try again."
                }
            }
        }
    }
}

#Preview {
    let networkService = NetworkService()
    let authService = AuthenticationService(networkService: networkService)
    SignInView(authService: authService)
}

