import AppKit
import Combine
import SwiftUI

final class TomySpriteAtlas {
    static let shared = TomySpriteAtlas()

    static let maskWidth = 24
    static let maskHeight = 26
    static let hitAlphaThreshold: UInt8 = 52

    private(set) var cellPixelWidth: Int = 0
    private(set) var cellPixelHeight: Int = 0
    private var cells: [[CGImage]] = []
    private var hitMasks: [[[Bool]]] = []

    var isLoaded: Bool { !cells.isEmpty && cellPixelWidth > 0 && cellPixelHeight > 0 }

    private convenience init() {
        let image = NSImage(named: "TomyAtlas") ?? Self.fallbackImage()
        self.init(image: image)
    }

    init(image: NSImage?) {
        guard let source = Self.bestCGImage(from: image),
              source.width >= TomyAtlasRow.columns * 48,
              source.height >= TomyAtlasRow.rows * 52 else {
            return
        }
        let cw = source.width / TomyAtlasRow.columns
        let ch = source.height / TomyAtlasRow.rows
        self.cellPixelWidth = cw
        self.cellPixelHeight = ch

        var allCells: [[CGImage]] = []
        var allMasks: [[[Bool]]] = []
        allCells.reserveCapacity(TomyAtlasRow.rows)
        allMasks.reserveCapacity(TomyAtlasRow.rows)

        for row in TomyAtlasRow.allCases {
            var rowCells: [CGImage] = []
            var rowMasks: [[Bool]] = []
            for col in 0..<row.frameCount {
                let cropRect = CGRect(x: col * cw, y: row.rawValue * ch, width: cw, height: ch)
                if let cropped = source.cropping(to: cropRect) {
                    rowCells.append(cropped)
                    rowMasks.append(Self.bakeHitMask(for: cropped))
                }
            }
            allCells.append(rowCells)
            allMasks.append(rowMasks)
        }
        self.cells = allCells
        self.hitMasks = allMasks
    }

    private static func bestCGImage(from image: NSImage?) -> CGImage? {
        guard let image = image else { return nil }
        var proposedRect = CGRect(
            x: 0,
            y: 0,
            width: Double(TomyAtlasRow.columns) * TomyAtlasRow.cellWidth,
            height: Double(TomyAtlasRow.rows) * TomyAtlasRow.cellHeight
        )
        if let hiRes = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: [.ctm: AffineTransform(scale: 2.0)]),
           hiRes.width >= TomyAtlasRow.columns * 192,
           hiRes.height >= TomyAtlasRow.rows * 208 {
            return hiRes
        }
        let repImages = image.representations.compactMap { rep -> CGImage? in
            if let bitmap = rep as? NSBitmapImageRep { return bitmap.cgImage }
            var rect = CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh)
            return rep.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        if let largest = repImages.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            return largest
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private static func fallbackImage() -> NSImage? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            cwd.appendingPathComponent("TomatoBar/Assets.xcassets/TomyAtlas.imageset/TomyAtlas@2x.png"),
            cwd.appendingPathComponent("TomatoBar/Assets.xcassets/TomyAtlas.imageset/TomyAtlas.png")
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }

    private static func bakeHitMask(for cell: CGImage) -> [Bool] {
        let mw = maskWidth
        let mh = maskHeight
        var pixels = [UInt8](repeating: 0, count: mw * mh * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        pixels.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(data: base, width: mw, height: mh, bitsPerComponent: 8,
                                      bytesPerRow: mw * 4, space: colorSpace, bitmapInfo: bitmapInfo) else { return }
            ctx.interpolationQuality = .medium
            ctx.draw(cell, in: CGRect(x: 0, y: 0, width: mw, height: mh))
        }
        // CGBitmapContext row 0 corresponds to the top row of the drawn CGImage.
        return (0..<(mw * mh)).map { pixels[$0 * 4 + 3] >= hitAlphaThreshold }
    }

    func cellImage(row: TomyAtlasRow, col: Int) -> CGImage? {
        let r = row.rawValue
        guard r >= 0, r < cells.count, !cells[r].isEmpty else { return nil }
        let c = min(max(0, col), cells[r].count - 1)
        return cells[r][c]
    }

    /// Point is in top-left flipped view coordinates (`0...viewSize.width`, `0...viewSize.height`).
    func contains(point: CGPoint, in viewSize: CGSize, pose: TomyPose) -> Bool {
        guard isLoaded, viewSize.width > 0, viewSize.height > 0 else { return false }
        let r = pose.row.rawValue
        guard r >= 0, r < hitMasks.count, !hitMasks[r].isEmpty else { return false }
        let c = min(max(0, pose.col), hitMasks[r].count - 1)
        let mask = hitMasks[r][c]
        guard mask.count == Self.maskWidth * Self.maskHeight else { return false }

        var localPt = point
        if abs(pose.tiltDegrees) > 0.05 {
            let stemX = viewSize.width * 0.5
            let stemY = viewSize.height * CGFloat(TomyAtlasRow.stemPivotRatio)
            let rad = -CGFloat(pose.tiltDegrees) * .pi / 180.0
            let dx = localPt.x - stemX
            let dy = localPt.y - stemY
            let cosR = cos(rad)
            let sinR = sin(rad)
            localPt = CGPoint(
                x: stemX + dx * cosR - dy * sinR,
                y: stemY + dx * sinR + dy * cosR
            )
        }

        let anchorX = viewSize.width * 0.5
        let anchorY = viewSize.height * CGFloat(TomyAtlasRow.feetBaselineRatio)
        let sx = max(0.2, CGFloat(pose.scaleX))
        let sy = max(0.2, CGFloat(pose.scaleY))

        let unshiftedX = (localPt.x - anchorX) / sx + anchorX
        let unshiftedY = (localPt.y + CGFloat(pose.offsetY) - anchorY) / sy + anchorY
        let ux = unshiftedX / viewSize.width
        let uy = unshiftedY / viewSize.height
        guard ux >= 0, ux < 1, uy >= 0, uy < 1 else { return false }

        let mx = min(Self.maskWidth - 1, max(0, Int(ux * CGFloat(Self.maskWidth))))
        let my = min(Self.maskHeight - 1, max(0, Int(uy * CGFloat(Self.maskHeight))))
        return mask[my * Self.maskWidth + mx]
    }

    /// Draws into a flipped (`isFlipped == true`) CoreGraphics context.
    func draw(in context: CGContext, viewSize: CGSize, pose: TomyPose) {
        guard let cgImage = cellImage(row: pose.row, col: pose.col),
              viewSize.width > 0, viewSize.height > 0 else { return }

        let anchorX = viewSize.width * 0.5
        let anchorY = viewSize.height * CGFloat(TomyAtlasRow.feetBaselineRatio)

        context.saveGState()
        context.interpolationQuality = .high

        if abs(pose.tiltDegrees) > 0.05 {
            let stemX = viewSize.width * 0.5
            let stemY = viewSize.height * CGFloat(TomyAtlasRow.stemPivotRatio)
            context.translateBy(x: stemX, y: stemY)
            context.rotate(by: CGFloat(pose.tiltDegrees) * .pi / 180.0)
            context.translateBy(x: -stemX, y: -stemY)
        }

        context.translateBy(x: anchorX, y: anchorY - CGFloat(pose.offsetY))
        context.scaleBy(x: CGFloat(pose.scaleX), y: CGFloat(pose.scaleY))
        context.translateBy(x: -anchorX, y: -anchorY)

        // Locally invert Y so CGImage renders upright inside a flipped NSView.
        context.translateBy(x: 0, y: viewSize.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(origin: .zero, size: viewSize))
        context.restoreGState()
    }
}

