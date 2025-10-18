![Build Status](https://github.com/mensadilabs/Immich-Gallery/actions/workflows/objective-c-xcode.yml/badge.svg?branch=main) ![Platform](https://img.shields.io/badge/platform-TvOS-blue) ![Language](https://img.shields.io/github/languages/top/mensadilabs/Immich-Gallery)

# Immich Gallery for Apple TV

A native Apple TV app for browsing your self-hosted Immich photo library with a TV-optimized interface.

## Features

- 🖼️ **Photo Grid View**: Browse your library in a fast, infinite-scrolling grid
- 👥 **People Recognition**: Jump straight to people Immich detects in your photos
- 📁 **Album Support**: Navigate personal and shared Immich albums
- 🏷️ **Tag Support with animated thumbnails**: Optional tag tab with looping previews
- 🗂️ **Folders Tab** : View external libray folders.
- 🔍 **Explore Tab**: Discover stats, locations, and highlights from your library
- 📺 **Top Shelf Customization**: Pick featured or random photos for the Apple TV top shelf
- 🎬 **Slideshow Mode**: Full-screen slideshow with optional clock overlay
- 👤 **Multi-User Support**: Store multiple accounts and switch instantly
- 📊 **EXIF Data**: Inspect camera details and location metadata
- 🔒 **Privacy First**: Pure client, keeps credentials local

  <a href="https://www.buymeacoffee.com/zzpr69dnqtr" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-blue.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

## Requirements

- Apple TV (4th generation or later)
- tvOS 15.0+
- Immich server running and accessible
- Network connectivity between Apple TV and Immich server

## Quick Start

1. **Launch the app** - You'll be prompted to sign in to your Immich server
2. **Enter credentials** - Provide the server URL (e.g., `https://your-immich-server.com`) plus either email & password or an Immich API key
3. **Browse your photos** - Navigate using the Apple TV remote or Siri Remote

> [!NOTE]
>
> - Stuck on "Data couldn't read because its missing"? Update Immich and retry: https://github.com/mensadilabs/Immich-Gallery/issues/67
> - OAuth / OIDC sign-in needs server-side changes (tracked in https://github.com/mensadilabs/Immich-Gallery/issues/77). Use an Immich API key instead.
> - FaceID / PIN locking is currently out of scope. https://github.com/mensadilabs/Immich-Gallery/issues/64

### Building from Source

1. Clone the repository
2. Open `Immich Gallery.xcodeproj` in Xcode
3. Select Apple TV target device
4. Build and run

<img width="3840" height="2160" alt="Simulator Screenshot - Apple TV 4K (3rd generation) - 2025-08-11 at 18 23 16" src="https://github.com/user-attachments/assets/c802a515-e775-4068-af4c-0f90879cf41b" />
<img width="1515" height="849" alt="image" src="https://github.com/user-attachments/assets/be1bcc49-2086-4a6f-9070-d3c62cb1be8a" />

https://github.com/user-attachments/assets/78987a7a-ef62-497c-828f-f7b99851ffb3

<img width="1527" height="857" alt="image" src="https://github.com/user-attachments/assets/f109e3b9-a617-49bd-815a-de452cb30f70" />

<img width="1530" height="863" alt="image" src="https://github.com/user-attachments/assets/3fdcb427-33f7-4538-bced-62ceaab0e609" />

![Full screen view with people](https://github.com/user-attachments/assets/16b56fc4-ee74-4506-984a-46884bc65228)

![Album tab](https://github.com/user-attachments/assets/1dafee22-a04d-43c3-b0fc-a6ff01036b60)

<img width="1917" alt="image" src="https://github.com/user-attachments/assets/7a8eb077-0811-4101-8e7c-69b34b03a536" />

<img width="3840" height="2160" alt="Simulator Screenshot - Apple TV 4K (3rd generation) - 2025-07-29 at 16 59 04" src="https://github.com/user-attachments/assets/f156ade2-1e59-4c00-ac15-6f05205ddb7a" />

<img width="3840" height="2160" alt="Simulator Screenshot - Apple TV 4K (3rd generation) - 2025-07-29 at 17 00 05" src="https://github.com/user-attachments/assets/3f646593-e310-4d39-827c-c4d02179d45f" />

## Stats

![Alt](https://repobeats.axiom.co/api/embed/3fea253de89fc88824c16adb77a456f7e7d657b7.svg "Repobeats analytics image")

[![Star History Chart](https://api.star-history.com/svg?repos=mensadilabs/Immich-Gallery&type=Timeline)](https://www.star-history.com/#mensadilabs/Immich-Gallery&Timeline)
