# Immich Gallery for Apple TV

A native Apple TV app for browsing your Immich photo library with a beautiful, TV-optimized interface.

## Features

- 📱 **TV-Optimized Interface**: Designed specifically for Apple TV with large, easy-to-navigate elements
- 🖼️ **Photo Grid View**: Browse all your photos in a responsive grid layout
- 📁 **Album Support**: View and navigate through your Immich albums
- 🔍 **Full-Screen Viewing**: Tap any photo to view it in full-screen mode
- 🎥 **Video Support**: Displays video thumbnails with play indicators
- 🔄 **Real-time Sync**: Automatically syncs with your Immich server

## Setup Instructions

### 1. Configure Server Settings

Before running the app, you need to update the server configuration in `Immich Gallery/Services/ImmichService.swift`:

```swift
// Update these values with your Immich server details
private let baseURL = "http://192.168.1.100:3001" // Your Immich server URL
private let email = "admin@example.com" // Your Immich email
private let password = "password123" // Your Immich password
```

**Important**: Replace the placeholder values with your actual Immich server details:
- `baseURL`: The URL where your Immich server is running (e.g., `http://192.168.1.100:3001` or `https://your-domain.com`)
- `email`: Your Immich account email address
- `password`: Your Immich account password

### 2. Network Configuration

For Apple TV to connect to your Immich server:

1. **Local Network**: If your Immich server is on the same network as your Apple TV, use the local IP address
2. **Remote Access**: If accessing remotely, ensure your server is accessible via HTTPS
3. **Firewall**: Make sure your Immich server port (default 3001) is accessible

### 3. Build and Run

1. Open the project in Xcode
2. Select your Apple TV as the target device
3. Build and run the app

## App Structure

```
Immich Gallery/
├── Models/
│   └── ImmichModels.swift          # Data models for Immich API
├── Services/
│   └── ImmichService.swift         # API service and authentication
├── Views/
│   ├── AssetGridView.swift         # Main photo grid view
│   └── AlbumListView.swift         # Album browsing view
├── ContentView.swift               # Main app interface
└── Immich_GalleryApp.swift         # App entry point
```

## Usage

### Photos Tab
- Browse all your photos in a grid layout
- Tap any photo to view it full-screen
- Use the remote to navigate between photos
- Pull to refresh to sync with your server

### Albums Tab
- View all your Immich albums
- Tap an album to see its contents
- Navigate through album photos in grid view

## Troubleshooting

### Authentication Issues
- Verify your email and password are correct
- Ensure your Immich server is running and accessible
- Check that your server URL is correct (including protocol and port)

### Network Issues
- Make sure your Apple TV and Immich server are on the same network
- Check firewall settings on your server
- Verify the Immich server port is open

### Performance Issues
- The app loads thumbnails for better performance
- Full-resolution images are loaded only when viewing full-screen
- Consider reducing the number of photos loaded per page if experiencing slow performance

## Security Notes

⚠️ **Important**: This app currently uses hardcoded credentials for demonstration purposes. For production use, consider implementing:

- Secure credential storage
- OAuth authentication
- Certificate pinning for HTTPS connections
- Environment-based configuration

## Requirements

- Apple TV (4th generation or later)
- iOS 15.0+
- Immich server running and accessible
- Network connectivity between Apple TV and Immich server

## Development

This app is built with:
- SwiftUI for the user interface
- Combine for reactive programming
- URLSession for network requests
- Async/await for modern concurrency

## License

This project is for educational and personal use. Please respect Immich's terms of service and your server's security policies. 