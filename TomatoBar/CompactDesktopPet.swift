import AppKit
import SwiftUI

enum CompactPetLayout {
    static let slot = 96.0
    static let characterHeight = 80.0
    static func scale(_ value: Double) -> Double {
        value.isFinite && value > 0.5 ? min(1.2, max(0.8, value)) : 1
    }
}

/// Idle keeps the approved body/eye raster. Work and rest use complete authored
/// seated poses, including arms, feet and their laptop/mug interaction.
final class CompactTomyAtlas {
    static let shared = CompactTomyAtlas()
    static let cell = 724
    static let eyeRects = [CGRect(x: 150, y: 335, width: 85, height: 88),
                           CGRect(x: 341, y: 364, width: 85, height: 89)]
    let body: CGImage?
    let eyePatches: [[CGImage]]
    let seatedFrames: [SeatedPetClip: [CGImage]]
    private var hitPose: PetPose?
    private var hitAlpha: [UInt8] = []

    private convenience init() {
        let image = NSImage(named: "pet_tomy_compact_v1") ??
            Bundle.main.url(forResource: "tomy-blink-strip", withExtension: "png")
                .flatMap { NSImage(contentsOf: $0) }
        self.init(image: image)
    }

    init(image: NSImage?, workImage: NSImage? = NSImage(named: "pet_tomy_seated_work_v1"),
         restImage: NSImage? = NSImage(named: "pet_tomy_seated_rest_v1")) {
        func frames(_ image: NSImage?) -> [CGImage] {
            var proposed = CGRect(x: 0, y: 0, width: 1536, height: 1024)
            guard let source = image?.cgImage(forProposedRect: &proposed, context: nil, hints: nil),
                  source.width == 1536, source.height == 1024 else { return [] }
            return (0..<6).compactMap { i in
                source.cropping(to: CGRect(x: i % 3 * 512, y: i / 3 * 512, width: 512, height: 512))
            }
        }
        seatedFrames = [.work: frames(workImage), .rest: frames(restImage)]
        var proposed = CGRect(x: 0, y: 0, width: 2172, height: 724)
        guard let source = image?.cgImage(forProposedRect: &proposed, context: nil, hints: nil),
              source.width == 2172, source.height == 724,
              let neutral = source.cropping(to: CGRect(x: 0, y: 0, width: 724, height: 724)) else {
            body = nil; eyePatches = []; return
        }
        body = neutral
        eyePatches = (0..<3).map { frame in
            Self.eyeRects.compactMap { rect in
                source.cropping(to: rect.offsetBy(dx: CGFloat(frame * Self.cell), dy: 0))
            }
        }
    }

