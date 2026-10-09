import AppKit
import SwiftUI

enum CompactPetLayout {
    static let slot = 96.0
    static let characterHeight = 80.0
    static func scale(_ value: Double) -> Double {
        value.isFinite && value > 0.5 ? min(1.2, max(0.8, value)) : 1
    }
}

/// The atlas contains authored eye poses. Every drawing uses the same body image,
/// so no pose can accidentally mirror the leaf crown or move the face.
final class CompactTomyAtlas {
    static let shared = CompactTomyAtlas()
    static let cell = 724
    static let eyeRects = [CGRect(x: 150, y: 335, width: 85, height: 88),
                           CGRect(x: 341, y: 364, width: 85, height: 89)]
    let body: CGImage?
    let eyePatches: [[CGImage]]
    private let alpha: [UInt8]

    private convenience init() {
        let image = NSImage(named: "pet_tomy_compact_v1") ??
            Bundle.main.url(forResource: "tomy-blink-strip", withExtension: "png")
                .flatMap { NSImage(contentsOf: $0) }
        self.init(image: image)
    }

    init(image: NSImage?) {
        var proposed = CGRect(x: 0, y: 0, width: 2172, height: 724)
        guard let source = image?.cgImage(forProposedRect: &proposed, context: nil, hints: nil),
              source.width == 2172, source.height == 724,
              let neutral = source.cropping(to: CGRect(x: 0, y: 0, width: 724, height: 724)) else {
            body = nil; eyePatches = []; alpha = []
            return
        }
        body = neutral
        eyePatches = (0..<3).map { frame in
            Self.eyeRects.compactMap { rect in
                source.cropping(to: rect.offsetBy(dx: CGFloat(frame * Self.cell), dy: 0))
            }
        }
        var pixels = [UInt8](repeating: 0, count: Self.cell * Self.cell * 4)
        pixels.withUnsafeMutableBytes { bytes in
            let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            if let context = CGContext(data: bytes.baseAddress, width: Self.cell, height: Self.cell,
                                       bitsPerComponent: 8, bytesPerRow: Self.cell * 4,
                                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) {
                // Bitmap rows already follow CGImage's top-origin pixel order.
                // The drawing view's flipped coordinates must not flip this mask.
                context.draw(neutral, in: CGRect(x: 0, y: 0, width: Self.cell, height: Self.cell))
            }
        }
        alpha = (0..<(Self.cell * Self.cell)).map { pixels[$0 * 4 + 3] }
    }

    private func metrics(_ size: CGSize) -> (scale: CGFloat, x: CGFloat, y: CGFloat, baseline: CGFloat) {
        let scale = size.width / CGFloat(CompactPetLayout.slot) * CGFloat(CompactPetLayout.characterHeight) / 597
        let baseline = size.height * 0.94
        return (scale, (size.width - 724 * scale) / 2, baseline - 671 * scale, baseline)
    }

    func draw(in context: CGContext, size: CGSize, pose: PetPose) {
        guard let body = body else { return }
        let m = metrics(size)
        let unit = size.width / CGFloat(CompactPetLayout.slot)
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: size.width / 2 + CGFloat(pose.x) * unit,
                            y: m.baseline + CGFloat(pose.y) * unit)
        context.rotate(by: CGFloat(pose.angle * .pi / 180))
        context.scaleBy(x: CGFloat(pose.scaleX), y: CGFloat(pose.scaleY))
        context.translateBy(x: -size.width / 2, y: -m.baseline)
        func drawImage(_ image: CGImage, _ rect: CGRect) {
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
        }
        drawImage(body, CGRect(x: m.x, y: m.y, width: 724 * m.scale, height: 724 * m.scale))
        let frame = min(2, max(0, pose.eyes))
        if frame > 0, eyePatches.count == 3, eyePatches[frame].count == 2 {
            for (rect, patch) in zip(Self.eyeRects, eyePatches[frame]) {
                drawImage(patch, CGRect(x: m.x + rect.minX * m.scale,
                                       y: m.y + rect.minY * m.scale,
                                       width: rect.width * m.scale, height: rect.height * m.scale))
            }
        }
        context.restoreGState()
    }

    func contains(_ point: CGPoint, size: CGSize, pose: PetPose) -> Bool {
        guard !alpha.isEmpty, size.width > 0, size.height > 0 else { return false }
        let m = metrics(size), unit = size.width / CGFloat(CompactPetLayout.slot)
        let dx = point.x - size.width / 2 - CGFloat(pose.x) * unit
        let dy = point.y - m.baseline - CGFloat(pose.y) * unit
        let radians = CGFloat(pose.angle * .pi / 180)
        let x = (cos(radians) * dx + sin(radians) * dy) / CGFloat(pose.scaleX) + size.width / 2
        let y = (-sin(radians) * dx + cos(radians) * dy) / CGFloat(pose.scaleY) + m.baseline
        let sx = Int(floor((x - m.x) / m.scale)), sy = Int(floor((y - m.y) / m.scale))
        guard (0..<Self.cell).contains(sx), (0..<Self.cell).contains(sy) else { return false }
        return alpha[sy * Self.cell + sx] > 96
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
