![Build Status](https://github.com/mensadilabs/Immich-Gallery/actions/workflows/objective-c-xcode.yml/badge.svg?branch=main) ![Platform](https://img.shields.io/badge/platform-TvOS-blue) ![Language](https://img.shields.io/github/languages/top/mensadilabs/Immich-Gallery)

# Immich Gallery for Apple TV

A native Apple TV app for browsing your self-hosted Immich photo library with a beautiful, TV-optimized interface.

## Features

- 🖼️ **Photo Grid View**: Browse all your photos in a responsive grid layout with infinite scrolling
- 👥 **People Recognition**: View and browse photos by people detected in your library
- 📁 **Album Support**: View and navigate through your Immich albums
- 🏷️ **Tag Support with animated thubnails**: Browse photos by tags (optional, configurable)
- 🎬 **Slideshow Mode**: Full-screen slideshow with optional clock overlay
- 👤 **Multi-User Support**: Multiple user accounts with easy switching
- 📊 **EXIF Data**: View detailed photo metadata including camera settings and location
- 🔒 **Privacy First**: Self-hosted solution with secure credential storage, no data sent to third parties

<a href="https://www.buymeacoffee.com/zzpr69dnqtr" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-blue.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

<img width="1515" height="849" alt="image" src="https://github.com/user-attachments/assets/be1bcc49-2086-4a6f-9070-d3c62cb1be8a" />

https://github.com/user-attachments/assets/78987a7a-ef62-497c-828f-f7b99851ffb3

<img width="1527" height="857" alt="image" src="https://github.com/user-attachments/assets/f109e3b9-a617-49bd-815a-de452cb30f70" />


<img width="1530" height="863" alt="image" src="https://github.com/user-attachments/assets/3fdcb427-33f7-4538-bced-62ceaab0e609" />


![Full screen view with people](https://github.com/user-attachments/assets/16b56fc4-ee74-4506-984a-46884bc65228)

![Album tab](https://github.com/user-attachments/assets/1dafee22-a04d-43c3-b0fc-a6ff01036b60)

<img width="1917" alt="image" src="https://github.com/user-attachments/assets/7a8eb077-0811-4101-8e7c-69b34b03a536" />

<img width="3840" height="2160" alt="Simulator Screenshot - Apple TV 4K (3rd generation) - 2025-07-29 at 16 59 04" src="https://github.com/user-attachments/assets/f156ade2-1e59-4c00-ac15-6f05205ddb7a" />

<img width="3840" height="2160" alt="Simulator Screenshot - Apple TV 4K (3rd generation) - 2025-07-29 at 17 00 05" src="https://github.com/user-attachments/assets/3f646593-e310-4d39-827c-c4d02179d45f" />


## Requirements

- Apple TV (4th generation or later)
- tvOS 15.0+
- Immich server running and accessible
- Network connectivity between Apple TV and Immich server

## Quick Start

1. **Launch the app** - You'll be prompted to sign in to your Immich server
2. **Enter server details** - Server URL (e.g., `https://your-immich-server.com`), email, and password
3. **Browse your photos** - Navigate using the Apple TV remote or Siri Remote

## Technical Details

### Architecture

```
Immich Gallery/
├── Models/
│   └── ImmichModels.swift          # Data models for Immich API responses
├── Services/
│   ├── AuthenticationService.swift # User authentication and session management
│   ├── NetworkService.swift        # Core HTTP networking layer
│   ├── AssetService.swift          # Photo/video asset management
│   ├── AlbumService.swift          # Album data handling
│   ├── PeopleService.swift         # People recognition integration
│   ├── TagService.swift            # Tag-based photo organization
│   └── ThumbnailCache.swift        # Efficient image caching system
├── Views/
│   ├── AssetGridView.swift         # Main photo grid interface
│   ├── FullScreenImageView.swift   # Full-screen photo viewer
│   ├── SlideshowView.swift         # Slideshow functionality
│   └── Settings/                   # Configuration interfaces
├── Extensions/
│   └── DateFormatter+Extensions.swift
└── ContentView.swift               # Main app coordinator
```

### Technology Stack

- **SwiftUI**: Modern declarative UI framework
- **Async/Await**: Modern Swift concurrency for network operations
- **URLSession**: HTTP networking with custom authentication
- **UserDefaults**: Secure credential storage with encryption
- **Core Image**: Image processing and thumbnail generation
- **AVKit**: Video playback support

### Network & API Integration

- **Immich REST API**: Full integration with Immich server endpoints
- **Authentication**: Bearer token-based authentication with automatic refresh
- **Caching Strategy**: Multi-layer caching for thumbnails and metadata
- **Error Handling**: Comprehensive error boundaries and retry mechanisms

### Performance Optimizations

- **Lazy Loading**: Photos loaded on-demand as user scrolls
- **Thumbnail Caching**: Persistent cache with configurable size limits
- **Memory Management**: Efficient image loading with automatic cleanup
- **Background Processing**: Non-blocking API calls for smooth UI

### Security Features

- **Credential Encryption**: Secure storage of server credentials
- **HTTPS Support**: Encrypted communication with Immich server
- **Token Validation**: Automatic token refresh and validation
- **No Telemetry**: No data collection or external service communication

### Configuration Options

- **Default Tab**: Customizable startup tab (Photos, Albums, People, Tags)
- **Slideshow Settings**: Configurable timing and overlay options
- **Cache Management**: User-controlled cache size and cleanup
- **Multi-User**: Support for multiple Immich accounts

## Development

### Building from Source

1. Clone the repository
2. Open `Immich Gallery.xcodeproj` in Xcode
3. Select Apple TV target device
4. Build and run

### Dependencies

This project uses only system frameworks and has no external dependencies.

## Troubleshooting

### Authentication Issues

- Verify server URL includes protocol (`http://` or `https://`)
- Ensure Immich server is accessible from Apple TV network
- Check firewall settings and port configuration

### Performance Issues

- Monitor cache usage in Settings > Cache Management
- Clear cached data if storage is full
- Ensure stable network connection for optimal loading

![Alt](https://repobeats.axiom.co/api/embed/3fea253de89fc88824c16adb77a456f7e7d657b7.svg "Repobeats analytics image")
<iframe style="width:100%;height:auto;min-width:600px;min-height:400px;" src="https://www.star-history.com/embed?secret=Z2l0aHViX3BhdF8xMUJVRlkzNFEwZU4xMFVxcGd2dDhiX1BuTmRJZ2xhczZQSkszVFFMTjdOdGdXMzlWRHpPQXdYeTdwbEpobE84eVZXTEpET1kzM2pLQ0psZ0VU#mensadilabs/Immich-Gallery&Timeline" frameBorder="0"></iframe>