    func draw(in context: CGContext, size: CGSize, pose: PetPose) {
        let unit = size.width / CGFloat(CompactPetLayout.slot), baseline = size.height * 0.94
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: size.width / 2 + CGFloat(pose.x) * unit,
                            y: baseline + CGFloat(pose.y) * unit)
        context.rotate(by: CGFloat(pose.angle * .pi / 180))
        context.scaleBy(x: CGFloat(pose.scaleX), y: CGFloat(pose.scaleY))
        context.translateBy(x: -size.width / 2, y: -baseline)
        func drawImage(_ image: CGImage, _ rect: CGRect) {
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
        }
        func drawScene(_ state: PetMotionState, frame: Int, eyes: Int, opacity: Double) {
            guard opacity > 0 else { return }
            context.saveGState()
            context.setAlpha(CGFloat(opacity))
            defer { context.restoreGState() }
            if let clip = state.clip, let frames = seatedFrames[clip], frames.count == 6 {
                let index = min(5, max(0, frame)), bounds = clip.bounds, offset = clip.offsets[index]
                // One fixed camera for every frame, identical to full-pose-player.js.
                let scale = CGFloat(CompactPetLayout.characterHeight) * unit / CGFloat(bounds[3] - bounds[1])
                let x = size.width / 2 - CGFloat((bounds[0] + bounds[2]) / 2) * scale
                let y = baseline - CGFloat(bounds[3]) * scale
                drawImage(frames[index], CGRect(x: x + CGFloat(offset[0]) * scale,
                    y: y + CGFloat(offset[1]) * scale, width: 512 * scale, height: 512 * scale))
                return
            }
            guard let body = body else { return }
            let scale = CGFloat(CompactPetLayout.characterHeight) * unit / 597
            let x = (size.width - 724 * scale) / 2, y = baseline - 671 * scale
            drawImage(body, CGRect(x: x, y: y, width: 724 * scale, height: 724 * scale))
            let eye = min(2, max(0, eyes))
            if eye > 0, eyePatches.count == 3, eyePatches[eye].count == 2 {
                for (rect, patch) in zip(Self.eyeRects, eyePatches[eye]) {
                    drawImage(patch, CGRect(x: x + rect.minX * scale, y: y + rect.minY * scale,
                        width: rect.width * scale, height: rect.height * scale))
                }
            }
        }
        if pose.sceneProgress < 1 {
            drawScene(pose.previousScene, frame: pose.previousFrame, eyes: pose.previousEyes,
                      opacity: 1 - pose.sceneProgress)
        }
        drawScene(pose.scene, frame: pose.frame, eyes: pose.eyes, opacity: pose.sceneProgress)
        context.restoreGState()
    }

    func contains(_ point: CGPoint, size: CGSize, pose: PetPose) -> Bool {
        guard body != nil, size.width > 0, size.height > 0 else { return false }
        let side = Int(CompactPetLayout.slot)
        let x = Int(floor(point.x / size.width * CGFloat(side)))
        let y = Int(floor(point.y / size.height * CGFloat(side)))
        guard (0..<side).contains(x), (0..<side).contains(y) else { return false }
        if hitPose != pose {
            // Cache the actual composited alpha, including authored hands/props,
            // frame registration and crossfades. Clear pixels pass through.
            var pixels = [UInt8](repeating: 0, count: side * side * 4)
            pixels.withUnsafeMutableBytes { bytes in
                let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                let context = CGContext(data: bytes.baseAddress, width: side, height: side,
                    bitsPerComponent: 8, bytesPerRow: side * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
                context.translateBy(x: 0, y: CGFloat(side)); context.scaleBy(x: 1, y: -1)
                draw(in: context, size: CGSize(width: side, height: side), pose: pose)
            }
            hitAlpha = (0..<(side * side)).map { pixels[$0 * 4 + 3] }
            hitPose = pose
        }
        return hitAlpha[y * side + x] > 96
    }
}

final class CompactTomyDrawingView: NSView {
    var pose = PetPose() { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        CompactTomyAtlas.shared.draw(in: context, size: bounds.size, pose: pose)
    }
}

struct CompactTomySprite: NSViewRepresentable {
    var pose = PetPose()
    func makeNSView(context: Context) -> CompactTomyDrawingView { CompactTomyDrawingView() }
    func updateNSView(_ view: CompactTomyDrawingView, context: Context) { view.pose = pose }
}

final class DesktopPetAnimator: ObservableObject {
    @Published private(set) var pose = PetPose()
    private var driver = PetMotionDriver(now: ProcessInfo.processInfo.systemUptime)
    private var frameTimer: Foundation.Timer?
    private(set) var presented = false
    private(set) var isTicking = false

    func configure(state: PetMotionState, hovered: Bool, dragging: Bool,
                   enabled: Bool, reduced: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        driver.configure(state: state, hovered: hovered, dragging: dragging,
                         enabled: enabled, reduced: reduced, now: now)
        refresh()
    }

    func setPresented(_ value: Bool) { presented = value; refresh() }
    func stop() { presented = false; frameTimer?.invalidate(); frameTimer = nil; isTicking = false }

