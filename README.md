# Claude Code Monitor

A lightweight macOS menu bar app that shows your Claude Code usage limits in real time.

## Features

- Robot pixel icon in your menu bar with live session %
- Current session (5h) and weekly usage donuts
- Countdown timer to next session reset
- Auto-refreshes every 60 seconds
- Native Swift/AppKit — no Electron, no WebView, zero animation jank
- Reads your existing Claude Code credentials — no API key setup needed

## Requirements

- macOS 13+
- Claude Code installed and logged in

## Installation

### Build from source

```bash
git clone https://github.com/yourusername/claude-code-monitor.git
cd claude-code-monitor
swift build -c release
mkdir -p ClaudeMonitor.app/Contents/MacOS
cp .build/release/ClaudeMonitor ClaudeMonitor.app/Contents/MacOS/
cp -r ClaudeMonitor.app /Applications/
open /Applications/ClaudeMonitor.app
```

## How it works

Reads your Claude Code OAuth token from macOS Keychain and makes a minimal API call to get usage from response headers:

- `anthropic-ratelimit-unified-5h-utilization` — Current session %
- `anthropic-ratelimit-unified-7d-utilization` — Weekly %
- `anthropic-ratelimit-unified-5h-reset` — Reset timestamp

## Usage

- Left click the menu bar icon to open/close the widget
- Right click → Quit to exit
- Login on startup: System Settings → General → Login Items → add ClaudeMonitor

## Privacy

All data stays local. Only network request is to api.anthropic.com using your own credentials.

## License

MIT
