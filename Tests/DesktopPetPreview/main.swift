import AppKit
import SwiftUI

// This executable has a distinct process/bundle name and writes only to a fresh
// temporary FocusStore. It never constructs TBApp/TBStatusItem or the live store.
final class PetLab: ObservableObject {
    @Published var timer: TBTimer
    @Published var selected: PetMotionState = .idle
    @Published var visible = true
    @Published var motion = true
    @Published var scale = 1.0
    @Published var renderedPet: NSImage?
    var controller: DesktopPetController?
    weak var anchor: NSView?
    let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("TomyPetQA-\(UUID().uuidString)")
    init() {
        timer = TBTimer(store: FocusStore(url: scratch.appendingPathComponent("initial/sessions.json")))
        UserDefaults.standard.set("tomy", forKey: "desktopPetKind")
        UserDefaults.standard.set(true, forKey: "showDesktopPet")
        UserDefaults.standard.set(true, forKey: "gentleAnimations")
        UserDefaults.standard.set(1.0, forKey: "desktopPetScale")
        apply(.idle)
    }
    func apply(_ state: PetMotionState) {
        controller?.shutdown()
        renderedPet = nil
        var seed = FocusState()
        let now = Date()
        switch state {
        case .idle: break
        case .work, .workPaused:
            seed.startWork(name: "桌宠隔离验收", seconds: 600, at: now)
            seed.pause(at: now)
        case .rest, .restPaused:
            seed.phase = .workFinished
            seed.startRest(seconds: 300, at: now); seed.pause(at: now)
        case .workFinished: seed.phase = .workFinished
        case .restFinished: seed.phase = .restFinished
        }
        let store = FocusStore(url: scratch.appendingPathComponent("\(UUID().uuidString)/sessions.json"))
        try! store.save(seed)
        timer = TBTimer(store: store)
        if state == .work || state == .rest { timer.togglePause() }
        selected = state
        controller = DesktopPetController(timer: timer)
        controller?.setup()
    }
    func show(_ value: Bool) {
        visible = value; UserDefaults.standard.set(value, forKey: "showDesktopPet")
        controller?.updateVisibility()
    }
    func animate(_ value: Bool) { motion = value; UserDefaults.standard.set(value, forKey: "gentleAnimations") }
    func resize(_ value: Double) { renderedPet = nil; scale = value; UserDefaults.standard.set(value, forKey: "desktopPetScale"); controller?.updatePanelSize() }
    func capture() {
        guard let view = controller?.panel?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let image = NSImage(size: view.bounds.size); image.addRepresentation(bitmap)
        renderedPet = image
    }
    func place() {
        guard let anchor = anchor, let window = anchor.window, let panel = controller?.panel else { return }
        let point = window.convertPoint(toScreen: anchor.convert(NSPoint(x: anchor.bounds.midX, y: anchor.bounds.midY), to: nil))
        panel.setFrameOrigin(NSPoint(x: point.x - panel.frame.width / 2, y: point.y - panel.frame.height / 2))
        controller?.saveCurrentPosition()
    }
    func cleanup() { controller?.shutdown(); try? FileManager.default.removeItem(at: scratch) }
}
struct StateSample: View {
    let state: PetMotionState
    @StateObject private var animator = DesktopPetAnimator()
    var body: some View {
        VStack(spacing: 8) {
            CompactTomySprite(pose: animator.pose).frame(width: 96, height: 96)
            Text(state.label).font(.system(size: 12))
        }
        .onAppear {
            animator.configure(state: state, hovered: false, dragging: false, enabled: true, reduced: false)
            animator.setPresented(true)
        }
        .onDisappear { animator.stop() }
    }
}
struct PlacementAnchor: NSViewRepresentable {
    let lab: PetLab
    func makeNSView(context: Context) -> NSView { let view = NSView(); lab.anchor = view; return view }
    func updateNSView(_ view: NSView, context: Context) { lab.anchor = view }
}
struct PanelInspector: View {
    @ObservedObject var timer: TBTimer
    let controller: DesktopPetController?
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 0.2)) { _ in
            Text("实际状态：\(timer.phaseLabel)  \(timer.timeLeft)\n窗口：\(Int(controller?.panel?.frame.width ?? 0)) × \(Int(controller?.panel?.frame.height ?? 0)) 点    透明区穿透：\(controller?.panel?.ignoresMouseEvents == true ? "是" : "否")    悬停气泡：\(controller?.tooltipPanel?.isVisible == true ? "显示" : "隐藏")\n位置：\(Int(controller?.panel?.frame.minX ?? 0)), \(Int(controller?.panel?.frame.minY ?? 0))")
                .font(.system(size: 12, design: .monospaced)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
struct PetLabView: View {
    @ObservedObject var lab: PetLab
    @State private var underlyingClicks = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tomy · macOS 桌面验收").font(.system(size: 24, weight: .semibold))
            Text("坐姿打字、捧杯喝水；暂停停住当前动作。下方都是实际原生渲染。").foregroundStyle(.secondary)
            HStack(spacing: 16) { ForEach(PetMotionState.allCases, id: \.self) { StateSample(state: $0) } }
                .frame(height: 140).padding(12).background(Color(nsColor: .windowBackgroundColor))
            HStack {
                ForEach(PetMotionState.allCases, id: \.self) { state in
                    Button(state.label) { lab.apply(state) }
                }
            }
            HStack {
                Button("显示桌宠") { lab.show(true) }
                Button("隐藏桌宠") { lab.show(false) }
                Button("放到验证区") { lab.place() }
                Button("查看浮窗内容") { lab.capture() }
                Button(lab.motion ? "关闭动画" : "开启动画") { lab.animate(!lab.motion) }
                ForEach([0.8, 1.0, 1.2], id: \.self) { scale in
                    Button("\(Int(80 * scale)) 点") { lab.resize(scale) }
                }
            }
            HStack {
                PanelInspector(timer: lab.timer, controller: lab.controller)
                if let image = lab.renderedPet {
                    VStack { Image(nsImage: image).resizable().interpolation(.none).frame(width: 96, height: 96)
                        Text("原生浮窗内容").font(.caption) }
                }
            }
            Button { underlyingClicks += 1 } label: {
                Text("穿透验证区 · 点击次数 \(underlyingClicks)")
                    .frame(maxWidth: .infinity, minHeight: 100).contentShape(Rectangle())
            }
            .buttonStyle(.plain).background(Color.blue.opacity(0.08))
            .background(PlacementAnchor(lab: lab))
            Text("把桌宠拖到验证区内：点番茄应改变计时状态，点其透明边角应增加下方次数。右键菜单可切换形象、尺寸及隐藏。").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(28).frame(width: 870, height: 680)
    }
}
final class PetQADelegate: NSObject, NSApplicationDelegate {
    var lab: PetLab?
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let lab = PetLab(); self.lab = lab
        let window = NSWindow(contentRect: NSRect(x: 180, y: 260, width: 870, height: 680),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Tomy Desktop QA — 独立验收"
        window.contentViewController = NSHostingController(rootView: PetLabView(lab: lab))
        self.window = window; window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationWillTerminate(_ notification: Notification) { lab?.cleanup() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let application = NSApplication.shared
let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
let appMenu = NSMenu()
appMenu.addItem(NSMenuItem(title: "退出 Tomy Desktop QA", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
appMenuItem.submenu = appMenu
mainMenu.addItem(appMenuItem)
application.mainMenu = mainMenu
let delegate = PetQADelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
