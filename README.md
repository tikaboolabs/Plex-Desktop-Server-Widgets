# Plex Desktop Widgets for macOS

Live desktop widgets for Plex Media Server — now playing, bandwidth, and system stats updating every 2 seconds.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

<!-- Add your screenshot here -->
<!-- ![Screenshot](screenshots/desktop.png) -->

## What Is This?

Three persistent desktop widgets that monitor your Plex server in real time:

- **Now Playing** — Active streams with poster art, playback progress, user, player device, quality badges (4K, HDR, Transcode), bandwidth per stream, and animated equalizer
- **System** — CPU and RAM gauges with 60-second sparkline history, using native macOS Mach kernel APIs that match Activity Monitor exactly
- **Bandwidth** — Real-time throughput from active sessions split into LAN vs WAN with a rolling chart

The widgets float just above your desktop wallpaper but behind all normal windows — they behave like native macOS widgets. Drag them anywhere you like. Runs as a menu bar app with no Dock icon.

## Why Not WidgetKit?

Apple's WidgetKit framework has two dealbreakers for this use case:

1. **Requires a $99/year Apple Developer account** to sign WidgetKit extensions. Not worth it for a personal tool.
2. **Timeline-based refresh only** — Apple controls when your widget updates, with the fastest reliable refresh being every 5–15 minutes. Useless for monitoring active streams and real-time bandwidth.

Instead, this app uses borderless transparent `NSPanel` windows pinned to the desktop layer, polling your Plex server every 2 seconds. Same visual result, no developer account needed, real-time data.

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Xcode 15+** (free from the App Store — no paid developer account needed)
- **XcodeGen** (to generate the Xcode project from `project.yml`)
- A **Plex Media Server** on your local network

## Build & Install

### 1. Install XcodeGen

If you don't have it already:

```bash
brew install xcodegen
```

Don't have Homebrew? Install it first: https://brew.sh

### 2. Clone and Generate the Xcode Project

```bash
git clone https://github.com/tikaboolabs/Plex-Desktop-Server-Widgets.git
cd Plex-Desktop-Server-Widgets
xcodegen generate
```

This creates `PlexDesktopWidgets.xcodeproj` from the `project.yml` spec.

### 3. Open in Xcode

```bash
open PlexDesktopWidgets.xcodeproj
```

### 4. Set Build Configuration to Release

In Xcode:
1. Click **Product → Scheme → Edit Scheme…** (or press `⌘<`)
2. Select **Run** on the left sidebar
3. Change **Build Configuration** from `Debug` to **`Release`**
4. Click **Close**

### 5. Build

Press **⌘B** (or **⌘R** to build and run immediately).

If Xcode asks you to trust the project or its plugins, click **Trust**.

### 6. Get the Built App

1. In Xcode, go to **Product → Show Build Folder in Finder**
2. Navigate to **`Build/Products/Release/`**
3. You'll see **`Plex Desktop Widgets.app`**
4. **Drag it to your `/Applications` folder**

### 7. Launch & Configure

1. Open **Plex Desktop Widgets** from Applications
2. A ▶ icon appears in your **menu bar** (no Dock icon — this is intentional)
3. Click the ▶ icon → **Settings…**
4. Enter your **Server URL** (e.g., `http://192.168.1.100:32400`)
5. Enter your **Plex Token** (see below)
6. Click **Test** to verify the connection, then **Save**

The three widgets will appear on your desktop. Drag them wherever you want — positions are remembered between launches.

### 8. Start on Login (Optional)

To have the widgets launch automatically:
1. Open **System Settings → General → Login Items**
2. Click **+** and select **Plex Desktop Widgets** from Applications

## Finding Your Plex Token

Your Plex token is a short string (~20 characters) that authenticates API requests.

**Method 1 — Browser DevTools:**
1. Open your Plex server in a web browser
2. Open DevTools (**F12** or **⌘⌥I**)
3. Go to the **Network** tab
4. Play something or navigate around
5. Click any request to your server and look for `X-Plex-Token` in the URL parameters or headers

