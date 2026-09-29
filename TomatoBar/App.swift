import SwiftUI
import LaunchAtLogin

extension NSImage.Name {
    static let idle = Self("BarIconIdle")
    static let work = Self("BarIconWork")
    static let shortRest = Self("BarIconShortRest")
    static let longRest = Self("BarIconLongRest")
}

@main
struct TBApp: App {
    @NSApplicationDelegateAdaptor(TBStatusItem.self) var appDelegate
    var body: some Scene { Settings {} }
}

class TBStatusItem: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mainWindow: NSWindow?
    private var popover = NSPopover()
    private var statusBarItem: NSStatusItem?
    private var model: TBTimer!
    private let reminder = TBReminder()
    private var launchContext = LaunchContext()
    static var shared: TBStatusItem?

    func applicationWillFinishLaunching(_: Notification) {
        launchContext.observe(NSAppleEventManager.shared().currentAppleEvent)
    }
    func applicationDidFinishLaunching(_: Notification) {
        launchContext.observe(NSAppleEventManager.shared().currentAppleEvent)
        Self.shared = self
        LaunchAtLogin.migrateIfNeeded()
        model = TBTimer()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: TBPopoverView(timer: model))
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem?.button?.imagePosition = .imageLeft
        statusBarItem?.button?.target = self
        statusBarItem?.button?.action = #selector(togglePopover(_:))
        model.onAttention = { [weak self] in
            guard let self = self else { return }
            self.popover.performClose(nil)
            self.reminder.show(timer: self.model)
        }
        model.updateStatus()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep),
            name: NSWorkspace.willSleepNotification, object: nil)
        // Suppress both restored windows on login; retain needsAttention so the user
        // can explicitly open the reminder from the menu bar after signing in.
        if launchContext.shouldShowInitialWindows {
            showMainWindow()
            if model.state.needsAttention { reminder.show(timer: model) }
        }
    }
    @objc private func willSleep() { model.pause() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.pause()
        guard model.hasUnsavedChanges else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "专注记录尚未保存"
        alert.informativeText = "请检查磁盘空间后重试保存，避免丢失当前记录。"
        alert.addButton(withTitle: "返回")
        alert.runModal()
        return .terminateCancel
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        if model.state.needsAttention { reminder.show(timer: model) }
        return true
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme?.lowercased() == "tomatobar-personal" {
            if url.host?.lowercased() == "startstop" { model.primaryAction() }
        }
    }
    func showMainWindow() {
        popover.performClose(nil)
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 800),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "TomatoBar · 专注时光"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Garden.paper)
            window.contentMinSize = NSSize(width: 920, height: 740)
            window.isReleasedWhenClosed = false
            window.delegate = self
            let hosting = NSHostingController(rootView: MainWindowView(timer: model, history: model.history))
            if #available(macOS 13.0, *) { hosting.sizingOptions = [] }
            window.contentViewController = hosting
            window.setContentSize(NSSize(width: 1120, height: 800))
            window.center()
            window.setFrameAutosaveName("TomatoBarMainWindow")
            mainWindow = window
        }
        if !NSApp.setActivationPolicy(.regular) {
            NSLog("TomatoBar: failed to show the running Dock icon")
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.windowActivity.visible = true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowDidBecomeKey(_ notification: Notification) { model.windowActivity.visible = true }
    func windowDidResignKey(_ notification: Notification) { model.windowActivity.visible = false }
    func windowDidMiniaturize(_ notification: Notification) { model.windowActivity.visible = false }
    func windowDidDeminiaturize(_ notification: Notification) { model.windowActivity.visible = true }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === mainWindow else { return }
        model.windowActivity.visible = false
        if !NSApp.setActivationPolicy(.accessory) {
            NSLog("TomatoBar: failed to hide the running Dock icon")
        }
    }
    func setTitle(title: String?) {
        statusBarItem?.button?.attributedTitle = NSAttributedString(string: title.map { " \($0)" } ?? "",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)])
        statusBarItem?.button?.toolTip = "番茄钟 · \(model.phaseLabel)"
    }
    func setIcon(name: NSImage.Name) { statusBarItem?.button?.image = NSImage(named: name) }
    func showPopover(_ sender: AnyObject?) {
        guard let button = statusBarItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    func closePopover(_ sender: AnyObject?) { popover.performClose(sender) }
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown { closePopover(sender) } else { showPopover(sender) }
    }
}