// MARK: - Non-Activating Floating Panel

final class TomyPetPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - AppKit Sprite & Pointer Interaction Canvas

final class TomyCanvasView: NSView {
    weak var controller: TomyPetController?
    var pose = TomyPose(row: .idle, col: 0) {
        didSet {
            if pose != oldValue { needsDisplay = true }
        }
    }

    private var pointerDownScreen = NSPoint.zero
    private var panelOriginOnDown = NSPoint.zero
    private var isTrackingDown = false
    private var isDragging = false
    private var pendingAttentionClick: DispatchWorkItem?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        TomySpriteAtlas.shared.draw(in: ctx, viewSize: bounds.size, pose: pose)
    }

    func cancelPendingClick() {
        pendingAttentionClick?.cancel()
        pendingAttentionClick = nil
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            cancelPendingClick()
            controller?.showContextMenu(with: event, in: self)
            return
        }
        if event.clickCount >= 2 {
            cancelPendingClick()
        }
        isTrackingDown = true
        isDragging = false
        pointerDownScreen = NSEvent.mouseLocation
        panelOriginOnDown = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard isTrackingDown, let panel = window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - pointerDownScreen.x
        let dy = current.y - pointerDownScreen.y
        if !isDragging && hypot(dx, dy) > 4.0 {
            isDragging = true
            cancelPendingClick()
            controller?.beginDrag()
        }
        if isDragging {
            let proposed = NSPoint(x: panelOriginOnDown.x + dx, y: panelOriginOnDown.y + dy)
            controller?.movePanelDuringDrag(to: proposed, panelSize: panel.frame.size)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isTrackingDown else { return }
        isTrackingDown = false

        if isDragging {
            isDragging = false
            controller?.finishDrag()
            return
        }

        if event.clickCount >= 2 {
            cancelPendingClick()
            TBStatusItem.shared?.showMainWindow()
            return
        }

        guard let controller = controller else { return }
        switch controller.singleClickAction {
        case .wave:
            controller.triggerInteractiveWave()
        case .confirmAttention:
            cancelPendingClick()
            let item = DispatchWorkItem { [weak controller] in
                controller?.confirmAttentionFromClick()
            }
            pendingAttentionClick = item
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: item)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        cancelPendingClick()
        controller?.showContextMenu(with: event, in: self)
    }

    // MARK: - Accessibility

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? {
        controller?.accessibilitySummary ?? "番茄仔桌面伴侣"
    }
    override func accessibilityPerformPress() -> Bool {
        guard let controller = controller else { return false }
        switch controller.singleClickAction {
        case .wave: controller.triggerInteractiveWave()
        case .confirmAttention: controller.confirmAttentionFromClick()
        }
        return true
    }
}

// MARK: - Hover-Only Unobtrusive Status Capsule

final class TomyHoverModelBox: ObservableObject {
    @Published var hud = TomyHoverHUDModel(phase: .idle, paused: false, taskTitle: "", timeLeft: "25:00")
}

struct TomyHoverCapsuleView: View {
    @ObservedObject var box: TomyHoverModelBox

