#!/bin/bash
set -e

echo "Installing Claude Code Monitor..."

# Check requirements
if ! command -v swift &> /dev/null; then
    echo "Error: Swift not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Clone and build
TMP=$(mktemp -d)
git clone https://github.com/CaGgAnN/claude-code-monitor.git "$TMP/claude-code-monitor"
cd "$TMP/claude-code-monitor"

echo "Building..."
swift build -c release

# Create app bundle
APP="$TMP/ClaudeMonitor.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp .build/release/ClaudeMonitor "$APP/Contents/MacOS/"

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ClaudeMonitor</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.claudemonitor.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Install
pkill ClaudeMonitor 2>/dev/null || true
rm -rf /Applications/ClaudeMonitor.app
cp -r "$APP" /Applications/

# Cleanup
rm -rf "$TMP"

echo "Done! Launching Claude Code Monitor..."
open /Applications/ClaudeMonitor.app
