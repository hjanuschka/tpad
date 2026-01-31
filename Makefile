.PHONY: all mac ios clean

all: mac

# Build macOS server
mac:
	swift build -c release
	mkdir -p macOS/TPad.app/Contents/MacOS
	cp .build/release/TPadServer macOS/TPad.app/Contents/MacOS/
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > macOS/TPad.app/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> macOS/TPad.app/Contents/Info.plist
	@echo '<plist version="1.0"><dict>' >> macOS/TPad.app/Contents/Info.plist
	@echo '<key>CFBundleExecutable</key><string>TPadServer</string>' >> macOS/TPad.app/Contents/Info.plist
	@echo '<key>CFBundleIdentifier</key><string>com.tpad.server</string>' >> macOS/TPad.app/Contents/Info.plist
	@echo '<key>CFBundleName</key><string>T-Pad</string>' >> macOS/TPad.app/Contents/Info.plist
	@echo '<key>CFBundlePackageType</key><string>APPL</string>' >> macOS/TPad.app/Contents/Info.plist
	@echo '<key>CFBundleVersion</key><string>1.0</string>' >> macOS/TPad.app/Contents/Info.plist
	@echo '<key>LSMinimumSystemVersion</key><string>13.0</string>' >> macOS/TPad.app/Contents/Info.plist
	@echo '<key>LSUIElement</key><true/>' >> macOS/TPad.app/Contents/Info.plist
	@echo '<key>NSLocalNetworkUsageDescription</key><string>T-Pad needs network access.</string>' >> macOS/TPad.app/Contents/Info.plist
	@echo '<key>NSBonjourServices</key><array><string>_tpad._udp</string></array>' >> macOS/TPad.app/Contents/Info.plist
	@echo '</dict></plist>' >> macOS/TPad.app/Contents/Info.plist
	codesign --force --deep --sign - macOS/TPad.app
	@echo "Built: macOS/TPad.app"

# Build iOS app
ios:
	cd iOS && xcodebuild -project TPad.xcodeproj \
		-target TPad \
		-sdk iphoneos \
		-configuration Release \
		CODE_SIGN_STYLE=Automatic \
		CONFIGURATION_BUILD_DIR=../.build/ios \
		build
	@echo "Built: .build/ios/TPad.app"

# Run macOS server
run: mac
	open macOS/TPad.app

clean:
	rm -rfv .build
	rm -rfv macOS/TPad.app
	rm -rfv iOS/build iOS/.build
