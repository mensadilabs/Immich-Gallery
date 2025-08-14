//
//  UniversalErrorHandler.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-07-13
//

import SwiftUI
import Foundation

struct UniversalErrorDisplayView: View {
    let error: Error
    let context: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack() {
            ZStack {
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                HStack(spacing: 30) {
                    // Left side - Error info
                    VStack(spacing: 15) {
                        // Error Icon
                        Image(systemName: errorIcon)
                            .font(.system(size: 50))
                            .foregroundColor(errorColor)
                        
                        // Error Title
                        Text("Oops! Unexpected Error")
                            .font(.title2)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                        
                        // Context
                        Text("Error in: \(context)")
                            .font(.body)
                            .foregroundColor(.gray)
                            .fontWeight(.medium)
                        
                        // User-friendly description
                        Text(userFriendlyDescription)
                            .font(.callout)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                        
                        // System error description
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                        
                        
                            
                            Text("Please refresh the app in settings tab")
                                .padding(.horizontal, 40)
                                .padding(.vertical, 15)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .fontWeight(.bold)
                                .focusable(true)
                                .scaleEffect(1.1)

                            
                            Text("Report this error on reddit: https://www.reddit.com/user/iosDevAc. Please include a picture of this screen. Thanks!")
                                .lineLimit(4)
                                .multilineTextAlignment(.center)
                        
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right side - Technical details
                    VStack(alignment: .leading, spacing: 15) {
                        Text("🔧 TECHNICAL DETAILS")
                            .font(.headline)
                            .foregroundColor(.cyan)
                            .fontWeight(.bold)
                        
                        // Error type
                        Group {
                            Text("Type: \(String(describing: type(of: error)))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // Error domain and code (if NSError)
                        if let nsError = error as NSError? {
                            Group {
                                Text("Domain: \(nsError.domain)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                Text("Code: \(nsError.code)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                if !nsError.userInfo.isEmpty {
                                    Text("UserInfo: \(String(describing: nsError.userInfo).prefix(100))...")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                }
                            }
                        }
                        
                        // Memory info
                        Text("Memory: \(availableMemory)")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        // Timestamp
                        Text("Time: \(currentTimestamp)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        // Full error description (truncated)
                        Text("Details: \(String(describing: error).prefix(200))...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(6)
                    }
                    .padding(15)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                    )
                }
                .padding(20)
            }
        }
    }
    
    private var errorIcon: String {
        if let nsError = error as NSError?, nsError.domain == "SlideshowError" {
            return "photo.on.rectangle.angled"
        } else if error is ImmichError {
            return "network.slash"
        } else if error.localizedDescription.contains("memory") || error.localizedDescription.contains("Memory") {
            return "memorychip.fill"
        } else if error.localizedDescription.contains("network") || error.localizedDescription.contains("Network") {
            return "wifi.slash"
        } else if error.localizedDescription.contains("timeout") || error.localizedDescription.contains("Timeout") {
            return "clock.badge.exclamationmark"
        } else if error.localizedDescription.contains("index") || error.localizedDescription.contains("Index") || error.localizedDescription.contains("bounds") {
            return "list.number"
        } else if error.localizedDescription.contains("decode") || error.localizedDescription.contains("Decode") || error.localizedDescription.contains("parse") {
            return "doc.text.magnifyingglass"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var errorColor: Color {
        if let nsError = error as NSError?, nsError.domain == "SlideshowError" {
            return .orange
        } else if error is ImmichError {
            return .blue
        } else if error.localizedDescription.contains("memory") || error.localizedDescription.contains("Memory") {
            return .purple
        } else if error.localizedDescription.contains("network") || error.localizedDescription.contains("Network") {
            return .blue
        } else if error.localizedDescription.contains("timeout") || error.localizedDescription.contains("Timeout") {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var userFriendlyDescription: String {
        // Known specific errors
        if let immichError = error as? ImmichError {
            switch immichError {
            case .notAuthenticated:
                return "Authentication failed. Please check your login credentials and try again."
            case .forbidden:
                return "Access forbidden. Please check your permissions or contact your administrator."
            case .invalidURL:
                return "Invalid server URL. Please check your server configuration in settings."
            case .serverError(let statusCode):
                return "Server communication error (HTTP \(statusCode)). Please check your connection and server status."
            case .networkError:
                return "Network connection error. Please check your internet connection."
            case .clientError(let statusCode):
                return "Request error (HTTP \(statusCode)). Please try again or contact support if the issue persists."
            }
        }
        
        // Handle slideshow-specific errors
        if let nsError = error as NSError?, nsError.domain == "SlideshowError" {
            switch nsError.code {
            case 1001:
                return "Image navigation error. The slideshow encountered an issue with image ordering."
            case 1002:
                return "No images available. Please select an album with images."
            case 1003:
                return "Image loading error. The selected image could not be loaded or is corrupted."
            case 1004:
                return "Reached end of slideshow. All images have been displayed."
            case 1005:
                return "Memory error. The image is too large to display properly."
            case 1006:
                return "Timer error in slideshow automation. The automatic advance failed."
            default:
                return "Slideshow error occurred."
            }
        }
        
        // Generic error pattern matching
        let description = error.localizedDescription.lowercased()
        
        if description.contains("memory") || description.contains("out of memory") {
            return "Memory error. The app ran out of available memory. Try closing other apps."
        } else if description.contains("network") || description.contains("connection") || description.contains("timeout") {
            return "Network error. Please check your internet connection and try again."
        } else if description.contains("decode") || description.contains("parse") || description.contains("json") {
            return "Data parsing error. The server returned unexpected data format."
        } else if description.contains("index") || description.contains("bounds") || description.contains("range") {
            return "Data access error. The app tried to access data that doesn't exist."
        } else if description.contains("nil") || description.contains("null") {
            return "Missing data error. Required information was not available."
        } else if description.contains("permission") || description.contains("authorization") {
            return "Permission error. The app doesn't have required permissions."
        } else if description.contains("file") || description.contains("path") {
            return "File system error. Unable to access or save files."
        } else if description.contains("cast") || description.contains("type") {
            return "Data type error. Unexpected data format encountered."
        } else {
            return "An unexpected error occurred. This error type is not specifically handled yet."
        }
    }
    
    private var availableMemory: String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = info.resident_size
            return "\(usedMemory / 1024 / 1024) MB used"
        } else {
            return "Unable to determine"
        }
    }
    
    private var currentTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .full
        return formatter.string(from: Date())
    }
}

// MARK: - Universal Error Boundary Wrapper
struct ErrorBoundary<Content: View>: View {
    let content: Content
    let context: String
    
    @State private var hasError = false
    @State private var currentError: Error?
    
    init(context: String, @ViewBuilder content: () -> Content) {
        self.context = context
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if hasError, let error = currentError {
                UniversalErrorDisplayView(
                    error: error,
                    context: context,
                    onDismiss: {
                        resetError()
                    }
                )
            } else {
                content
                    .onReceive(NotificationCenter.default.publisher(for: .universalErrorOccurred)) { notification in
                        if let error = notification.object as? Error {
                            handleError(error)
                        }
                    }
            }
        }
        .onAppear {
            setupGlobalErrorHandling()
        }
    }
    
    private func handleError(_ error: Error) {
        print("ErrorBoundary [\(context)]: \(error)")
        currentError = error
        hasError = true
    }
    
    private func resetError() {
        hasError = false
        currentError = nil
    }
    
    private func setupGlobalErrorHandling() {
        // This could be expanded to catch system-level crashes
        NSSetUncaughtExceptionHandler { exception in
            let error = NSError(domain: "UncaughtException", code: -1, userInfo: [
                NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception",
                "name": exception.name.rawValue,
                "callStackSymbols": exception.callStackSymbols
            ])
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .universalErrorOccurred,
                    object: error
                )
            }
        }
    }
}

// MARK: - Global Error Broadcasting
extension Notification.Name {
    static let universalErrorOccurred = Notification.Name("universalErrorOccurred")
}

// MARK: - Global Error Handler
class GlobalErrorHandler {
    static let shared = GlobalErrorHandler()
    
    private init() {}
    
    func handleError(_ error: Error, context: String = "Unknown") {
        print("GlobalError [\(context)]: \(error)")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .universalErrorOccurred,
                object: error
            )
        }
    }
    
    func clearErrors() {
        print("GlobalErrorHandler: Clearing all error states")
        // Additional cleanup logic can be added here if needed
    }
}

// MARK: - Convenience Extensions
extension View {
    func errorBoundary(context: String ) -> some View {
        ErrorBoundary(context: context) {
            self
        }
    }
}

// MARK: - Preview
#Preview("Error Display") {
    let mockError = NSError(
        domain: "SlideshowError",
        code: 1003,
        userInfo: [
            NSLocalizedDescriptionKey: "Failed to load image from server. The image file may be corrupted or the network connection is unstable.",
            "errorCode": "IMG_LOAD_FAIL",
            "assetId": "abc123def456",
            "retryAttempts": 3
        ]
    )
    
    UniversalErrorDisplayView(
        error: mockError,
        context: "Photo Slideshow",
        onDismiss: { print("Preview: Dismissed error") }
    )
}