**Method 2 — Plex XML:**
1. Sign in to Plex in your browser
2. Visit: `https://plex.tv/devices.xml`
3. Search the page for `token="` — that's your token

**Method 3 — From a media item:**
1. In Plex web, click the **⋯** menu on any movie or show
2. Click **Get Info → View XML**
3. Look for `X-Plex-Token=` in the URL bar

## Menu Bar Options

Click the ▶ icon in your menu bar to:

| Option | Description |
|--------|-------------|
| **Now Playing** | Toggle the Now Playing widget on/off |
| **Bandwidth** | Toggle the Bandwidth widget on/off |
| **System** | Toggle the System widget on/off |
| **Refresh Now** | Force an immediate data refresh |
| **Reset Positions** | Reset all widgets to default positions |
| **Settings…** | Configure server URL and token |
| **Quit** | Exit the app |

## Technical Details

- **Native Swift/AppKit** — no Electron, no web views, no external dependencies
- **Borderless NSPanel windows** at desktop+1 level with transparent backgrounds
- **Poster art** fetched from Plex's built-in photo transcoder (`/photo/:/transcode`)
- **CPU/RAM** via Mach kernel APIs (`host_statistics64`, `host_processor_info`) — matches Activity Monitor
- **Bandwidth** derived in real time from active session data, not the delayed `/statistics/bandwidth` endpoint
- **Self-signed cert support** for HTTPS connections to your server
- **URL auto-normalization** — entering `192.168.1.100:32400` automatically becomes `http://192.168.1.100:32400`

## Project Structure

```
PlexDesktopWidgets/
├── project.yml                  # XcodeGen project spec
└── PlexDesktopWidgets/
    ├── Info.plist               # App config (LSUIElement, ATS)
    ├── PlexDesktopWidgetsApp.swift  # App entry, menu bar, widget windows
    ├── PlexConfig.swift         # UserDefaults-backed settings
    ├── PlexAPI.swift            # Plex server API client
    ├── PlexDataManager.swift    # Polling, native stats, bandwidth derivation
    ├── PlexModels.swift         # Data models & API response types
    ├── NativeSystemStats.swift  # Mach API CPU/RAM (matches Activity Monitor)
    ├── NowPlayingView.swift     # Now Playing widget + poster image loader
    ├── BandwidthView.swift      # Bandwidth chart widget
    ├── SystemView.swift         # CPU/RAM gauges + sparklines
    ├── SettingsView.swift       # Server configuration UI
    ├── Theme.swift              # Widget background + color palette
    └── Assets.xcassets/         # App icon assets
```

## Customization

**Adjust widget transparency** — In `Theme.swift`, change the opacity values on the gradient colors:

```swift
Color(red: 0.07, green: 0.08, blue: 0.14).opacity(0.85)  // ← adjust this
```

Lower = more translucent (try `0.70` for glassier, `0.95` for nearly opaque).

**Change polling interval** — In `PlexDataManager.swift`, change `2.0` to your preferred interval in seconds.

## Troubleshooting

**Widgets are invisible / fully transparent:**
The app may need accessibility permissions. Also try: menu bar → Reset Positions.

**"Connection failed" in Settings:**
- Make sure your URL includes the port: `http://192.168.1.100:32400`
- Verify your token by testing in a browser: `http://YOUR_IP:32400/?X-Plex-Token=YOUR_TOKEN`

**No data showing but connection succeeds:**
- Start playing something in Plex — the Now Playing widget only shows active streams
- Bandwidth requires at least one active stream to register throughput
- System stats take ~4 seconds to populate (CPU needs a baseline measurement)

**Build error about `@MainActor`:**
Make sure your Xcode is version 15 or later and the deployment target is macOS 14.0.

## Built With

This project was built in one evening through conversational AI-assisted development ("vibe coding") with [Claude](https://claude.ai) by Anthropic. The entire app — architecture, API integration, native system stats, poster art loading, transparent window management — was created iteratively by describing desired features and debugging build issues through conversation.

## License

MIT License — do whatever you want with it.
