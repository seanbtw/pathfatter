# PathFatter 🚀

**Beautiful, instant path conversion for macOS**

[![Build](https://github.com/seanbtw/pathfatter/actions/workflows/build.yml/badge.svg)](https://github.com/seanbtw/pathfatter/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange)](https://swift.org)

PathFatter is a modern macOS app that instantly converts Windows and SharePoint paths to macOS equivalents (and vice versa). Built with SwiftUI, featuring stunning glassmorphism UI, smart animations, and complete accessibility support.

---

## ✨ Features

### 🎨 Beautiful UI
- **Glassmorphism design** with multi-layer depth and animated gradient orbs
- **Time-based accent colors** that adapt throughout the day
- **Spring animations** for all interactions (with reduced motion support)
- **Syntax highlighting** for path components
- **Floating label** input fields

### ⚡ Instant Conversion
- Windows paths → macOS (e.g., `C:\Temp\file.txt` → `/Volumes/C/Temp/file.txt`)
- macOS paths → Windows (e.g., `/Volumes/C/Temp` → `C:\Temp`)
- SharePoint URLs → Local OneDrive paths
- UNC/SMB paths support (e.g., `\\server\share` ↔ `smb://server/share`)

### 📜 Smart History
- **Grouped by date** (Today, Yesterday, This Week, Older)
- **Pin frequently-used paths** to the top
- **Search** through history
- **Keyboard navigation** (↑↓ to select, Enter to copy)

### 🎯 Productivity
- **Drag & drop** files/folders to get their paths
- **Keyboard shortcuts** for all actions (⌘C, ⌘O, ⌘S, ⌘V, Escape)
- **Clipboard integration** with one-click copy
- **Open in Finder** directly from converted paths

### ♿ Fully Accessible
- **VoiceOver** support with custom labels
- **Dynamic type** scaling
- **High contrast** mode adaptation
- **Reduced motion** support
- **Keyboard-only navigation**

---

## 📥 Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/seanbtw/pathfatter.git
cd pathfatter

# Open in Xcode
open PathFatter.xcodeproj

# Build and run (⌘R)
```

**Requirements:**
- macOS 14.0 or later
- Xcode 15.0 or later

### Option 2: App Store (Coming Soon)

PathFatter will be available on the Mac App Store. Stay tuned!

### Option 3: Direct Download (Coming Soon)

Signed and notarized releases will be available on the [Releases page](https://github.com/seanbtw/pathfatter/releases).

---

## 🚀 Quick Start

1. **Open the project** in Xcode
2. **Build and Run** (⌘R)
3. **Complete onboarding** (4 quick slides)
4. **Start converting paths!**

### First Launch

On first launch, you'll see an interactive onboarding carousel that explains:
- Instant path conversion
- Custom drive mappings
- SharePoint URL support
- History and pinning features

You can skip onboarding and access it later via Settings.

---

## 📖 Usage

### Convert a Windows Path

1. Paste a Windows path (e.g., `C:\Users\name\Documents\file.docx`)
2. Instantly see the macOS equivalent (`/Volumes/C/Users/name/Documents/file.docx`)
3. Click **Copy** (⌘C) or **Open in Finder** (⌘O)

### Convert a SharePoint URL

1. Paste a SharePoint URL from your browser
2. PathFatter converts it to your local OneDrive folder path
3. Configure SharePoint mappings in Settings (⌘,)

### Custom Drive Mappings

Map your Windows drive letters to macOS folders:

1. Open **Settings** (⌘,)
2. Go to **Drive Mappings**
3. Add a new mapping:
   - **Windows Drive:** `K` (for K:\)
   - **macOS Folder:** `smb://server/share/Projects` or `/Volumes/Projects`
4. Validation indicators show if your mapping is valid

### Pin Frequently-Used Paths

1. Convert a path
2. Open **History** (click the clock button)
3. Hover over the item and click the **pin** icon
4. Pinned items appear at the top of history

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘V` | Paste into input |
| `⌘C` | Copy output path |
| `⌘O` | Open in Finder |
| `⌘S` | Swap input/output |
| `Escape` | Clear input |
| `↑` / `↓` | Navigate history |
| `Enter` | Copy selected history item |
| `⌘,` | Open Settings |

---

## 🎨 UI Highlights

### Glassmorphism Design

PathFatter uses multi-layer glassmorphism with:
- Gradient fills (0.8 → 0.4 opacity)
- Inner shadows for depth
- Animated gradient orbs in background
- Gradient border strokes
- Dynamic shadows that respond to hover

### Dynamic Accent Colors

The app's accent color changes based on time of day:
- **Morning (6AM-12PM):** Warm blue
- **Afternoon (12PM-6PM):** Standard blue
- **Evening (6PM-12AM):** Purple-blue
- **Night (12AM-6AM):** Deep indigo

### Micro-Interactions

Every interaction feels responsive:
- **Conversion flash** - Green pulse when conversion completes
- **Copy success** - Scale bounce + checkmark morph
- **Hover effects** - Cards scale to 1.02-1.05x on hover
- **Spring animations** - Throughout the app (response: 0.3, damping: 0.7)

---

## ⚙️ Settings

### Drive Mappings
- Map Windows drive letters to macOS paths
- Support for SMB network paths
- Import/Export mappings as JSON
- Real-time validation with visual feedback

### SharePoint Mappings
- Map SharePoint URL prefixes to local OneDrive folders
- Auto-detects OneDrive installation
- Support for multiple SharePoint sites

### Browser Integration
- Enable `pathfatter://` deep links from browser
- Auto-open converted folders in Finder
- Auto-copy converted paths to clipboard
- Safari extension support (build separately)

---

## 📁 Project Structure

```
PathFatter/
├── .github/
│   └── workflows/
│       └── build.yml          # GitHub Actions CI
├── PathFatter.xcodeproj       # Xcode project
├── PathFatter/                # Main app source
│   ├── PathFatterApp.swift    # App entry point
│   ├── ContentView.swift      # Main UI
│   ├── SettingsView.swift     # Settings UI
│   ├── OnboardingView.swift   # First-launch onboarding
│   ├── PathConverter.swift    # Conversion logic
│   ├── PathMappingStore.swift # State management
│   ├── BrowserIntegrationHelper.swift
│   └── Assets.xcassets        # App icons and assets
├── PathFatterSafariWebExtension/
├── README.md                  # This file
├── LICENSE                    # MIT License
├── CHANGELOG.md               # Version history
├── PRIVACY_POLICY.md          # Privacy policy
└── PRODUCTION_READINESS.md    # Distribution guide
```

---

## 🔧 Technical Details

### Requirements
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### Dependencies
- **None!** Pure SwiftUI with no third-party libraries

### Architecture
- **MVVM** pattern with `ObservableObject` state management
- **Debounced saves** to UserDefaults (0.3-0.5s delay)
- **Thread-safe** data snapshots for background operations
- **Lazy loading** for history items

### Performance
- Efficient `GeometryReader` usage (single instance)
- Cached color calculations
- Pre-rendered blur backgrounds
- Spring animations optimized for 60fps

---

## 🎯 Code Quality

### Implemented Best Practices

✅ **Memory Safety**
- `[weak self]` in all async closures
- Data snapshots for background operations
- No retain cycles

✅ **Thread Safety**
- All `@Published` properties modified on main thread
- Background saves use captured snapshots
- Debounced operations prevent race conditions

✅ **Error Handling**
- Try/catch for file operations
- User-friendly error messages
- Graceful fallbacks

✅ **Validation**
- Real-time input validation in Settings
- Visual feedback (green checks, orange warnings)
- Helper tooltips

✅ **Accessibility**
- Full VoiceOver support
- Keyboard navigation
- Reduced motion support
- Dynamic type scaling

---

## 📝 License

MIT License - feel free to use, modify, and distribute. See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

Design inspiration from:
- **Linear** - Smooth animations and depth
- **Raycast** - macOS-native patterns
- **Arc Browser** - Glassmorphism excellence
- **Cron** - Time-based adaptations
- **Superhuman** - Keyboard-first design

---

## 📬 Contact

- **GitHub:** https://github.com/seanbtw/pathfatter
- **Issues:** https://github.com/seanbtw/pathfatter/issues
- **Privacy Policy:** [PRIVACY_POLICY.md](PRIVACY_POLICY.md)

Built with ❤️ using SwiftUI

---

## 🗺️ Roadmap

- [ ] Mac App Store release
- [ ] Direct download (DMG) with notarization
- [ ] iOS/iPadOS version
- [ ] Sync mappings via iCloud
- [ ] Batch path conversion
- [ ] Custom themes
- [ ] Menu bar quick access