    private func refresh() {
        let now = ProcessInfo.processInfo.systemUptime
        let next = driver.pose(at: now)
        if next != pose { pose = next }
        guard presented, driver.requiresTicks(at: now) else {
            frameTimer?.invalidate(); frameTimer = nil; isTicking = false
            return
        }
        guard frameTimer == nil else { return }
        let timer = Foundation.Timer(timeInterval: 1 / 24, repeats: true) { [weak self] _ in self?.refresh() }
        frameTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        isTicking = true
    }
    deinit { frameTimer?.invalidate() }
}

struct DesktopPetRootView: View {
    @ObservedObject var timer: TBTimer
    @AppStorage("desktopPetKind") private var kind = PetKind.tomy.rawValue
    var body: some View {
        if kind == PetKind.tomy.rawValue { CompactDesktopPetView(timer: timer) }
        else { DesktopPetView(timer: timer) }
    }
}

struct CompactDesktopPetView: View {
    @ObservedObject var timer: TBTimer
    @AppStorage("desktopPetScale") private var rawScale = 1.0
    @AppStorage("gentleAnimations") private var animations = true
    @AppStorage("showDesktopPet") private var show = true
    @StateObject private var animator = DesktopPetAnimator()
    @State private var hovered = false
    @State private var dragging = false
    @State private var reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    private var side: CGFloat { CGFloat(CompactPetLayout.slot * CompactPetLayout.scale(rawScale)) }
    private var state: PetMotionState { PetMotionState(phase: timer.state.phase, paused: timer.state.paused) }

    var body: some View {
        ZStack {
            CompactTomySprite(pose: animator.pose)
            DesktopPetEventRepresentable(
                onSingleClick: { timer.primaryAction() },
                onDoubleClick: { TBStatusItem.shared?.showMainWindow() },
                onRightClick: { DesktopPetController.shared?.showCompactContextMenu(with: $0) },
                onDragEnded: {
                    dragging = false; updateMotion()
                    DesktopPetController.shared?.saveCurrentPosition()
                },
                onHoverStateChanged: { value in hovered = value; updateMotion() },
                onDragBegan: {
                    dragging = true; updateMotion()
                },
                acceptsPoint: { point, size in CompactTomyAtlas.shared.contains(point, size: size, pose: animator.pose) },
                onPresentationChanged: { animator.setPresented($0) },
                accessibilityName: "Tomy，\(state.label)")
        }
        .frame(width: side, height: side)
        .onAppear { updateMotion(); animator.setPresented(show) }
        .onDisappear { animator.stop() }
        .onChange(of: timer.state.phase) { _ in updateMotion() }
        .onChange(of: timer.state.paused) { _ in updateMotion() }
        .onChange(of: animations) { _ in updateMotion() }
        .onChange(of: show) { value in animator.setPresented(value) }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)) { _ in
            reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            updateMotion()
        }
    }

    private func updateMotion() {
        animator.configure(state: state, hovered: hovered, dragging: dragging,
                           enabled: animations, reduced: reduced)
    }
}

struct CompactPetTooltipView: View {
    @ObservedObject var timer: TBTimer
    private var state: PetMotionState { PetMotionState(phase: timer.state.phase, paused: timer.state.paused) }
    private var detail: String {
        switch timer.state.phase {
        case .idle: return "点我开始"
        case .work, .rest: return timer.timeLeft
        case .workFinished: return "已完成"
        case .restFinished: return "准备下一轮"
        }
    }
    var body: some View {
        HStack(spacing: 8) {
            Text("Tomy").fontWeight(.semibold)
            Text(state.label).foregroundColor(Garden.muted)
            Spacer(minLength: 4)
            Text(detail).monospacedDigit().foregroundColor(Garden.red)
        }
        .font(.system(size: 11))
        .foregroundColor(Garden.ink)
        .padding(.horizontal, 12)
        .frame(width: 214, height: 34)
        .background(RoundedRectangle(cornerRadius: 11).fill(Garden.paper)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Garden.line, lineWidth: 0.8)))
    }
}
