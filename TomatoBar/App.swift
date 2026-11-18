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

class TBStatusItem: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    enum StatusIcon: Equatable {
        case asset(NSImage.Name)
        case emoji(String)
    }

    private var mainWindow: NSWindow?
    private var popover = NSPopover()
    private var anchorWindow: NSWindow?
    private var statusBarItem: NSStatusItem?
    private var model: TBTimer!
    private let reminder = TBReminder()
    private var launchContext = LaunchContext()
    private(set) var petController: TomyPetController?
    static var shared: TBStatusItem?
    private static let mainWindowMinContent = NSSize(width: 960, height: 620)
    private static let trailingAnchorWidth: CGFloat = 32
    static let pausedButtonAlpha: CGFloat = 0.45
    private static let smokeEmojiImage: NSImage = makeEmojiImage("🚬")
    private var statusWindowObservers: [NSObjectProtocol] = []
    private var suppressNextStatusButtonToggle = false
    private var isProgrammaticClose = false
    private var lastAppliedStatus: (icon: StatusIcon, title: String?, paused: Bool, toolTip: String)?

    deinit {
        stopObservingStatusWindow()
        petController?.shutdown()
        anchorWindow?.orderOut(nil)
        anchorWindow?.close()
    }

    func applicationWillFinishLaunching(_: Notification) {
        launchContext.observe(NSAppleEventManager.shared().currentAppleEvent)
    }
    func applicationDidFinishLaunching(_: Notification) {
        launchContext.observe(NSAppleEventManager.shared().currentAppleEvent)
        Self.shared = self
        LaunchAtLogin.migrateIfNeeded()
        model = TBTimer()
        let pet = TomyPetController(timer: model)
        pet.setup()
        petController = pet
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: TBPopoverView(timer: model))
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem?.button?.imagePosition = .imageLeft
        statusBarItem?.button?.target = self
        statusBarItem?.button?.action = #selector(togglePopover(_:))
        model.onAttention = { [weak self] in
            guard let self = self else { return }
            self.closePopover(nil)
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
    func applicationWillTerminate(_ notification: Notification) {
        petController?.shutdown()
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
        closePopover(nil)
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "TomatoBar · 专注时光"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Garden.paper)
            window.isReleasedWhenClosed = false
            window.delegate = self
            let hosting = NSHostingController(rootView: MainWindowView(timer: model, history: model.history))
            if #available(macOS 13.0, *) { hosting.sizingOptions = [] }
            window.contentViewController = hosting
            // Assigning contentViewController overwrites contentMinSize with the view
            // controller's own minimum (≈0 once sizingOptions is cleared), so this must
            // run after the assignment or the window can shrink past the layout's floor.
            window.contentMinSize = Self.mainWindowMinContent
            window.setContentSize(NSSize(width: 1180, height: 760))
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
    // contentMinSize only constrains interactive resize and frame restoration. System
    // window tiling and programmatic setFrame paths bypass it, so the floor is also
    // enforced in the delegate: clamp proposed sizes, and bounce back any applied
    // frame that still ended up smaller than the layout can render without clipping.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard sender === mainWindow else { return frameSize }
        return clampedMainFixedSize(frameSize)
    }
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === mainWindow else { return }
        // Fullscreen and Split View own their frame; fighting them would loop.
        guard !window.styleMask.contains(.fullScreen) else { return }
        let clamped = clampedMainFixedSize(window.frame.size)
        if clamped != window.frame.size {
            window.setFrame(window.constrainFrameRect(NSRect(origin: window.frame.origin, size: clamped), to: window.screen),
                display: true)
        }
    }
    private func clampedMainFixedSize(_ size: NSSize) -> NSSize {
        guard let window = mainWindow else { return size }
        let content = window.contentRect(forFrameRect: NSRect(origin: .zero, size: size)).size
        let min = Self.mainWindowMinContent
        guard content.width < min.width || content.height < min.height else { return size }
        let fixedContent = NSSize(width: max(content.width, min.width), height: max(content.height, min.height))
        return window.frameRect(forContentRect: NSRect(origin: .zero, size: fixedContent)).size
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === mainWindow else { return }
        model.windowActivity.visible = false
        if !NSApp.setActivationPolicy(.accessory) {
            NSLog("TomatoBar: failed to hide the running Dock icon")
        }
    }
    static func trailingAnchorRect(for bounds: NSRect) -> NSRect {
        let width = min(trailingAnchorWidth, bounds.width)
        return NSRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height)
    }

    static func trailingAnchorScreenRect(for button: NSStatusBarButton) -> NSRect? {
        guard let buttonWindow = button.window else { return nil }
        let anchorRect = trailingAnchorRect(for: button.bounds)
        let screenRect = buttonWindow.convertToScreen(button.convert(anchorRect, to: nil))
        return NSRect(
            x: screenRect.minX,
            y: buttonWindow.frame.minY,
            width: max(1, screenRect.width),
            height: max(1, buttonWindow.frame.height)
        )
    }

    static func titleAttributedString(title: String?) -> NSAttributedString {
        NSAttributedString(
            string: title.map { " \($0)" } ?? "",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    /// Render the easter-egg emoji as a real status-item image so the normal timer title
    /// can remain beside it. Keep it non-template to preserve the native color emoji.
    private static func makeEmojiImage(_ emoji: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let text = NSAttributedString(string: emoji, attributes: [
                .font: NSFont.systemFont(ofSize: 13.5)
            ])
            let size = text.size()
            text.draw(at: NSPoint(x: (rect.width - size.width) / 2,
                                  y: (rect.height - size.height) / 2 - 0.5))
            return true
        }
        image.isTemplate = false
        return image
    }

    func setStatus(icon: StatusIcon, title: String?, paused: Bool = false, phaseLabel: String? = nil) {
        guard let button = statusBarItem?.button else { return }
        let label = phaseLabel ?? model?.phaseLabel ?? ""
        let toolTip = label.isEmpty ? "番茄钟" : "番茄钟 · \(label)"
        if let last = lastAppliedStatus,
           last.icon == icon,
           last.title == title,
           last.paused == paused,
           last.toolTip == toolTip {
            return
        }
        let image: NSImage?
        switch icon {
        case .asset(let name):
            image = NSImage(named: name)
        case .emoji(let emoji):
            image = emoji == "🚬" ? Self.smokeEmojiImage : Self.makeEmojiImage(emoji)
        }
        button.contentTintColor = nil
        button.image = image
        button.attributedTitle = Self.titleAttributedString(title: title)
        button.alphaValue = paused ? Self.pausedButtonAlpha : 1.0
        button.toolTip = toolTip
        lastAppliedStatus = (icon, title, paused, toolTip)
    }

    func showPopover(_ sender: AnyObject?) {
        guard let button = statusBarItem?.button,
              let anchor = syncAnchorWindow(for: button),
              let anchorView = anchor.contentView else { return }
        suppressNextStatusButtonToggle = false
        if popover.isShown {
            anchor.orderFrontRegardless()
            popover.contentViewController?.view.window?.makeKey()
            return
        }
        stopObservingStatusWindow()
        if let contentView = popover.contentViewController?.view {
            contentView.layoutSubtreeIfNeeded()
            let fitting = contentView.fittingSize
            if fitting.width > 0 && fitting.height > 0 {
                popover.contentSize = fitting
            }
        }
        anchor.orderFrontRegardless()
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        if let buttonWindow = button.window {
            startObservingStatusWindow(buttonWindow, button: button)
        }
    }

    func closePopover(_ sender: AnyObject?) {
        suppressNextStatusButtonToggle = false
        isProgrammaticClose = true
        defer { isProgrammaticClose = false }
        popover.performClose(sender)
    }

    func popoverWillClose(_ notification: Notification) {
        if !isProgrammaticClose && isClosingDueToStatusButtonClick() {
            // Transient popovers close on leftMouseDown before NSStatusBarButton triggers its action.
            // Suppress only that click's toggle so the popover closes instead of reopening immediately.
            suppressNextStatusButtonToggle = true
            RunLoop.main.perform(inModes: [.default]) { [weak self] in
                self?.suppressNextStatusButtonToggle = false
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopObservingStatusWindow()
        anchorWindow?.orderOut(nil)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if suppressNextStatusButtonToggle {
            suppressNextStatusButtonToggle = false
            return
        }
        if popover.isShown { closePopover(sender) } else { showPopover(sender) }
    }

    private func ensureAnchorWindow() -> NSWindow {
        if let anchorWindow { return anchorWindow }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.trailingAnchorWidth, height: 22),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        anchorWindow = window
        return window
    }

    @discardableResult
    private func syncAnchorWindow(for button: NSStatusBarButton) -> NSWindow? {
        guard let buttonWindow = button.window,
              let screenRect = Self.trailingAnchorScreenRect(for: button) else { return nil }
        let window = ensureAnchorWindow()
        if window.level != buttonWindow.level {
            window.level = buttonWindow.level
        }
        if abs(window.frame.minX - screenRect.minX) > 0.5
            || abs(window.frame.minY - screenRect.minY) > 0.5
            || abs(window.frame.width - screenRect.width) > 0.5
            || abs(window.frame.height - screenRect.height) > 0.5 {
            window.setFrame(screenRect, display: false)
        }
        return window
    }

    private func isClosingDueToStatusButtonClick() -> Bool {
        guard let button = statusBarItem?.button,
              let buttonWindow = button.window,
              let event = NSApp.currentEvent else { return false }
        guard event.type == .leftMouseDown || event.type == .rightMouseDown else { return false }
        let buttonScreenRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        return buttonScreenRect.contains(NSEvent.mouseLocation)
    }

    private func startObservingStatusWindow(_ window: NSWindow, button: NSStatusBarButton) {
        let center = NotificationCenter.default
        let syncIfShown: () -> Void = { [weak self, weak window, weak button] in
            guard let self = self,
                  let window = window,
                  let button = button,
                  self.popover.isShown,
                  button.window === window else { return }
            _ = self.syncAnchorWindow(for: button)
        }
        let watched: [(Notification.Name, Any?)] = [
            (NSWindow.didMoveNotification, window),
            (NSWindow.didChangeScreenNotification, window),
            (NSApplication.didChangeScreenParametersNotification, nil),
        ]
        statusWindowObservers = watched.map { name, sender in
            center.addObserver(forName: name, object: sender, queue: .main) { _ in
                syncIfShown()
            }
        }
        // Sync asynchronously on resize so normal status-bar relayout (didResize before didMove
        // in the same pass) settles first, while notch-pinned resizes without didMove still sync.
        let resizeObserver = center.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                syncIfShown()
            }
        }
        statusWindowObservers.append(resizeObserver)
    }

    private func stopObservingStatusWindow() {
        for observer in statusWindowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        statusWindowObservers.removeAll()
    }
}
