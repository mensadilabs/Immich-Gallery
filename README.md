# Immich Gallery for Apple TV

A native Apple TV app for browsing your Immich photo library with a beautiful, TV-optimized interface.

![Login page](https://github.com/user-attachments/assets/64f526eb-d89e-4959-8be0-b7411f8fdc90)
![Gallery view](https://github.com/user-attachments/assets/6afe210d-6f6e-45a3-89d2-19ed48fce643)
![Full screen view](https://github.com/user-attachments/assets/6ab63005-bbcf-468a-9b83-b93f265fa348)
![Full screen view with people](https://github.com/user-attachments/assets/16b56fc4-ee74-4506-984a-46884bc65228)
![Album tab](https://github.com/user-attachments/assets/1dafee22-a04d-43c3-b0fc-a6ff01036b60)
![People tab](https://github.com/user-attachments/assets/057fef75-ebdb-40f1-ad07-349b0ddf740b)
<img width="1910" alt="Settings tab" src="https://github.com/user-attachments/assets/d5eae253-0475-47a4-8058-731c6e0fb85c" />


## Features

- 👥 **Multi User Support**: Alows more than one user to be logged in at the same time, with easy user switching. 
- 📱 **TV-Optimized Interface**: Designed specifically for Apple TV with large, easy-to-navigate elements
- 🖼️ **Photo Grid View**: Browse all your photos in a responsive grid layout
- 👥 **People Tab**: View and browse photos by people detected in your library
- 📁 **Album Support**: View and navigate through your Immich albums

## Setup Instructions

### 1. First Launch

When you first launch the app, you'll be prompted to sign in to your Immich server:

1. **Enter your server URL** (e.g., `https://your-immich-server.com` or `http://192.168.1.100:3001`)
2. **Enter your email** and **password**
3. **Tap Sign In**

The app will securely store your credentials and automatically sign you in on future launches.

### 2. Server Requirements

Your Immich server should be:
- Running and accessible from your Apple TV
- Configured with face recognition enabled (for People tab)
- Using HTTPS for remote access


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
│   ├── ImmichService.swift         # API service and authentication
│   └── ThumbnailCache.swift        # Efficient thumbnail caching
├── Views/
│   ├── AssetGridView.swift         # Main photo grid view
│   ├── AlbumListView.swift         # Album browsing view
│   ├── PeopleGridView.swift        # People browsing view
│   ├── FullScreenImageView.swift   # Full-screen photo viewing
│   ├── SignInView.swift            # Authentication interface
│   └── CacheManagementView.swift   # Cache management settings
├── ContentView.swift               # Main app interface
└── Immich_GalleryApp.swift         # App entry point
```

## Usage

### Photos Tab
- Browse all your photos in a grid layout
- Tap any photo to view it full-screen with navigation
- View EXIF information including camera settings and location
- Use the remote to navigate between photos
- Infinite scrolling with automatic loading

### People Tab
- Browse all people detected in your photo library
- Tap a person to view all photos featuring them
- See person names, birth dates, and favorite status
- Navigate through person photos in grid view

### Albums Tab
- View all your Immich albums
- Tap an album to see its contents
- Navigate through album photos in grid view

### Settings Tab
- Switch or add users.
- Manage thumbnail cache
- Clear cached data
- View cache statistics

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
- The app uses smart thumbnail caching for better performance
- Full-resolution images are loaded only when viewing full-screen
- Infinite scrolling loads photos in batches for smooth performance
- Cache management allows you to clear stored thumbnails if needed

## Security Notes

✅ **Security Features Implemented**:
- Secure credential storage using UserDefaults with encryption
- Automatic token validation and refresh
- HTTPS support for secure connections
- No hardcoded credentials in the source code


## Requirements

- Apple TV (4th generation or later)
- tvOS 15.0+
- Immich server running and accessible
- Network connectivity between Apple TV and Immich server
- Face recognition enabled on Immich server (for People tab)

## Development

This app is built with:
- SwiftUI for the user interface
- Async/await for modern concurrency
- URLSession for network requests
- UserDefaults for secure credential storage
- Core Image for image processing and caching