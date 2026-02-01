# T-Pad

<p align="center">
  <img src="icon.png" width="150" alt="T-Pad Icon">
</p>

<p align="center">
  <strong>Turn your iPhone into a wireless trackpad for your Mac.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2016%2B%20%7C%20macOS%2013%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

Perfect for when your Magic Mouse dies, you're presenting from across the room, or you just prefer trackpad gestures. Zero configuration — just connect and go.

---

---

## ✨ Features

| Gesture | Action |
|---------|--------|
| **Slide** | Move cursor |
| **Tap** | Left click |
| **Double tap** | Double click |
| **Two-finger tap** | Right click |
| **Two-finger drag** | Scroll |
| **Tap, hold, drag** | Select text / Drag items |

**Plus:**
- 🖥️ **Multi-display support** — cursor moves seamlessly across all your monitors
- ⚡ **Low latency** — UDP protocol for real-time responsiveness  
- 🔧 **Adjustable sensitivity** — customize cursor speed to your preference
- 🔍 **Auto-discovery** — finds your Mac automatically via Bonjour/mDNS
- 🔒 **Local network only** — no internet, no cloud, no tracking

---

## 📥 Installation

### macOS Server

1. Download `TPad-x.x.x-mac.dmg` from [Releases](https://github.com/hjanuschka/tpad/releases)
2. Open the DMG and drag **T-Pad** to Applications
3. Launch T-Pad from Applications
4. Grant **Accessibility** permission when prompted:
   > System Settings → Privacy & Security → Accessibility → Enable T-Pad

The server runs in your menu bar — look for the 👆 icon.

### iOS App

Since T-Pad isn't on the App Store, you'll need to install it using one of these methods:

#### Option 1: Build with Xcode (Recommended)

Requires: Mac with Xcode 15+, Apple ID (free)

```bash
# Clone the repo
git clone https://github.com/hjanuschka/tpad.git
cd tpad

# Open in Xcode
open iOS/TPad.xcodeproj
```

In Xcode:
1. Select your iPhone as the build target
2. Go to **Signing & Capabilities**
3. Select your **Team** (your Apple ID)
4. Click **Run** (⌘R)

> **Note:** Free Apple IDs require re-installing every 7 days. Paid developer accounts last 1 year.

#### Option 2: AltStore / SideStore

1. Install [AltStore](https://altstore.io/) or [SideStore](https://sidestore.io/) on your iPhone
2. Download `TPad-x.x.x-ios.ipa` from [Releases](https://github.com/hjanuschka/tpad/releases)
3. Open the IPA with AltStore/SideStore to install

#### Option 3: Sideloadly (Windows/Mac)

1. Download [Sideloadly](https://sideloadly.io/)
2. Download `TPad-x.x.x-ios.ipa` from [Releases](https://github.com/hjanuschka/tpad/releases)
3. Connect your iPhone via USB
4. Drag the IPA into Sideloadly and sign with your Apple ID

#### Option 4: Xcode Command Line

```bash
# Clone and build
git clone https://github.com/hjanuschka/tpad.git
cd tpad

# Build for your device (replace TEAM_ID with your Apple Developer Team ID)
xcodebuild -project iOS/TPad.xcodeproj \
  -target TPad \
  -sdk iphoneos \
  -configuration Release \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  CONFIGURATION_BUILD_DIR=build \
  build

# Install to connected device
xcrun devicectl device install app --device YOUR_DEVICE_UDID build/TPad.app
```

Find your device UDID with:
```bash
xcrun devicectl list devices
```

---

## 🚀 Usage

1. Ensure both devices are on the **same WiFi network**
2. Launch **T-Pad** on your Mac (menu bar icon appears)
3. Open **T-Pad** on your iPhone
4. Tap **Connect to Mac**
5. Select your Mac from the list
6. Use the trackpad area to control your cursor!

---

## 🛠️ Building from Source

### Requirements

- macOS 13.0+ (Ventura or later)
- iOS 16.0+
- Xcode 15+ (for iOS app)
- Swift 5.9+

### Make Commands

```bash
# Build macOS server
make mac

# Build iOS app
make ios DEVELOPMENT_TEAM=YOUR_TEAM_ID

# Run macOS server
make run

# Clean build artifacts
make clean
```

---

## 🏗️ Architecture

```
┌──────────────┐         UDP/5679         ┌──────────────┐
│              │  ───────────────────────▶ │              │
│   iPhone     │      Touch events        │     Mac      │
│   (Client)   │                          │   (Server)   │
│              │  ◀─────────────────────  │              │
└──────────────┘     Bonjour discovery    └──────────────┘
```

### Protocol

Simple binary protocol over UDP for minimal latency:

```
┌────────┬────────┬────────┐
│  Type  │ DeltaX │ DeltaY │
│ 1 byte │ 4 bytes│ 4 bytes│
└────────┴────────┴────────┘
```

Message types: `move`, `leftClick`, `rightClick`, `scroll`, `dragStart`, `drag`, `dragEnd`, `setSensitivity`

### Project Structure

```
tpad/
├── Package.swift          # Swift Package (macOS server)
├── Makefile
├── Shared/
│   └── Protocol.swift     # Shared message protocol
├── macOS/
│   └── main.swift         # Menu bar server app
└── iOS/
    ├── TPad.xcodeproj
    └── TPad/
        ├── TPadApp.swift
        ├── ContentView.swift
        ├── TouchpadView.swift
        ├── NetworkClient.swift
        └── Protocol.swift
```

---

## 🔐 Permissions

### macOS
- **Accessibility** — Required to control mouse cursor and clicks

### iOS  
- **Local Network** — Required to discover and connect to Mac server

---

## 🐛 Troubleshooting

**Mac not appearing in the list?**
- Ensure both devices are on the same WiFi network
- Check that T-Pad server is running (look for 👆 icon in menu bar)
- Try restarting the T-Pad server

**Cursor not moving?**
- Grant Accessibility permission to T-Pad in System Settings
- You may need to remove and re-add the permission after updates

**iOS app won't install?**
- Free Apple IDs can only have 3 sideloaded apps at a time
- Try removing other sideloaded apps first
- Ensure your device is trusted on your Mac

**"Untrusted Developer" error on iOS?**
- Go to Settings → General → VPN & Device Management
- Tap your developer profile and tap "Trust"

**Connection drops frequently?**
- Move closer to your WiFi router
- Check for network congestion

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🤝 Contributing

Contributions welcome! Feel free to:
- Report bugs
- Suggest features  
- Submit pull requests

---

<p align="center">
  Made with ☕ for dead Magic Mouse batteries everywhere
</p>
