# T-Pad

Use your iPhone as a wireless trackpad for your Mac.

## Features

- **Cursor movement** - Slide finger to move cursor
- **Click** - Tap
- **Double click** - Double tap
- **Right click** - Two-finger tap
- **Scroll** - Two-finger drag
- **Drag & select** - Tap, hold, then drag
- **Multi-display** - Works across all connected displays
- **Adjustable speed** - Configure cursor sensitivity

## Requirements

- macOS 13.0+
- iOS 16.0+
- Both devices on the same WiFi network

## Installation

### macOS Server

```bash
# Build
cd TPad
swift build -c release

# Run
.build/release/TPadServer
```

Or build the app bundle:

```bash
make mac
open macOS/TPad.app
```

### iOS App

```bash
# Build and install (requires Xcode)
make ios

# Or open in Xcode
open iOS/TPad.xcodeproj
```

## Usage

1. Start T-Pad server on your Mac
2. Open T-Pad on your iPhone
3. Tap "Connect to Mac" and select your Mac
4. Use the trackpad!

## Permissions

- **macOS**: Accessibility permission required (System Settings → Privacy & Security → Accessibility)
- **iOS**: Local Network permission required (prompted on first use)

## Building

```bash
# macOS server
make mac

# iOS app (requires device or simulator)
make ios

# Clean
make clean
```

## License

MIT
