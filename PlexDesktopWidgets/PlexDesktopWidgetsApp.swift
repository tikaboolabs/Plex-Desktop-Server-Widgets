import SwiftUI
import AppKit
import Combine

@main
struct PlexDesktopWidgetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)
    }
}

// MARK: - App Delegate
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var widgetWindows: [String: NSWindow] = [:]
    private var settingsWindow: NSWindow?
    private var settingsCloseObserver: NSObjectProtocol?
    private let dataManager = PlexDataManager.shared
    private var nowPlayingHostView: NSHostingView<AnyView>?
    private var resizeCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        for window in NSApp.windows {
            window.close()
        }

        setupMenuBar()
        dataManager.startPolling()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.createWidgetWindows()
        }
    }

    // MARK: - Menu Bar
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = NSImage(systemSymbolName: "play.circle.fill",
                                   accessibilityDescription: "Plex Widgets")?
                .withSymbolConfiguration(config)
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Plex Desktop Widgets", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        addToggleItem(menu, title: "Now Playing", key: "nowPlaying")
        addToggleItem(menu, title: "Bandwidth", key: "bandwidth")
        addToggleItem(menu, title: "System", key: "system")

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let resetItem = NSMenuItem(title: "Reset Positions", action: #selector(resetPositions), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func addToggleItem(_ menu: NSMenu, title: String, key: String) {
        let item = NSMenuItem(title: title, action: #selector(toggleWidget(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = key
        item.state = widgetWindows[key]?.isVisible == true ? .on : .off
        menu.addItem(item)
    }

    @objc private func toggleWidget(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let window = widgetWindows[key], window.isVisible {
            window.orderOut(nil)
            UserDefaults.standard.set(false, forKey: "widget_visible_\(key)")
        } else {
            if widgetWindows[key] == nil { createSingleWidget(key: key) }
            widgetWindows[key]?.orderFront(nil)
            UserDefaults.standard.set(true, forKey: "widget_visible_\(key)")
        }
        rebuildMenu()
    }

    @objc private func refreshNow() {
        dataManager.fetch()
    }

    @objc private func resetPositions() {
        for key in ["nowPlaying", "bandwidth", "system"] {
            UserDefaults.standard.removeObject(forKey: "widget_x_\(key)")
            UserDefaults.standard.removeObject(forKey: "widget_y_\(key)")
        }
        widgetWindows.values.forEach { $0.close() }
        widgetWindows.removeAll()
        createWidgetWindows()
    }

    @objc private func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "Plex Desktop Widgets — Settings"
        window.contentView = NSHostingView(
            rootView: SettingsView().environmentObject(dataManager)
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window

        if let prev = settingsCloseObserver {
            NotificationCenter.default.removeObserver(prev)
        }
        settingsCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    // MARK: - Widget Windows
    private func createWidgetWindows() {
        for key in ["nowPlaying", "bandwidth", "system"] {
            let visible = UserDefaults.standard.object(forKey: "widget_visible_\(key)") as? Bool ?? true
            if visible { createSingleWidget(key: key) }
        }
        rebuildMenu()
    }

    private func createSingleWidget(key: String) {
        let screen = NSScreen.main!
        let sw = screen.visibleFrame.width
        let sh = screen.visibleFrame.height
        let sx = screen.visibleFrame.origin.x
        let sy = screen.visibleFrame.origin.y

        let size: NSSize
        let defaultOrigin: NSPoint

        switch key {
        case "nowPlaying":
            size = NSSize(width: 340, height: 420)
            defaultOrigin = NSPoint(x: sx + sw - 364, y: sy + sh - 460)
        case "bandwidth":
            size = NSSize(width: 340, height: 220)
            defaultOrigin = NSPoint(x: sx + sw - 364, y: sy + sh - 700)
        case "system":
            size = NSSize(width: 340, height: 260)
            defaultOrigin = NSPoint(x: sx + sw - 364, y: sy + sh - 980)
        default: return
        }

        let savedX = UserDefaults.standard.object(forKey: "widget_x_\(key)") as? CGFloat
        let savedY = UserDefaults.standard.object(forKey: "widget_y_\(key)") as? CGFloat
        let origin = (savedX != nil && savedY != nil)
            ? NSPoint(x: savedX!, y: savedY!) : defaultOrigin

        let frame = NSRect(origin: origin, size: size)
        let window = WidgetWindow(contentRect: frame, key: key)

        let swiftUIView: AnyView
        switch key {
        case "nowPlaying":
            swiftUIView = AnyView(NowPlayingView().environmentObject(dataManager))
        case "bandwidth":
            swiftUIView = AnyView(BandwidthView().environmentObject(dataManager))
        case "system":
            swiftUIView = AnyView(SystemView().environmentObject(dataManager))
        default: return
        }

        let hostView = NSHostingView(rootView: swiftUIView)
        hostView.frame = NSRect(origin: .zero, size: size)
        hostView.autoresizingMask = [.width, .height]
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = .clear
        hostView.layer?.isOpaque = false

        // Store ref for auto-resize
        if key == "nowPlaying" {
            nowPlayingHostView = hostView
        }

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = .clear
        container.layer?.isOpaque = false
        container.autoresizingMask = [.width, .height]
        container.addSubview(hostView)

        window.contentView = container
        window.orderFront(nil)
        widgetWindows[key] = window

        // Re-apply transparency after the display cycle settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.isOpaque = false
            window.backgroundColor = .clear
            hostView.layer?.backgroundColor = .clear
            container.layer?.backgroundColor = .clear
        }

        // Auto-resize nowPlaying window when streams change
        if key == "nowPlaying" {
            resizeCancellable = dataManager.$streams
                .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
                .sink { [weak self] _ in self?.resizeNowPlaying() }
        }
    }

    // MARK: - Auto-Resize Now Playing
    private func resizeNowPlaying() {
        guard let window = widgetWindows["nowPlaying"],
              let hostView = nowPlayingHostView else { return }

        let fitting = hostView.fittingSize
        let newHeight = max(fitting.height, 120)  // minimum height for empty state
        let oldFrame = window.frame

        // Grow/shrink from top edge (keep top-left pinned)
        let newY = oldFrame.origin.y + oldFrame.height - newHeight
        let newFrame = NSRect(x: oldFrame.origin.x, y: newY,
                              width: oldFrame.width, height: newHeight)

        window.setFrame(newFrame, display: true, animate: true)
    }
}

// MARK: - Widget Window
final class WidgetWindow: NSPanel {
    private let widgetKey: String

    init(contentRect: NSRect, key: String) {
        self.widgetKey = key
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .init(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.stationary, .ignoresCycle]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
    }

    override func close() {
        savePosition()
        super.close()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        savePosition()
    }

    private func savePosition() {
        UserDefaults.standard.set(frame.origin.x, forKey: "widget_x_\(widgetKey)")
        UserDefaults.standard.set(frame.origin.y, forKey: "widget_y_\(widgetKey)")
    }
}
