# T-Pad

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2016%2B%20%7C%20macOS%2013%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

**Turn your iPhone into a wireless trackpad for your Mac.**

Perfect for when your Magic Mouse dies, you're presenting from across the room, or you just prefer trackpad gestures. Zero configuration — just connect and go.

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

## 📱 Screenshots

```
┌─────────────────────────┐
│         T-Pad           │
│                         │
│  ┌───────────────────┐  │
│  │                   │  │
│  │    Touch here     │  │
│  │    to control     │  │
│  │    your Mac       │  │
│  │                   │  │
│  └───────────────────┘  │
│                         │
│  Speed: ●━━━━━━━━━━━━━  │
│                         │
│  [  Connect to Mac  ]   │
└─────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Install the Mac Server

```bash
git clone https://github.com/hjanuschka/tpad.git
cd tpad
make mac
open macOS/TPad.app
```

Grant **Accessibility** permission when prompted:
> System Settings → Privacy & Security → Accessibility → Enable T-Pad

### 2. Install the iOS App

**Option A: Build from source**
```bash
make ios DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

**Option B: Open in Xcode**
```bash
open iOS/TPad.xcodeproj
```

### 3. Connect

1. Ensure both devices are on the same WiFi network
2. Open T-Pad on your iPhone
3. Tap **Connect to Mac**
4. Select your Mac from the list
5. Start using your phone as a trackpad!

---

## 🛠️ Building

### Requirements

- macOS 13.0+ (Ventura or later)
- iOS 16.0+
- Xcode 15+ (for iOS app)
- Swift 5.9+

### Make Commands

```bash
# Build macOS server
make mac

# Build iOS app (requires Xcode and signing)
make ios DEVELOPMENT_TEAM=YOUR_TEAM_ID

# Run macOS server
make run

# Clean build artifacts
make clean
```

### Manual Build

**macOS Server:**
```bash
swift build -c release
.build/release/TPadServer
```

**iOS App:**
```bash
xcodebuild -project iOS/TPad.xcodeproj \
  -target TPad \
  -sdk iphoneos \
  -configuration Release \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  build
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
- Check that T-Pad server is running (look for icon in menu bar)
- Try restarting the T-Pad server

**Cursor not moving?**
- Grant Accessibility permission to T-Pad in System Settings
- You may need to remove and re-add the permission after updates

**Connection drops frequently?**
- Move closer to your WiFi router
- Check for network congestion

**High latency?**
- T-Pad uses UDP for minimal latency
- If you experience lag, your network may be congested

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
