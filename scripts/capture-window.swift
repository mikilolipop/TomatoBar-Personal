import AppKit
import SwiftUI

@main
struct ShowcaseWindowHost {
    static var window: NSWindow?
    static var timer: TBTimer?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let demoPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "demo/sessions.json"
        let demoURL = URL(fileURLWithPath: demoPath)
        let store = FocusStore(url: demoURL)
        let t = TBTimer(store: store)
        timer = t

        let win = NSWindow(
            contentRect: NSRect(x: 200, y: 120, width: 960, height: 730),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        win.minSize = NSSize(width: 960, height: 620)
        win.title = "TomatoBar · 专注时光"
        win.isReleasedWhenClosed = false
        win.contentViewController = NSHostingController(rootView: MainWindowView(timer: t, history: t.history))
        win.setFrame(NSRect(x: 200, y: 100, width: 960, height: 705), display: true)
        win.center()
        win.makeKeyAndOrderFront(nil)
        window = win
        app.activate(ignoringOtherApps: true)

        // Allow SwiftUI layout and render to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let windowID = CGWindowID(win.windowNumber)
            print("SHOWCASE_WINDOW_ID:\(windowID)")
            fflush(stdout)
        }

        // Timeout after 20s
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
            exit(0)
        }

        app.run()
    }
}
