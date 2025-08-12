//
//  SignInView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct SignInView: View {
    @ObservedObject var authService: AuthenticationService
    let mode: Mode
    let onUserAdded: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum Mode {
        case signIn
        case addUser
    }
    
    init(authService: AuthenticationService, mode: Mode = .signIn, onUserAdded: (() -> Void)? = nil) {
        self.authService = authService
        self.mode = mode
        self.onUserAdded = onUserAdded
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: mode == .addUser ? "person.badge.plus" : "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Immich Gallery")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(mode == .addUser ? "Add another account" : "Sign in to your Immich server")
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
                                    serverURL = authService.baseURL.isEmpty ? "https://" : String(authService.baseURL)
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
                            Image(systemName: mode == .addUser ? "plus.circle.fill" : "arrow.right.circle.fill")
                        }
                        
                        Text(isLoading ? (mode == .addUser ? "Adding User..." : "Signing In...") : (mode == .addUser ? "Add User" : "Sign In"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isLoading || serverURL.isEmpty || email.isEmpty || password.isEmpty)
                .opacity((isLoading || serverURL.isEmpty || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                
            
                VStack(spacing: 8) {
                    Text("Make sure your Immich server is running and accessible from this device.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .frame(width: 1000)
            .padding(.horizontal, 30)
            .padding(.top, 50)
            .alert(mode == .addUser ? "Add User Error" : "Sign In Error", isPresented: $showError) {
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
        
        if mode == .addUser {
            // Add user mode: directly handle authentication without affecting current user
            addUser(serverURL: cleanURL)
        } else {
            // Regular sign in mode: use the existing auth service
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
    
    private func addUser(serverURL: String) {
        // Direct authentication without affecting current user
        let loginURL = URL(string: "\(serverURL)/api/auth/login")!
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginData = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            isLoading = false
            showError = true
            errorMessage = "Error creating login request"
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    showError = true
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    showError = true
                    errorMessage = "Invalid response from server"
                    return
                }
                
                guard let data = data else {
                    showError = true
                    errorMessage = "No data received from server"
                    return
                }
                
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorResponse["message"] as? String {
                        showError = true
                        errorMessage = message
                    } else {
                        showError = true
                        errorMessage = "Authentication failed (Status: \(httpResponse.statusCode))"
                    }
                    return
                }
                
                do {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    
                    // Generate unique user ID: "user@server"
                    let userId = generateUserIdForUser(email: authResponse.userEmail, serverURL: serverURL)
                    
                    print("SignInView: Adding new user \(authResponse.userEmail) with ID \(userId)")
                    
                    // Save user data
                    let savedUser = SavedUser(
                        id: userId,
                        email: authResponse.userEmail,
                        name: authResponse.name,
                        serverURL: serverURL
                    )
                    
                    if let userData = try? JSONEncoder().encode(savedUser) {
                        UserDefaults.standard.set(userData, forKey: "\(UserDefaultsKeys.userPrefix)\(userId)")
                        print("SignInView: Saved user data for \(authResponse.userEmail)")
                    }
                    
                    // Save token directly: "user@server" : token
                    UserDefaults.standard.set(authResponse.accessToken, forKey: "\(UserDefaultsKeys.tokenPrefix)\(userId)")
                    print("SignInView: Saved token for \(authResponse.userEmail) - starts with: \(String(authResponse.accessToken.prefix(20)))...")
                    
                    onUserAdded?()
                    dismiss()
                    
                } catch {
                    showError = true
                    errorMessage = "Invalid response format from server"
                }
            }
        }.resume()
    }
}

#Preview {
    let networkService = NetworkService()
    let authService = AuthenticationService(networkService: networkService)
    SignInView(authService: authService, mode: .signIn)
}

