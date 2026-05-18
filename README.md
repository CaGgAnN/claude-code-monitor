# Claude Code Monitor

A native macOS menu bar app that shows your Claude Code usage limits in real time — current session % and weekly %, built with Swift/AppKit.

## What it looks like

- A pixel robot icon sits in your menu bar
- Next to it, your current session usage percentage (e.g. `32%`)
- Click it to open a widget showing:
  - **Current** — 5-hour session usage donut
  - **Weekly** — 7-day usage donut  
  - **Next session** — countdown timer to your next reset
  - **Week** — weekly usage percentage

## How it works

Claude Code stores your OAuth credentials in macOS Keychain under `Claude Code-credentials`. This app:

1. Reads your access token from Keychain at startup
2. Makes a minimal API call every 60 seconds to `api.anthropic.com/v1/messages` (1 token of claude-haiku — essentially free)
3. Reads usage data directly from the response headers:
   - `anthropic-ratelimit-unified-5h-utilization` → Current session %
   - `anthropic-ratelimit-unified-7d-utilization` → Weekly %
   - `anthropic-ratelimit-unified-5h-reset` → Unix timestamp of next reset
4. Displays everything in a native AppKit popover panel

No scraping, no reverse engineering — Anthropic sends this data in every API response.

## Requirements

- macOS 13 or later
- Claude Code installed and logged in (run `claude` at least once)
- Swift toolchain (comes with Xcode Command Line Tools)

## Installation

### One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/CaGgAnN/claude-code-monitor/main/install.sh | bash
```

This clones the repo, builds it, creates the app bundle, and installs to `/Applications/`.

### Build from source

```bash
# Clone the repo
git clone https://github.com/yourusername/claude-code-monitor.git
cd claude-code-monitor

# Build
swift build -c release

# Create app bundle
mkdir -p ClaudeMonitor.app/Contents/MacOS
cp .build/release/ClaudeMonitor ClaudeMonitor.app/Contents/MacOS/
cp Info.plist ClaudeMonitor.app/Contents/

# Install
cp -r ClaudeMonitor.app /Applications/
open /Applications/ClaudeMonitor.app
```

## Usage

| Action | Result |
|--------|--------|
| Left click icon | Open / close widget |
| Right click icon | Show quit menu |
| Quit | Closes the app |

### Launch on startup

System Settings → General → Login Items → click `+` → select `ClaudeMonitor.app`

### Uninstall

```bash
pkill ClaudeMonitor
rm -rf /Applications/ClaudeMonitor.app
```

## Privacy & Security

- Your token never leaves your machine except to Anthropic's own API
- No analytics, no telemetry, no third-party requests
- All credential access goes through macOS Keychain — the same way Claude Code itself does it
- Open source — read every line

## Technical details

Built with pure Swift + AppKit. No Electron, no WebKit, no web views. The widget is a native `NSPanel` with `NSVisualEffectView` for the blur/glass background. Donut charts are drawn with `NSBezierPath`. The tray icon is rendered programmatically as a pixel art robot.

## License

MIT

## Troubleshooting

**Values showing 0%?**

Your Claude Code token may have expired. Run this in your terminal to refresh it:

```bash
claude -p "hi"
```

Then restart Claude Monitor. This only happens if you haven't used Claude Code for a while.