    private var dotColor: Color {
        switch box.hud.tone {
        case .idle: return Garden.muted
        case .work: return Garden.red
        case .paused: return Garden.colorPalette[4].color
        case .rest: return Garden.colorPalette[1].color
        case .attention: return Garden.colorPalette[2].color
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6.5, height: 6.5)

                Text(box.hud.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Garden.ink)
                    .lineLimit(1)

                if let badge = box.hud.badge {
                    Text(badge)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Garden.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Garden.red.opacity(0.11)))
                }

                Text("·")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Garden.muted.opacity(0.6))

                Text(box.hud.detail)
                    .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                    .foregroundColor(box.hud.tone == .work || box.hud.tone == .attention ? Garden.red : Garden.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5.5)

            if let progress = box.hud.progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Garden.line.opacity(0.45))
                        Rectangle()
                            .fill(dotColor)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)))
                    }
                }
                .frame(height: 2)
            }
        }
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Garden.paper.opacity(0.95))
        )
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Garden.line, lineWidth: 1)
        )
    }
}

// MARK: - Controller (Zero Idle Polling + Auto-Ghost + Magnetic Snap)

final class TomyPetController: NSObject, NSWindowDelegate {
    static let showKey = "showDesktopPet"
    static let sizeKey = "tomyPetSize"
    static let lockedKey = "tomyPetLocked"
    static let animationsKey = "gentleAnimations"
    static let originXKey = "desktopPetOriginX"
    static let originYKey = "desktopPetOriginY"
    static let originSavedKey = "desktopPetPositionSaved"

    static weak var shared: TomyPetController?

    weak var timer: TBTimer?
    private(set) var panel: TomyPetPanel?
    private var canvasView: TomyCanvasView?
    private var hoverPanel: TomyPetPanel?
    private let hoverBox = TomyHoverModelBox()

    private var engine = TomyPetEngine(now: ProcessInfo.processInfo.systemUptime)
    private var wakeTimer: Foundation.Timer?
    private var hoverDebounceTimer: Foundation.Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private struct ObservedPrefs: Equatable {
        let show: Bool
        let size: TomyPetSize
        let locked: Bool
        let animations: Bool
    }

    private var sleeping = false
    private var displaySleeping = false
    private var isOccluded = false
    private var dragging = false
    private var menuOpen = false
    private var wasNearPanel = false
    private var isHoveringOpaque = false
    private var currentGhostOpacity: Double = 1.0
    private var preSnapDragOrigin: NSPoint = .zero
    private var dragTilt: Double = 0.0
    private var lastDragX: CGFloat = 0.0
    private var lastTiltStepAt: TimeInterval?
    private var lastObservedPrefs: ObservedPrefs?

    var isPresenting: Bool {
        panel?.isVisible == true && !sleeping && !displaySleeping && !isOccluded
    }

    var singleClickAction: TomyClickAction {
        guard let phase = timer?.state.phase else { return .wave }
        return TomyClickAction.singleClick(for: phase)
    }

    var accessibilitySummary: String {
        guard let timer = timer else { return "番茄仔桌面伴侣" }
        return "番茄仔，\(timer.phaseLabel)，\(timer.timeLeft)"
    }

