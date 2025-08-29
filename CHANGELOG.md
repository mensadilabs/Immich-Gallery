# VERSION|1.0.14

IMPROVEMENT| Slideshow optimizations
  - Rewrite SlideshowView for loading assets dynamically
  - Fix shared albums are duplicated
  - Fix slideshow does not work for shared-in albums
  - Bug fixes and performance improvements

# VERSION|1.0.12

BUGFIX| Fix more bugs
  - Make slideshow truly random, just like life. Outsourced this to the server. - #43 
  - Fix inactivity timer - Browse fast or the automatic slideshow will catch up to you - #43 
  - Remove date of birth from people tab - WAF+10 - #44

# VERSION|1.0.11

BUGFIX| Fix bugs
  - Top shef portraits no longer do unexpected headstands or cartwheels. I Hope. 
  - Hopefully it also won't crash. But you may see reduced image quality in top shelf. 
  - Better error handling.
  - Changed color gradient, this is much better on the eyes, I think. 


# version 1.0.7 Build 1

🎬 Animated Thumbnails

- **Dynamic Grid Previews**: Albums, People, and Tags now show animated slideshow previews of their content
- **Smooth Fade Transitions**: Gentle 1.5-second crossfades between thumbnails every 4 seconds
- **Smart Animation**: Pauses when focused, resumes when unfocused for better navigation
- **User Control**: New "Enable Thumbnail Animation" toggle in Settings (enabled by default)
- **Performance Optimized**: Uses thumbnail cache and loads maximum 10 images per animation

✨ Enhanced Visual Experience

- **Album Previews**: See actual photos from each album cycling in the thumbnail
- **People Previews**: View photos containing each person rotating through their thumbnail
- **Tag Previews**: Discover content in each tag through animated previews
- **Overlay Labels**: Subtle name overlays on animated thumbnails for better identification

⚙️ Settings Integration

- Added "Enable Thumbnail Animation" setting under Slideshow & Display settings
- Real-time setting changes - no restart required
- Descriptive subtitle: "Animate thumbnails in Albums, People, and Tags views"

🔧 Technical Improvements

- Consistent animation timing across all views
- Proper memory management and timer cleanup
- Graceful fallbacks when no images are available
- UserDefaults integration for persistent settings

---

version 1.0.4 Build 1

📊 EXIF Photo Information Display

- View detailed photo metadata in fullscreen mode by pressing the up arrow on your remote
- See camera settings, location, file size, resolution, and capture date
- Swipe down or press down arrow to dismiss the overlay

🏠 Customizable Default Tab

- Choose your preferred starting tab in Settings → Customization
- Options: All Photos, Albums, People, or Tags (if enabled)
- App now opens to your selected tab every time you launch

📚 Help & Tips Section

- New Help & Tips section in Settings explains key features:
  - Start Slideshow: Press play anywhere in the photo grid to begin slideshow from the
    highlighted image
  - Navigate Photos: Use arrow keys or swipe gestures to move between photos in fullscreen

Improvements

Better Settings Navigation

- Fixed picker behavior - settings now require a click/tap to change instead of changing
  when you just focus on them
- More intuitive menu-style pickers replace the old segmented controls

Misc:

- Updated navigation hints now show how to access photo details
- Consistent Date Formatting