    init(timer: TBTimer) {
        self.timer = timer
        super.init()
        Self.shared = self

        timer.onWorkCancelled = { [weak self] in
            self?.handleWorkCancelled()
        }

        // Observe timer changes cleanly: only wake engine when phase/pause/sprint changes,
        // or refresh HUD text while the hover capsule is actually visible.
        timer.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncWithTimer()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self, selector: #selector(defaultsDidChange),
            name: UserDefaults.didChangeNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screensDidSleep),
            name: NSWorkspace.screensDidSleepNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screensDidWake),
            name: NSWorkspace.screensDidWakeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(accessibilityOptionsDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil
        )
    }

    deinit {
        stopAllTimersAndMonitors()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func setup() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.showKey) == nil {
            defaults.set(true, forKey: Self.showKey)
        }
        if defaults.object(forKey: Self.sizeKey) == nil {
            defaults.set(TomyPetSize.medium.rawValue, forKey: Self.sizeKey)
        }
        if defaults.object(forKey: Self.lockedKey) == nil {
            defaults.set(false, forKey: Self.lockedKey)
        }
        if defaults.object(forKey: Self.animationsKey) == nil {
            defaults.set(true, forKey: Self.animationsKey)
        }
        lastObservedPrefs = currentObservedPrefs()
        updateVisibility()
    }

    func shutdown() {
        stopAllTimersAndMonitors()
        canvasView?.cancelPendingClick()
        hideHoverCapsule()
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        canvasView = nil
        hoverPanel?.contentViewController = nil
        hoverPanel = nil
        cancellables.removeAll()
        if Self.shared === self { Self.shared = nil }
    }

    // MARK: - Visibility, Sizing & Positioning

    private var configuredSize: TomyPetSize {
        TomyPetSize.resolved(UserDefaults.standard.integer(forKey: Self.sizeKey))
    }

    private var isLocked: Bool {
        UserDefaults.standard.bool(forKey: Self.lockedKey)
    }

    private var animationsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.animationsKey) == nil
            ? true : UserDefaults.standard.bool(forKey: Self.animationsKey)
    }

    private var reducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func currentObservedPrefs() -> ObservedPrefs {
        ObservedPrefs(
            show: UserDefaults.standard.object(forKey: Self.showKey) == nil
                ? true : UserDefaults.standard.bool(forKey: Self.showKey),
            size: configuredSize,
            locked: isLocked,
            animations: animationsEnabled
        )
    }

    private func reconcilePreferences() {
        let next = currentObservedPrefs()
        guard next != lastObservedPrefs else { return }
        let prev = lastObservedPrefs
        lastObservedPrefs = next

        if prev?.show != next.show {
            updateVisibility()
            return
        }
        guard isPresenting else { return }

        if prev?.size != next.size {
            applyConfiguredSize()
        }
        if prev?.animations != next.animations {
            syncEngineAndRender()
        }
        if prev?.locked != next.locked {
            if next.locked && engine.cursorGlance != nil {
                let now = ProcessInfo.processInfo.systemUptime
                engine.setCursorGlance(nil, at: now)
                stepAndScheduleNext(at: now)
            }
            evaluatePointerState(at: NSEvent.mouseLocation)
        }
    }

    func updateVisibility() {
        let shouldShow = UserDefaults.standard.bool(forKey: Self.showKey) && !sleeping
        if shouldShow {
            if panel == nil {
                createPanel()
            }
            applyConfiguredSize()
            isOccluded = false
            panel?.orderFront(nil)
            installEventMonitorsIfNeeded()
            syncEngineAndRender()
            evaluatePointerState(at: NSEvent.mouseLocation)
        } else {
            isOccluded = false
            dragTilt = 0.0
            stopAllTimersAndMonitors()
            canvasView?.cancelPendingClick()
            hideHoverCapsule()
            panel?.orderOut(nil)
        }
    }

    private func createPanel() {
        let size = configuredSize.pointSize
        let origin = loadSavedOrigin(for: size)
        let petPanel = TomyPetPanel(contentRect: NSRect(origin: origin, size: size))
        petPanel.delegate = self

        let canvas = TomyCanvasView(frame: NSRect(origin: .zero, size: size))
        canvas.autoresizingMask = [.width, .height]
        canvas.controller = self
        petPanel.contentView = canvas

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelOcclusionDidChange(_:)),
            name: NSWindow.didChangeOcclusionStateNotification,
            object: petPanel
        )

        self.panel = petPanel
        self.canvasView = canvas
        ensurePanelOnScreen()
    }

    func applyConfiguredSize() {
        guard let panel = panel else { return }
        let target = configuredSize.pointSize
        guard panel.frame.size != target else { return }
        // Anchor bottom-center when resizing so Tomy stays planted on the same spot.
        let newOrigin = CGPoint(
            x: panel.frame.midX - target.width * 0.5,
            y: panel.frame.minY
        )
        let screenFrame = activeScreen(for: panel.frame)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let clamped = TomyPetPlacement.clampAndSnap(origin: newOrigin, size: target, visibleFrame: screenFrame)
        panel.setFrame(NSRect(origin: clamped, size: target), display: true)
        saveCurrentPosition()
        if hoverPanel?.isVisible == true {
            positionHoverCapsule()
        }
    }

    func resetToDefaultCorner() {
        let targetSize = panel?.frame.size ?? configuredSize.pointSize
        let referenceFrame = panel?.frame ?? NSRect(origin: .zero, size: targetSize)
        let visible = activeScreen(for: referenceFrame)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = TomyPetPlacement.defaultOrigin(size: targetSize, visibleFrame: visible)
        if let panel = panel {
            panel.setFrameOrigin(origin)
            saveCurrentPosition()
            positionHoverCapsule()
        } else {
            let defaults = UserDefaults.standard
            defaults.set(Double(origin.x), forKey: Self.originXKey)
            defaults.set(Double(origin.y), forKey: Self.originYKey)
            defaults.set(true, forKey: Self.originSavedKey)
        }
    }

    private func loadSavedOrigin(for size: CGSize) -> CGPoint {
        let defaults = UserDefaults.standard
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        guard defaults.bool(forKey: Self.originSavedKey) else {
            return TomyPetPlacement.defaultOrigin(size: size, visibleFrame: visible)
        }
        let x = defaults.double(forKey: Self.originXKey)
        let y = defaults.double(forKey: Self.originYKey)
        guard x.isFinite, y.isFinite else {
            return TomyPetPlacement.defaultOrigin(size: size, visibleFrame: visible)
        }
        let candidate = NSRect(origin: CGPoint(x: x, y: y), size: size)
        let targetVisible = activeScreen(for: candidate)?.visibleFrame ?? visible
        return TomyPetPlacement.clampAndSnap(origin: candidate.origin, size: size, visibleFrame: targetVisible)
    }

    func saveCurrentPosition() {
        guard let panel = panel else { return }
        let defaults = UserDefaults.standard
        defaults.set(Double(panel.frame.minX), forKey: Self.originXKey)
        defaults.set(Double(panel.frame.minY), forKey: Self.originYKey)
        defaults.set(true, forKey: Self.originSavedKey)
    }

    private func ensurePanelOnScreen() {
        guard let panel = panel, let screen = activeScreen(for: panel.frame) else { return }
        let clamped = TomyPetPlacement.clampAndSnap(origin: panel.frame.origin, size: panel.frame.size, visibleFrame: screen.visibleFrame)
        if clamped != panel.frame.origin {
            panel.setFrameOrigin(clamped)
            saveCurrentPosition()
        }
    }

    private func activeScreen(for frame: NSRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            let ia = a.visibleFrame.intersection(frame)
            let ib = b.visibleFrame.intersection(frame)
            let areaA = ia.isNull ? 0 : ia.width * ia.height
            let areaB = ib.isNull ? 0 : ib.width * ib.height
            return areaA < areaB
        } ?? NSScreen.main
    }

    // MARK: - Engine & Single-Shot Frame Scheduling (0% Idle CPU)

    private func syncWithTimer() {
        guard let timer = timer else { return }
        let rem = timer.state.isTiming ? timer.state.timeLeft(at: timer.now) : nil
        let nextSprint = (timer.state.phase == .work && !timer.state.paused && (rem ?? 9999) <= 180)
        let stateChanged = (engine.phase != timer.state.phase) ||
                           (engine.paused != timer.state.paused) ||
                           (engine.isSprint != nextSprint)

        if stateChanged && isPresenting {
            syncEngineAndRender()
        }
        if hoverPanel?.isVisible == true {
            refreshHoverModel()
            positionHoverCapsule()
        }
    }

    private func handleWorkCancelled() {
        guard isPresenting else { return }
        let now = ProcessInfo.processInfo.systemUptime
        engine.triggerCancelSad(at: now)
        stepAndScheduleNext(at: now)
    }

    func triggerInteractiveWave() {
        guard isPresenting else { return }
        let now = ProcessInfo.processInfo.systemUptime
        engine.triggerWave(at: now)
        stepAndScheduleNext(at: now)
    }

    func confirmAttentionFromClick() {
        guard let timer = timer, timer.state.needsAttention else { return }
        guard timer.storageError == nil else {
            timer.onAttention?()
            return
        }
        switch timer.state.phase {
        case .workFinished: timer.startRest()
        case .restFinished: timer.startWork()
        case .idle, .work, .rest: break
        }
    }

    private func syncEngineAndRender() {
        guard let timer = timer else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let rem = timer.state.isTiming ? timer.state.timeLeft(at: timer.now) : nil
        engine.sync(
            phase: timer.state.phase,
            paused: timer.state.paused,
            timeLeftSeconds: rem,
            animationsEnabled: animationsEnabled,
            reducedMotion: reducedMotion,
            at: now
        )
        stepAndScheduleNext(at: now)
    }

    private func stepAndScheduleNext(at uptime: TimeInterval) {
        wakeTimer?.invalidate()
        wakeTimer = nil

        if animationsEnabled && !reducedMotion && abs(dragTilt) > 0.15 {
            let dt = min(0.05, max(0.0, lastTiltStepAt.map { uptime - $0 } ?? 0.016))
            lastTiltStepAt = uptime
            let decayBase: Double = dragging ? 0.12 : 0.04
            dragTilt *= pow(decayBase, dt)
            if abs(dragTilt) <= 0.15 {
                dragTilt = 0.0
                lastTiltStepAt = nil
            }
        } else {
            dragTilt = 0.0
            lastTiltStepAt = nil
        }

        var nextPose = engine.advance(to: uptime)
        nextPose.tiltDegrees = dragTilt
        canvasView?.pose = nextPose
        if wasNearPanel {
            evaluatePointerState(at: NSEvent.mouseLocation, allowEngineWake: false)
        }

        let engineDelay = engine.nextWakeDelay(at: uptime, isVisible: isPresenting)
        let tiltActive = abs(dragTilt) > 0.15 && isPresenting && animationsEnabled && !reducedMotion
        let delay: TimeInterval? = tiltActive ? min(engineDelay ?? 1.0, 1.0 / 60.0) : engineDelay
        guard let delay = delay else { return }

        let highPrecision = tiltActive || engine.isLandingActive
        let timer = Foundation.Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, self.isPresenting else { return }
            self.stepAndScheduleNext(at: ProcessInfo.processInfo.systemUptime)
        }
        timer.tolerance = highPrecision ? 0.002 : min(0.05, max(0.008, delay * 0.18))
        RunLoop.main.add(timer, forMode: .common)
        wakeTimer = timer
    }

    // MARK: - Drag & Landing Physics

    func beginDrag() {
        dragging = true
        hideHoverCapsule()
        if let panel = panel {
            preSnapDragOrigin = panel.frame.origin
            panel.ignoresMouseEvents = false
            setPanelOpacity(1.0)
        }
        dragTilt = 0.0
        lastDragX = preSnapDragOrigin.x
        lastTiltStepAt = nil
        let now = ProcessInfo.processInfo.systemUptime
        engine.setDragging(true, at: now)
        stepAndScheduleNext(at: now)
    }

    func movePanelDuringDrag(to proposedOrigin: NSPoint, panelSize: NSSize) {
        guard let panel = panel else { return }
        let probe = NSRect(origin: proposedOrigin, size: panelSize)
        let visible = activeScreen(for: probe)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let minX = visible.minX + TomyPetPlacement.edgeMargin
        let maxX = max(minX, visible.maxX - panelSize.width - TomyPetPlacement.edgeMargin)
        let minY = visible.minY
        let maxY = max(minY, visible.maxY - panelSize.height - TomyPetPlacement.edgeMargin)
        let clamped = NSPoint(
            x: min(max(proposedOrigin.x, minX), maxX),
            y: min(max(proposedOrigin.y, minY), maxY)
        )
        let dx = clamped.x - lastDragX
        lastDragX = clamped.x
        preSnapDragOrigin = clamped
        panel.setFrameOrigin(clamped)

        if animationsEnabled && !reducedMotion {
            let targetTilt = min(max(Double(dx) * 0.65, -10.5), 10.5)
            dragTilt = dragTilt * 0.62 + targetTilt * 0.38
            if abs(dragTilt) > 0.15 {
                let now = ProcessInfo.processInfo.systemUptime
                lastTiltStepAt = now
                canvasView?.pose.tiltDegrees = dragTilt
                if wakeTimer == nil || (wakeTimer?.fireDate.timeIntervalSinceNow ?? 1.0) > 0.025 {
                    stepAndScheduleNext(at: now)
                }
            }
        } else {
            dragTilt = 0.0
        }
    }

    func finishDrag() {
        dragging = false
        guard let panel = panel else { return }
        let visible = activeScreen(for: panel.frame)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let snapped = TomyPetPlacement.clampAndSnap(origin: preSnapDragOrigin, size: panel.frame.size, visibleFrame: visible)
        let snapDrop = max(0, Double(preSnapDragOrigin.y - snapped.y))
        panel.setFrameOrigin(snapped)
        saveCurrentPosition()

        // Always impart at least a light tactile settle (10pt equivalent) on drop, larger if snapped down to Dock.
        let effectiveDrop = max(10.0, snapDrop)
        let now = ProcessInfo.processInfo.systemUptime
        engine.setDragging(false, dropDistancePt: effectiveDrop, at: now)
        stepAndScheduleNext(at: now)
        evaluatePointerState(at: NSEvent.mouseLocation)
    }

    // MARK: - Event-Driven Pointer, Pixel Hit-Test & Auto-Ghost

    private func installEventMonitorsIfNeeded() {
        guard globalMonitor == nil && localMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .flagsChanged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.evaluatePointerState(at: NSEvent.mouseLocation)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.evaluatePointerState(at: NSEvent.mouseLocation)
            return event
        }
    }

    private func stopAllTimersAndMonitors() {
        wakeTimer?.invalidate()
        wakeTimer = nil
        hoverDebounceTimer?.invalidate()
        hoverDebounceTimer = nil
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
        wasNearPanel = false
        isHoveringOpaque = false
    }

    private func evaluatePointerState(at screenPoint: NSPoint, allowEngineWake: Bool = true) {
        guard let panel = panel, panel.isVisible, !sleeping, !displaySleeping, !isOccluded, !dragging, !menuOpen,
              let canvas = canvasView else { return }

        let frame = panel.frame
        let glanceActive = (engine.phase == .idle && !engine.paused && !isLocked && animationsEnabled && !reducedMotion)
        let inset: CGFloat = glanceActive ? -175 : -12
        let hotZone = frame.insetBy(dx: inset, dy: inset)

        if !hotZone.contains(screenPoint) {
            if wasNearPanel {
                wasNearPanel = false
                isHoveringOpaque = false
                if !panel.ignoresMouseEvents { panel.ignoresMouseEvents = true }
                setPanelOpacity(1.0)
                hideHoverCapsule()
            }
            if allowEngineWake && engine.cursorGlance != nil {
                let now = ProcessInfo.processInfo.systemUptime
                engine.setCursorGlance(nil, at: now)
                stepAndScheduleNext(at: now)
            }
            return
        }
        wasNearPanel = true

        if allowEngineWake {
            let nextGlance: TomyGlanceDirection? = glanceActive
                ? TomyGlanceDirection.resolve(petCenter: CGPoint(x: frame.midX, y: frame.midY), mousePoint: screenPoint)
                : nil
            if engine.cursorGlance != nextGlance {
                let now = ProcessInfo.processInfo.systemUptime
                engine.setCursorGlance(nextGlance, at: now)
                stepAndScheduleNext(at: now)
            }
        }

        let insideBounds = frame.contains(screenPoint)
        let hitOpaque: Bool
        if insideBounds {
            let winPt = panel.convertPoint(fromScreen: screenPoint)
            let viewPt = canvas.convert(winPt, from: nil)
            hitOpaque = TomySpriteAtlas.shared.contains(point: viewPt, in: canvas.bounds.size, pose: canvas.pose)
        } else {
            hitOpaque = false
        }

        let optionPressed = NSEvent.modifierFlags.contains(.option)
        let policy = TomyGhostPolicy.resolve(
            locked: isLocked,
            optionPressed: optionPressed,
            hitOpaquePixel: hitOpaque,
            pointerInsideBounds: insideBounds
        )

        if panel.ignoresMouseEvents != policy.ignoresMouseEvents {
            panel.ignoresMouseEvents = policy.ignoresMouseEvents
        }
        setPanelOpacity(policy.opacity)

        let shouldHoverHUD = hitOpaque && (!isLocked || optionPressed)
        if shouldHoverHUD != isHoveringOpaque {
            isHoveringOpaque = shouldHoverHUD
            if shouldHoverHUD {
                scheduleHoverCapsule()
                if allowEngineWake && glanceActive {
                    let now = ProcessInfo.processInfo.systemUptime
                    engine.triggerHoverPerk(at: now)
                    stepAndScheduleNext(at: now)
                }
            } else {
                hideHoverCapsule()
            }
        }
    }

    private func setPanelOpacity(_ target: Double) {
        guard abs(currentGhostOpacity - target) > 0.01, let panel = panel else { return }
        currentGhostOpacity = target
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            panel.animator().alphaValue = CGFloat(target)
        }
    }

    // MARK: - Hover HUD Capsule Management

    private func scheduleHoverCapsule() {
        hoverDebounceTimer?.invalidate()
        let t = Foundation.Timer(timeInterval: 0.12, repeats: false) { [weak self] _ in
            guard let self = self, self.isHoveringOpaque, self.isPresenting, !self.dragging, !self.menuOpen else { return }
            self.showHoverCapsule()
        }
        RunLoop.main.add(t, forMode: .common)
        hoverDebounceTimer = t
    }

    private func showHoverCapsule() {
        if hoverPanel == nil {
            let host = NSHostingController(rootView: TomyHoverCapsuleView(box: hoverBox))
            let bubble = TomyPetPanel(contentRect: .zero)
            bubble.ignoresMouseEvents = true
            bubble.contentViewController = host
            hoverPanel = bubble
        }
        refreshHoverModel()
        if let bubble = hoverPanel, let view = bubble.contentViewController?.view {
            view.layoutSubtreeIfNeeded()
            let fit = view.fittingSize
            if fit.width > 10 && bubble.frame.size != fit {
                bubble.setContentSize(fit)
            }
        }
        positionHoverCapsule()
        if hoverPanel?.isVisible == false {
            hoverPanel?.orderFront(nil)
        }
    }

    private func hideHoverCapsule() {
        hoverDebounceTimer?.invalidate()
        hoverDebounceTimer = nil
        if hoverPanel?.isVisible == true {
            hoverPanel?.orderOut(nil)
        }
    }

    private func refreshHoverModel() {
        guard let timer = timer else { return }
        let state = timer.state
        let taskTitle: String = {
            if let todo = state.currentTodo {
                return state.displayName(for: todo)
            }
            return timer.eventName
        }()
        let progress: Double? = {
            guard state.isTiming, state.planned > 0 else { return nil }
            let rem = state.timeLeft(at: timer.now)
            return 1.0 - (rem / state.planned)
        }()
        hoverBox.hud = TomyHoverHUDModel(
            phase: state.phase,
            paused: state.paused,
            taskTitle: taskTitle,
            timeLeft: timer.timeLeft,
            progress: progress,
            todayCompletedCount: timer.todayCount,
            workIntervalsInSet: timer.workIntervalsInSet
        )
        if let bubble = hoverPanel, let view = bubble.contentViewController?.view {
            let size = view.fittingSize
            if size.width > 10 && bubble.frame.size != size {
                bubble.setContentSize(size)
            }
        }
    }

    private func positionHoverCapsule() {
        guard let panel = panel, let bubble = hoverPanel else { return }
        let visible = activeScreen(for: panel.frame)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let bSize = bubble.frame.size
        let aboveY = panel.frame.maxY + 4
        let belowY = panel.frame.minY - bSize.height - 4
        let y = (aboveY + bSize.height <= visible.maxY - 4) ? aboveY : max(visible.minY + 4, belowY)
        let rawX = panel.frame.midX - bSize.width * 0.5
        let x = min(max(rawX, visible.minX + 6), max(visible.minX + 6, visible.maxX - bSize.width - 6))
        bubble.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    // MARK: - Rich Native Context Menu

    func showContextMenu(with event: NSEvent, in view: NSView) {
        guard let timer = timer else { return }
        menuOpen = true
        hideHoverCapsule()
        setPanelOpacity(1.0)

        let menu = NSMenu()
        menu.autoenablesItems = false

        // 1. Primary Pomodoro Control
        let primaryTitle: String
        switch timer.state.phase {
        case .idle:
            primaryTitle = "▶️ 开始专注 (\(timer.workIntervalLength) 分钟)"
        case .work:
            primaryTitle = timer.state.paused ? "▶️ 继续专注 (\(timer.timeLeft))" : "⏸️ 暂停专注 (\(timer.timeLeft))"
        case .rest:
            primaryTitle = timer.state.paused ? "▶️ 继续休息 (\(timer.timeLeft))" : "⏸️ 暂停休息 (\(timer.timeLeft))"
        case .workFinished:
            primaryTitle = "🔔 确认完成 · 进入休息"
        case .restFinished:
            primaryTitle = "🔔 休息结束 · 开启下一轮"
        }
        let primaryItem = NSMenuItem(title: primaryTitle, action: #selector(menuPrimaryAction), keyEquivalent: "")
        primaryItem.target = self
        primaryItem.isEnabled = (timer.storageError == nil || timer.state.isTiming || timer.state.needsAttention)
        menu.addItem(primaryItem)

        if timer.state.phase == .work {
            let cancelItem = NSMenuItem(title: "⏹️ 放弃这段专注…", action: #selector(menuCancelWork), keyEquivalent: "")
            cancelItem.target = self
            menu.addItem(cancelItem)
        } else if timer.state.phase == .rest || timer.state.phase == .workFinished {
            let skipItem = NSMenuItem(title: "⏭️ 跳过休息", action: #selector(menuSkipRest), keyEquivalent: "")
            skipItem.target = self
            skipItem.isEnabled = (timer.storageError == nil)
            menu.addItem(skipItem)
        }

        // 2. Quick Task Switcher
        let activeTodos = timer.state.todos.filter { !$0.isCompleted }
        if !activeTodos.isEmpty {
            let taskRoot = NSMenuItem(title: "🎯 当前专注任务", action: nil, keyEquivalent: "")
            let taskSub = NSMenu()
            taskSub.autoenablesItems = false

            let freeItem = NSMenuItem(title: "自由专注（不绑定待办）", action: #selector(menuSelectTodo(_:)), keyEquivalent: "")
            freeItem.target = self
            freeItem.state = (timer.state.currentTodoID == nil) ? .on : .off
            freeItem.isEnabled = !timer.state.isTiming && !timer.state.needsAttention
            taskSub.addItem(freeItem)
            taskSub.addItem(.separator())

            for todo in activeTodos.prefix(12) {
                let item = NSMenuItem(title: timer.state.displayName(for: todo), action: #selector(menuSelectTodo(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = todo.id
                item.state = (timer.state.currentTodoID == todo.id) ? .on : .off
                item.isEnabled = !timer.state.isTiming && !timer.state.needsAttention
                taskSub.addItem(item)
            }
            taskRoot.submenu = taskSub
            menu.addItem(taskRoot)
        }

        menu.addItem(.separator())

        // 3. Size Submenu (64 / 80 / 96pt)
        let sizeRoot = NSMenuItem(title: "📐 番茄仔尺寸", action: nil, keyEquivalent: "")
        let sizeSub = NSMenu()
        let curSize = configuredSize
        for preset in TomyPetSize.allCases {
            let item = NSMenuItem(title: preset.menuTitle, action: #selector(menuSelectSize(_:)), keyEquivalent: "")
            item.target = self
            item.tag = preset.rawValue
            item.state = (preset == curSize) ? .on : .off
            sizeSub.addItem(item)
        }
        sizeRoot.submenu = sizeSub
        menu.addItem(sizeRoot)

        // 4. Auto-Ghost Lock Toggle & Snap Reset
        let lockItem = NSMenuItem(
            title: "👻 锁定位置并穿透（按住 ⌥ 临时移动）",
            action: #selector(menuToggleLock),
            keyEquivalent: ""
        )
        lockItem.target = self
        lockItem.state = isLocked ? .on : .off
        menu.addItem(lockItem)

        let resetPosItem = NSMenuItem(title: "🧲 贴回屏幕右下角", action: #selector(menuResetCorner), keyEquivalent: "")
        resetPosItem.target = self
        menu.addItem(resetPosItem)

        menu.addItem(.separator())

        let mainWinItem = NSMenuItem(title: "📖 打开专注时光主面板", action: #selector(menuOpenMainWindow), keyEquivalent: "")
        mainWinItem.target = self
        menu.addItem(mainWinItem)

        let hideItem = NSMenuItem(title: "🙈 隐藏桌面伴侣", action: #selector(menuHidePet), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        let loc = view.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: loc, in: view)

        menuOpen = false
        evaluatePointerState(at: NSEvent.mouseLocation)
    }

    @objc private func menuPrimaryAction() {
        guard let timer = timer else { return }
        if timer.state.needsAttention {
            confirmAttentionFromClick()
        } else {
            timer.primaryAction()
        }
    }

    func applyCancelWorkDecision(confirmedCancel: Bool, wasPaused: Bool) {
        if confirmedCancel {
            timer?.cancel()
        } else if !wasPaused, let timer = timer, timer.state.phase == .work, timer.state.paused {
            timer.togglePause()
        }
    }

    @objc private func menuCancelWork() {
        guard let timer = timer else { return }
        let wasPaused = timer.state.paused
        guard timer.freezeForCancel() else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "放弃这段专注？"
        alert.informativeText = cancelFocusMessage(timer.state)
        alert.addButton(withTitle: "继续专注")
        alert.addButton(withTitle: "放弃这段")
        if #available(macOS 11.0, *) {
            alert.buttons.last?.hasDestructiveAction = true
        }
        NSApp.activate(ignoringOtherApps: true)
        let confirmedCancel = (alert.runModal() == .alertSecondButtonReturn)
        applyCancelWorkDecision(confirmedCancel: confirmedCancel, wasPaused: wasPaused)
    }

    @objc private func menuSkipRest() {
        timer?.skipRest()
    }

    @objc private func menuSelectTodo(_ sender: NSMenuItem) {
        let id = sender.representedObject as? UUID
        timer?.selectCurrentTodo(id)
    }

    @objc private func menuSelectSize(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: Self.sizeKey)
        reconcilePreferences()
    }

    @objc private func menuToggleLock() {
        UserDefaults.standard.set(!isLocked, forKey: Self.lockedKey)
        reconcilePreferences()
    }

    @objc private func menuResetCorner() {
        resetToDefaultCorner()
    }

    @objc private func menuOpenMainWindow() {
        TBStatusItem.shared?.showMainWindow()
    }

    @objc private func menuHidePet() {
        UserDefaults.standard.set(false, forKey: Self.showKey)
        reconcilePreferences()
    }

    // MARK: - System Notifications

    @objc private func defaultsDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.reconcilePreferences()
        }
    }

    @objc private func screenParametersDidChange() {
        ensurePanelOnScreen()
        if hoverPanel?.isVisible == true {
            positionHoverCapsule()
        }
    }

    @objc private func systemWillSleep() {
        sleeping = true
        stopAllTimersAndMonitors()
        canvasView?.cancelPendingClick()
        hideHoverCapsule()
    }

    @objc private func systemDidWake() {
        sleeping = false
        displaySleeping = false
        updateVisibility()
    }

    @objc private func screensDidSleep() {
        displaySleeping = true
        wakeTimer?.invalidate()
        wakeTimer = nil
        hideHoverCapsule()
    }

    @objc private func screensDidWake() {
        displaySleeping = false
        if isPresenting {
            stepAndScheduleNext(at: ProcessInfo.processInfo.systemUptime)
        }
    }

    @objc private func panelOcclusionDidChange(_ notification: Notification) {
        guard let panel = panel, panel.isVisible else { return }
        let nextOccluded = !panel.occlusionState.contains(.visible)
        guard nextOccluded != isOccluded else { return }
        isOccluded = nextOccluded
        if isOccluded {
            wakeTimer?.invalidate()
            wakeTimer = nil
            hideHoverCapsule()
        } else if !sleeping && !displaySleeping {
            stepAndScheduleNext(at: ProcessInfo.processInfo.systemUptime)
        }
    }

    @objc private func accessibilityOptionsDidChange() {
        if isPresenting {
            syncEngineAndRender()
        }
    }

    func windowDidMove(_ notification: Notification) {
        if !dragging {
            saveCurrentPosition()
        }
        if hoverPanel?.isVisible == true {
            positionHoverCapsule()
        }
    }
}
