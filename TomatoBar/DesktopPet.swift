import AppKit
import SwiftUI

// MARK: - Pet Model & Assets


enum PetStripLoopMode: Equatable {
    case loop
    case onceHold
}

struct PetStripAnimation: Equatable {
    let assetName: String
    let frameCount: Int
    let durations: [TimeInterval]
    let loopMode: PetStripLoopMode

    func duration(at index: Int) -> TimeInterval {
        guard !durations.isEmpty else { return 0.12 }
        return durations[min(max(index, 0), durations.count - 1)]
    }
}

/// One frame of a strip, content-cropped and grounded on the bottom edge of
/// the shared content box.
private struct PetSpriteStripView: View {
    let asset: PetSpriteAsset
    let frameCount: Int
    let frameIndex: Int
    let scale: CGFloat
    let box: CGSize

    var body: some View {
        let safeCount = max(frameCount, 1)
        let safeIndex = min(max(frameIndex, 0), safeCount - 1)
        let cellWidth = asset.cellSize.width * scale
        let cellHeight = asset.cellSize.height * scale

        Image(nsImage: asset.image)
            .resizable()
            .interpolation(.none)
            .frame(width: asset.pixelSize.width * scale, height: cellHeight)
            .offset(x: -cellWidth * CGFloat(safeIndex))
            .frame(width: cellWidth, height: cellHeight, alignment: .leading)
            .clipped()
            .frame(width: box.width, height: box.height, alignment: .bottom)
    }
}

/// Fallback for contexts without an asset catalog (tests, probes). Keeps the
/// previous canvas-fitting behavior so a missing scan never blanks the pet.
private struct PetSpriteStripFallbackView: View {
    let assetName: String
    let frameCount: Int
    let frameIndex: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let safeCount = max(frameCount, 1)
        let safeIndex = min(max(frameIndex, 0), safeCount - 1)

        Image(assetName)
            .resizable()
            .interpolation(.none)
            .frame(width: width * CGFloat(safeCount), height: height)
            .offset(x: -width * CGFloat(safeIndex))
            .frame(width: width, height: height, alignment: .leading)
            .clipped()
    }
}

/// A single content-cropped image, grounded on the shared baseline.
private struct PetSpriteStillView: View {
    let asset: PetSpriteAsset
    let scale: CGFloat
    let box: CGSize

    var body: some View {
        Image(nsImage: asset.image)
            .resizable()
            .interpolation(.none)
            .frame(width: asset.pixelSize.width * scale, height: asset.pixelSize.height * scale)
            .frame(width: box.width, height: box.height, alignment: .bottom)
    }
}


enum PetKind: String, CaseIterable, Identifiable {
    case tomy = "tomy"
    case sprout = "sprout"
    case chip = "chip"
    case clay = "clay"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tomy: return "🍅 番茄仔 · Tomy"
        case .sprout: return "🌱 植小芽 · Sprout"
        case .chip: return "🐱 码小黑 · Chip"
        case .clay: return "💧 陶土团 · Clay"
        }
    }

    var shortName: String {
        switch self {
        case .tomy: return "番茄仔"
        case .sprout: return "植小芽"
        case .chip: return "码小黑"
        case .clay: return "陶土团"
        }
    }

    var icon: String {
        switch self {
        case .tomy: return "🍅"
        case .sprout: return "🌱"
        case .chip: return "🐱"
        case .clay: return "💧"
        }
    }

    var tagline: String {
        switch self {
        case .tomy: return "一颗柔软的小番茄，安静陪你进入心流"
        case .sprout: return "静悄悄拔节，破土而出的蓬勃专注力"
        case .chip: return "复古极简键盘猫，代码飞按声是最棒的白噪音"
        case .clay: return "温润小陶团，静心沉淀每一段专注时光"
        }
    }


    func stripAnimation(for phase: FocusPhase, paused: Bool) -> PetStripAnimation? {
        switch self {
        case .tomy:
            if paused {
                return PetStripAnimation(
                    assetName: "pet_tomy_paused_v2",
                    frameCount: 4,
                    durations: [0.70, 0.70, 0.12, 0.70],
                    loopMode: .loop
                )
            }

            switch phase {
            case .work:
                return PetStripAnimation(
                    assetName: "pet_tomy_work_v2",
                    frameCount: 10,
                    durations: [0.11, 0.10, 0.12, 0.11, 0.06, 0.08, 0.12, 0.11, 0.12, 0.13],
                    loopMode: .loop
                )
            case .idle:
                return PetStripAnimation(
                    assetName: "pet_tomy_idle_v2",
                    frameCount: 8,
                    durations: [0.42, 0.42, 0.42, 0.07, 0.10, 0.07, 0.52, 0.52],
                    loopMode: .loop
                )
            case .rest:
                return PetStripAnimation(
                    assetName: "pet_tomy_rest_v2",
                    frameCount: 8,
                    durations: Array(repeating: 0.22, count: 8),
                    loopMode: .loop
                )
            case .workFinished:
                return PetStripAnimation(
                    assetName: "pet_tomy_work_finished_v2",
                    frameCount: 8,
                    durations: [0.13, 0.11, 0.11, 0.18, 0.18, 0.14, 0.18, 0.70],
                    loopMode: .onceHold
                )
            case .restFinished:
                return PetStripAnimation(
                    assetName: "pet_tomy_rest_finished_v2",
                    frameCount: 8,
                    durations: [0.26, 0.22, 0.16, 0.15, 0.14, 0.12, 0.12, 0.65],
                    loopMode: .onceHold
                )
            }

        case .sprout:
            // Sprout V3 keeps phase semantics visible even while paused:
            // work-paused still holds the reading pose, while rest-paused
            // stays beside the flowerpot instead of collapsing into one
            // generic paused sprite.
            if paused {
                switch phase {
                case .work:
                    return PetStripAnimation(
                        assetName: "pet_sprout_work_paused_v3",
                        frameCount: 4,
                        durations: [0.70, 0.70, 0.15, 0.70],
                        loopMode: .loop
                    )
                case .rest:
                    return PetStripAnimation(
                        assetName: "pet_sprout_rest_paused_v3",
                        frameCount: 4,
                        durations: [0.60, 0.60, 0.60, 0.60],
                        loopMode: .loop
                    )
                default:
                    break
                }
            }

            switch phase {
            case .work:
                return PetStripAnimation(
                    assetName: "pet_sprout_work_v3",
                    frameCount: 10,
                    durations: [0.16, 0.14, 0.12, 0.16, 0.10, 0.12, 0.15, 0.14, 0.13, 0.16],
                    loopMode: .loop
                )
            case .idle:
                return PetStripAnimation(
                    assetName: "pet_sprout_idle_v3",
                    frameCount: 8,
                    durations: [0.45, 0.45, 0.45, 0.08, 0.10, 0.08, 0.55, 0.55],
                    loopMode: .loop
                )
            case .rest:
                return PetStripAnimation(
                    assetName: "pet_sprout_rest_v3",
                    frameCount: 8,
                    durations: Array(repeating: 0.32, count: 8),
                    loopMode: .loop
                )
            case .workFinished:
                return PetStripAnimation(
                    assetName: "pet_sprout_work_finished_v3",
                    frameCount: 8,
                    durations: [0.16, 0.14, 0.13, 0.14, 0.16, 0.16, 0.20, 0.75],
                    loopMode: .onceHold
                )
            case .restFinished:
                return PetStripAnimation(
                    assetName: "pet_sprout_rest_finished_v3",
                    frameCount: 8,
                    durations: [0.28, 0.24, 0.20, 0.18, 0.16, 0.15, 0.16, 0.70],
                    loopMode: .onceHold
                )
            }

        case .chip, .clay:
            return nil
        }
    }

    /// Multi-frame sprite animation sequence for each phase.
    func frameNames(for phase: FocusPhase) -> [String] {
        switch self {
        case .tomy:
            switch phase {
            case .work:
                return (0..<10).map { "pet_tomy_work_\($0)" }
            case .rest:
                return (0..<8).map { "pet_tomy_rest_\($0)" }
            case .workFinished:
                return (0..<8).map { "pet_tomy_work_finished_\($0)" }
            case .restFinished:
                return (0..<8).map { "pet_tomy_rest_finished_\($0)" }
            case .idle:
                return (0..<8).map { "pet_tomy_idle_\($0)" }
            }
        case .chip:
            switch phase {
            case .work:
                // The four generated work drawings are unrelated compositions
                // (the monitor swaps sides, the cat flips, and one frame adds a
                // second cat), so cycling them read as flicker. Hold the
                // cleanest single scene instead.
                return ["pet_chip_work_0"]
            case .rest:
                return ["pet_chip_rest"]
            case .workFinished, .restFinished:
                // The two-cat desk is the drawing authored as a celebration;
                // hold it instead of replaying the four scenes backwards.
                return ["pet_chip_work_3"]
            case .idle:
                return ["pet_chip_idle"]
            }
        case .sprout:
            let single = singleImageName(for: phase)
            return [single, single, single, single]
        case .clay:
            return [singleImageName(for: phase)]
        }
    }

    func singleImageName(for phase: FocusPhase) -> String {
        switch self {
        case .tomy:
            switch phase {
            case .work, .workFinished: return "pet_tomy_focus"
            case .rest, .restFinished: return "pet_tomy_rest"
            case .idle: return "pet_tomy_idle"
            }
        case .chip:
            switch phase {
            case .work, .workFinished: return "pet_chip_focus"
            case .rest, .restFinished: return "pet_chip_rest"
            case .idle: return "pet_chip_idle"
            }
        case .sprout:
            switch phase {
            case .work, .workFinished: return "pet_sprout_focus"
            case .rest, .restFinished: return "pet_sprout_rest"
            case .idle: return "pet_sprout_idle"
            }
        case .clay:
            switch phase {
            case .work, .workFinished: return "pet_clay_focus"
            case .rest, .restFinished: return "pet_clay_rest"
            case .idle: return "pet_clay_idle"
            }
        }
    }

    func imageName(for phase: FocusPhase) -> String {
        singleImageName(for: phase)
    }

    /// Every image the legacy (non-compact) view can display for this pet.
    /// Used to normalize apparent size across phases before the first frame is
    /// drawn. Tomy uses the compact atlas and therefore has no legacy assets.
    var legacyDisplayAssets: [(name: String, frames: Int)] {
        guard self != .tomy else { return [] }
        var seen = Set<String>()
        var result: [(name: String, frames: Int)] = []
        let phases: [FocusPhase] = [.idle, .work, .rest, .workFinished, .restFinished]
        for phase in phases {
            for paused in [false, true] {
                if let strip = stripAnimation(for: phase, paused: paused) {
                    if seen.insert(strip.assetName).inserted {
                        result.append((strip.assetName, strip.frameCount))
                    }
                    continue
                }
                for name in frameNames(for: phase) where seen.insert(name).inserted {
                    result.append((name, 1))
                }
            }
        }
        return result
    }
}

// MARK: - Native Mouse Event & Drag Handling

final class DesktopPetEventView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    var onDragEnded: (() -> Void)?
    var onHoverStateChanged: ((Bool) -> Void)?
    var onDragBegan: (() -> Void)?
    var acceptsPoint: ((CGPoint, CGSize) -> Bool)?
    var onPresentationChanged: ((Bool) -> Void)?

    private var didDrag = false
    private var trackingArea: NSTrackingArea?
    private var pendingClick: DispatchWorkItem?
    private(set) var hovering = false

    override var acceptsFirstResponder: Bool { false }
    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window is DesktopPetPanel { DesktopPetController.shared?.register(self) }
    }

    func accepts(_ point: CGPoint) -> Bool {
        bounds.contains(point) && (acceptsPoint?(point, bounds.size) ?? true)
    }

    func setHovered(_ value: Bool) {
        guard hovering != value else { return }
        hovering = value
        onHoverStateChanged?(value)
    }

    func cancelPendingClick() { pendingClick?.cancel(); pendingClick = nil }

    override func accessibilityPerformPress() -> Bool {
        onSingleClick?()
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        setHovered(accepts(convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHovered(false)
    }

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        if event.clickCount > 1 { cancelPendingClick() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didDrag else { return }
        cancelPendingClick()
        didDrag = true
        DesktopPetController.shared?.setDragging(true)
        onDragBegan?()
        window?.performDrag(with: event)
        onDragEnded?()
        DesktopPetController.shared?.setDragging(false)
    }

    override func mouseUp(with event: NSEvent) {
        guard !didDrag else {
            didDrag = false
            return
        }
        if event.clickCount == 2 {
            cancelPendingClick()
            onDoubleClick?()
        } else if event.clickCount == 1 {
            cancelPendingClick()
            let click = DispatchWorkItem { [weak self] in self?.onSingleClick?() }
            pendingClick = click
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: click)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        cancelPendingClick()
        onRightClick?(event)
    }

    deinit { pendingClick?.cancel() }
}

struct DesktopPetEventRepresentable: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void
    let onRightClick: (NSEvent) -> Void
    let onDragEnded: () -> Void
    let onHoverStateChanged: (Bool) -> Void
    var onDragBegan: () -> Void = {}
    var acceptsPoint: ((CGPoint, CGSize) -> Bool)? = nil
    var onPresentationChanged: (Bool) -> Void = { _ in }
    var accessibilityName = "桌面伴侣"

    func makeNSView(context: Context) -> DesktopPetEventView {
        let view = DesktopPetEventView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: DesktopPetEventView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
        nsView.onRightClick = onRightClick
        nsView.onDragEnded = onDragEnded
        nsView.onHoverStateChanged = onHoverStateChanged
        nsView.onDragBegan = onDragBegan
        nsView.acceptsPoint = acceptsPoint
        nsView.onPresentationChanged = onPresentationChanged
        nsView.setAccessibilityElement(true)
        nsView.setAccessibilityRole(.button)
        nsView.setAccessibilityLabel(accessibilityName)
        nsView.setAccessibilityHelp("单击开始或暂停，双击打开主面板，拖动移动，右键打开菜单")
    }

    static func dismantleNSView(_ view: DesktopPetEventView, coordinator: ()) {
        view.cancelPendingClick()
        view.onPresentationChanged?(false)
    }
}

// MARK: - Shared Status Capsule

/// Presentation rules for the status capsule shown under every pet, so the
/// compact Tomy view and the legacy sprite view speak the same language.
struct PetStatusModel: Equatable {
    enum Style: Equatable { case name, timer, paused, attention }
    enum Indicator: Equatable { case none, red, green, muted, orange }

    let style: Style
    let indicator: Indicator
    let text: String

    init(kind: PetKind, phase: FocusPhase, paused: Bool, timeLeft: String) {
        switch phase {
        case .workFinished:
            style = .attention
            indicator = .orange
            text = "🎉 达成"
        case .restFinished:
            style = .attention
            indicator = .orange
            text = "☕️ 结束"
        case .idle:
            style = .name
            indicator = .none
            text = kind.shortName
        case .work, .rest:
            if paused {
                style = .paused
                indicator = .muted
                text = "⏸ \(timeLeft)"
            } else {
                style = .timer
                indicator = phase == .work ? .red : .green
                text = timeLeft
            }
        }
    }
}

struct PetStatusPill: View {
    let model: PetStatusModel
    var compact = false

    var body: some View {
        if model.style == .name {
            Text(model.text)
                .font(.system(size: compact ? 9 : 10, weight: .medium))
                .foregroundColor(Garden.muted)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Garden.paper.opacity(0.85))
                        .overlay(Capsule().stroke(Garden.line.opacity(0.7), lineWidth: 0.6))
                )
        } else {
            HStack(spacing: 5) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 6, height: 6)

                Text(model.text)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Garden.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 3 : 4)
            .background(
                Capsule()
                    .fill(Garden.paper.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
                    .overlay(
                        Capsule().stroke(Garden.line, lineWidth: 0.8)
                    )
            )
        }
    }

    private var indicatorColor: Color {
        switch model.indicator {
        case .none: return Garden.muted
        case .red: return Garden.red
        case .green: return Color.green
        case .muted: return Garden.muted
        case .orange: return Color.orange
        }
    }
}

// MARK: - SwiftUI Desktop Pet View

struct DesktopPetView: View {
    @ObservedObject var timer: TBTimer
    @AppStorage("desktopPetKind") private var petKindRaw = PetKind.tomy.rawValue
    @AppStorage("desktopPetScale") private var petScale = 1.0
    @AppStorage("gentleAnimations") private var animations = true
    @AppStorage("showDesktopPet") private var showDesktopPet = true

    @State private var isHovered = false
    @State private var frameIndex = 0
    @State private var animTimer: Foundation.Timer?
    @State private var reduced: Bool
    @State private var presented = false
    @State private var dragging = false
    @State private var hop = false
    @State private var breathAnchor = Date()

    init(timer: TBTimer, reducedMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
        self.timer = timer
        _reduced = State(initialValue: reducedMotion)
    }

    private var canAnimate: Bool {
        PetAnimationPolicy.allowsAnimation(enabled: animations && showDesktopPet, reduced: reduced,
                                           presented: presented, dragging: dragging)
    }

    private var petKind: PetKind {
        PetKind(rawValue: petKindRaw) ?? .tomy
    }

    private var spriteWidth: CGFloat {
        110 * CGFloat(petScale)
    }

    private var spriteHeight: CGFloat {
        110 * CGFloat(petScale)
    }

    /// Shared drawing box for every legacy state. Content is scaled to fit and
    /// grounded on the bottom edge, so switching phase or pet never shifts the
    /// apparent size or the baseline.
    private var contentBox: CGSize {
        let side = 104 * CGFloat(petScale)
        return CGSize(width: side, height: side)
    }

    /// Chip and Clay are single-image pets; a slow breath keeps them alive
    /// without inventing fake frame sequences.
    private var breathingEnabled: Bool {
        canAnimate && (petKind == .chip || petKind == .clay)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Top Slot: Reserved height so pet stays stationary when tooltip appears
            ZStack(alignment: .bottom) {
                if isHovered {
                    hoverCard
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    Color.clear.frame(height: 28)
                }
            }
            .frame(height: 28)

            // Main Pet Sprite. Tomy uses deterministic sprite strips; legacy
            // pets use content-normalized frame assets.
            ZStack {
                animatedPetSprite
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .scaleEffect(hop ? 1.05 : 1.0, anchor: .bottom)
                    .offset(y: hop ? -4 : 0)

                // Native Dragging and Gesture Overlay
                DesktopPetEventRepresentable(
                    onSingleClick: {
                        timer.primaryAction()
                    },
                    onDoubleClick: {
                        TBStatusItem.shared?.showMainWindow()
                    },
                    onRightClick: { event in
                        showContextMenu(with: event)
                    },
                    onDragEnded: {
                        dragging = false
                        updateAnimationTimer()
                        DesktopPetController.shared?.saveCurrentPosition()
                    },
                    onHoverStateChanged: { hovering in
                        withAnimation(canAnimate ? .spring(response: 0.25, dampingFraction: 0.8) : nil) {
                            isHovered = hovering
                        }
                    },
                    onDragBegan: { dragging = true; updateAnimationTimer() },
                    onPresentationChanged: { value in presented = value; updateAnimationTimer() }
                )
                .frame(width: spriteWidth + 20, height: spriteHeight + 20)
            }

            // Bottom Status Capsule
            PetStatusPill(model: PetStatusModel(kind: petKind,
                                                phase: timer.state.phase,
                                                paused: timer.state.paused,
                                                timeLeft: timer.timeLeft))
                .padding(.bottom, 8)
        }
        .frame(width: 220 * CGFloat(petScale), height: 250 * CGFloat(petScale))
        .onAppear {
            // Presentation is owned by the controller, which knows whether the panel is
            // on screen and whether the Mac is awake; register() already reported it.
            // Re-asserting the `showDesktopPet` preference here would start animation
            // for a panel that is hidden or sleep-suspended.
            presented = DesktopPetController.shared?.isPresenting ?? false
            updateAnimationTimer()
        }
        .onDisappear {
            presented = false
            animTimer?.invalidate()
            animTimer = nil
        }
        .onChange(of: timer.state.needsAttention) { value in
            guard value, canAnimate else { return }
            withAnimation(.easeOut(duration: 0.18)) { hop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeInOut(duration: 0.28)) { hop = false }
            }
        }
        .onChange(of: timer.state.phase) { _ in
            updateAnimationTimer(resetFrame: true)
        }
        .onChange(of: timer.state.paused) { _ in
            updateAnimationTimer(resetFrame: true)
        }
        .onChange(of: animations) { _ in
            updateAnimationTimer()
        }
        .onChange(of: showDesktopPet) { _ in
            updateAnimationTimer()
        }
        .onChange(of: petKindRaw) { _ in
            updateAnimationTimer(resetFrame: true)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)) { _ in
            reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            updateAnimationTimer()
        }
    }

    // MARK: - Pet Sprite

    /// Chip and Clay have no authored frames, so a deterministic, time-based
    /// breath keeps them alive. TimelineView only exists while the panel is
    /// actually presented, animated and motion is allowed.
    @ViewBuilder
    private var animatedPetSprite: some View {
        if breathingEnabled {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                petSprite
                    .scaleEffect(breathScale(at: context.date), anchor: .bottom)
            }
        } else {
            petSprite
        }
    }

    /// Smooth 0…1 breath over a 4.2 s cycle, anchored to this view's lifetime so
    /// the first frame is at rest and reinsertion does not snap to a random phase.
    private func breathScale(at date: Date) -> CGFloat {
        let cycle = 4.2
        let phase = date.timeIntervalSince(breathAnchor).truncatingRemainder(dividingBy: cycle) / cycle
        let wave = 0.5 - 0.5 * cos(phase * 2 * .pi)
        return 1 + 0.014 * wave
    }

    @ViewBuilder
    private var petSprite: some View {
        if let strip = petKind.stripAnimation(for: timer.state.phase, paused: timer.state.paused) {
            if let asset = PetSpriteMetrics.shared.asset(named: strip.assetName,
                                                         frameCount: strip.frameCount) {
                PetSpriteStripView(asset: asset,
                                   frameCount: strip.frameCount,
                                   frameIndex: frameIndex,
                                   scale: spriteScale(for: asset),
                                   box: contentBox)
            } else {
                PetSpriteStripFallbackView(assetName: strip.assetName,
                                           frameCount: strip.frameCount,
                                           frameIndex: frameIndex,
                                           width: spriteWidth,
                                           height: spriteHeight)
            }
        } else {
            let frames = petKind.frameNames(for: timer.state.phase)
            let name = (frameIndex < frames.count)
                ? frames[frameIndex]
                : petKind.singleImageName(for: timer.state.phase)
            if let asset = PetSpriteMetrics.shared.asset(named: name, frameCount: 1) {
                PetSpriteStillView(asset: asset, scale: spriteScale(for: asset), box: contentBox)
            } else {
                Image(name)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: spriteWidth, height: spriteHeight)
            }
        }
    }

    private func spriteScale(for asset: PetSpriteAsset) -> CGFloat {
        let fit = PetSpriteFit.scale(cellSize: asset.cellSize, box: contentBox)
        switch PetSpriteFit.policy {
        case .eachState:
            return fit
        case .perPet:
            return PetSpriteMetrics.shared.contentScale(for: petKind, box: contentBox) ?? fit
        }
    }

    // MARK: - Animation Driver

    private func updateAnimationTimer(resetFrame: Bool = false) {
        animTimer?.invalidate()
        animTimer = nil
        if resetFrame { frameIndex = 0 }

        guard canAnimate else {
            return
        }

        if let strip = petKind.stripAnimation(for: timer.state.phase, paused: timer.state.paused) {
            if strip.loopMode == .onceHold && frameIndex >= strip.frameCount - 1 { return }
            scheduleStripFrame(strip)
            return
        }

        // Single-image phases (Chip, Clay) have nothing to cycle; do not keep a
        // timer alive just to re-draw the same asset.
        guard petKind.frameNames(for: timer.state.phase).count > 1 else { return }

        let interval: TimeInterval
        switch timer.state.phase {
        case .work:
            interval = timer.state.paused ? 1.0 : 0.12
        case .rest:
            interval = timer.state.paused ? 1.0 : 0.20
        case .workFinished, .restFinished:
            interval = 0.15
        case .idle:
            interval = 0.28
        }

        if !timer.state.paused {
            animTimer = Foundation.Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                let frames = petKind.frameNames(for: timer.state.phase)
                guard frames.count > 1 else { return }
                frameIndex = (frameIndex + 1) % frames.count
            }
        }
    }

    private func scheduleStripFrame(_ strip: PetStripAnimation) {
        let delay = strip.duration(at: frameIndex)
        animTimer = Foundation.Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            guard canAnimate,
                  let current = petKind.stripAnimation(for: timer.state.phase, paused: timer.state.paused),
                  current.assetName == strip.assetName else {
                updateAnimationTimer()
                return
            }

            switch current.loopMode {
            case .loop:
                frameIndex = (frameIndex + 1) % current.frameCount
                scheduleStripFrame(current)
            case .onceHold:
                guard frameIndex < current.frameCount - 1 else {
                    animTimer = nil
                    return
                }
                frameIndex += 1
                scheduleStripFrame(current)
            }
        }
    }

    // MARK: - Subviews

    private var hoverCard: some View {
        HStack(spacing: 6) {
            Text(petKind.displayName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Garden.ink)
            Spacer(minLength: 8)
            Text(phaseShortLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Garden.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Garden.paper.opacity(0.96))
                .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Garden.line, lineWidth: 0.8)
                )
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var phaseShortLabel: String {
        PetMotionState(phase: timer.state.phase, paused: timer.state.paused).label
    }

    // MARK: - Native Context Menu

    func showContextMenu(with event: NSEvent) {
        let menu = NSMenu()

        // Character Submenu
        let characterItem = NSMenuItem(title: "形象选择", action: nil, keyEquivalent: "")
        let characterMenu = NSMenu()
        for kind in PetKind.allCases {
            let item = NSMenuItem(title: kind.displayName, action: #selector(ContextMenuTarget.selectPetKind(_:)), keyEquivalent: "")
            item.target = ContextMenuTarget.shared
            item.representedObject = kind.rawValue
            if kind == petKind {
                item.state = .on
            }
            characterMenu.addItem(item)
        }
        characterItem.submenu = characterMenu
        menu.addItem(characterItem)

        // Scale Submenu
        let scaleItem = NSMenuItem(title: "尺寸缩放", action: nil, keyEquivalent: "")
        let scaleMenu = NSMenu()
        let scales: [(String, Double)] = petKind == .tomy
            ? [("小号 (64 点)", 0.8), ("标准 (80 点)", 1.0), ("大号 (96 点)", 1.2)]
            : [("小号 (80%)", 0.8), ("标准 (100%)", 1.0), ("大号 (125%)", 1.25)]
        let currentScale = petKind == .tomy ? CompactPetLayout.scale(petScale) : petScale
        for (title, value) in scales {
            let item = NSMenuItem(title: title, action: #selector(ContextMenuTarget.selectScale(_:)), keyEquivalent: "")
            item.target = ContextMenuTarget.shared
            item.representedObject = value
            if abs(currentScale - value) < 0.05 {
                item.state = .on
            }
            scaleMenu.addItem(item)
        }
        scaleItem.submenu = scaleMenu
        menu.addItem(scaleItem)

        menu.addItem(NSMenuItem.separator())

        // Focus Quick Control
        let timerActionTitle: String
        switch timer.state.phase {
        case .idle:
            timerActionTitle = "▶️ 开始专注 (\(timer.workIntervalLength) 分钟)"
        case .work:
            timerActionTitle = timer.state.paused ? "▶️ 继续专注 (\(timer.timeLeft))" : "⏸️ 暂停专注 (\(timer.timeLeft))"
        case .rest:
            timerActionTitle = timer.state.paused ? "▶️ 继续休息 (\(timer.timeLeft))" : "⏸️ 暂停休息 (\(timer.timeLeft))"
        case .workFinished:
            timerActionTitle = "🔔 确认完成"
        case .restFinished:
            timerActionTitle = "🔔 结束休息"
        }
        let actionItem = NSMenuItem(title: timerActionTitle, action: #selector(ContextMenuTarget.triggerTimerAction), keyEquivalent: "")
        actionItem.target = ContextMenuTarget.shared
        menu.addItem(actionItem)

        menu.addItem(NSMenuItem.separator())

        // Open Main Window
        let openItem = NSMenuItem(title: "📖 打开专注时光主面板", action: #selector(ContextMenuTarget.openMainWindow), keyEquivalent: "")
        openItem.target = ContextMenuTarget.shared
        menu.addItem(openItem)

        // Hide Pet
        let hideItem = NSMenuItem(title: "隐藏桌面伴侣", action: #selector(ContextMenuTarget.hidePet), keyEquivalent: "")
        hideItem.target = ContextMenuTarget.shared
        menu.addItem(hideItem)

        if let window = DesktopPetController.shared?.panel ?? NSApp.windows.first(where: { $0 is DesktopPetPanel }),
           let content = window.contentView {
            let location = content.convert(event.locationInWindow, from: nil)
            menu.popUp(positioning: nil, at: location, in: window.contentView)
        }
    }
}

// MARK: - Context Menu Target Helper

@objc final class ContextMenuTarget: NSObject {
    static let shared = ContextMenuTarget()

    @objc func selectPetKind(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: "desktopPetKind")
    }

    @objc func selectScale(_ sender: NSMenuItem) {
        guard let scale = sender.representedObject as? Double else { return }
        UserDefaults.standard.set(scale, forKey: "desktopPetScale")
        DesktopPetController.shared?.updatePanelSize()
    }

    @objc func triggerTimerAction() {
        DesktopPetController.shared?.timer?.primaryAction()
    }

    @objc func openMainWindow() {
        TBStatusItem.shared?.showMainWindow()
    }

    @objc func hidePet() {
        UserDefaults.standard.set(false, forKey: "showDesktopPet")
        DesktopPetController.shared?.updateVisibility()
    }
}

// MARK: - Native Panel & Window Management

final class DesktopPetPanel: NSPanel {
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

// MARK: - Controller

final class DesktopPetController: NSObject, NSWindowDelegate {
    static var shared: DesktopPetController?
    private(set) var panel: DesktopPetPanel?
    private(set) var tooltipPanel: DesktopPetPanel?
    weak var timer: TBTimer?
    private weak var eventView: DesktopPetEventView?
    private var pointerTimer: Foundation.Timer?
    private var globalPointerMonitor: Any?
    private var localPointerMonitor: Any?
    private var dragging = false
    private var menuOpen = false
    private var sleeping = false
    /// The same answer register() hands the SwiftUI view, exposed for the initial mount:
    /// a panel that is on screen while the Mac is awake is the only meaning of visible.
    var isPresenting: Bool { panel?.isVisible == true && !sleeping }
    private let originXKey = "desktopPetOriginX"
    private let originYKey = "desktopPetOriginY"
    private let showKey = "showDesktopPet"
    private let scaleKey = "desktopPetScale"
    private var compact: Bool { UserDefaults.standard.string(forKey: "desktopPetKind") == PetKind.tomy.rawValue }
    private var desiredSize: NSSize {
        let scale = UserDefaults.standard.double(forKey: scaleKey)
        if compact {
            let side = CompactPetLayout.slot * CompactPetLayout.scale(scale)
            // The compact pet now shares the status capsule with the legacy
            // pets, so the panel reserves a strip below the character.
            return NSSize(width: side, height: side + CompactPetLayout.statusArea)
        }
        let actual = scale.isFinite && scale > 0.5 ? scale : 1
        return NSSize(width: 220 * actual, height: 250 * actual)
    }

    init(timer: TBTimer) {
        self.timer = timer
        super.init()
        Self.shared = self
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep),
            name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    func setup() {
        if UserDefaults.standard.object(forKey: showKey) == nil {
            UserDefaults.standard.set(true, forKey: showKey)
        }
        if UserDefaults.standard.object(forKey: "desktopPetKind") == nil {
            UserDefaults.standard.set(PetKind.tomy.rawValue, forKey: "desktopPetKind")
        }
        if UserDefaults.standard.object(forKey: scaleKey) == nil {
            UserDefaults.standard.set(1.0, forKey: scaleKey)
        }
        updateVisibility()
    }

    func register(_ view: DesktopPetEventView) {
        eventView?.cancelPendingClick()
        eventView?.onPresentationChanged?(false)
        eventView = view
        view.onPresentationChanged?(isPresenting)
        refreshPointer()
    }

    @objc private func defaultsChanged() {
        DispatchQueue.main.async { [weak self] in self?.updateVisibility() }
    }
    @objc private func screenParametersChanged() { ensurePanelOnScreen(); positionTooltip() }
    @objc private func willSleep() {
        sleeping = true
        stopPointerMonitoring()
        eventView?.onPresentationChanged?(false)
        eventView?.cancelPendingClick()
        tooltipPanel?.orderOut(nil)
    }
    @objc private func didWake() { sleeping = false; updateVisibility() }

    func updateVisibility() {
        if UserDefaults.standard.bool(forKey: showKey) && !sleeping {
            if panel == nil { createPanel() }
            updatePanelSize()
            panel?.orderFront(nil)
            eventView?.onPresentationChanged?(true)
            if pointerTimer == nil {
                globalPointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
                    self?.refreshPointer()
                }
                localPointerMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
                    self?.refreshPointer()
                    return event
                }
                let monitor = Foundation.Timer(timeInterval: 1 / 12, repeats: true) { [weak self] _ in
                    self?.refreshPointer()
                }
                pointerTimer = monitor
                RunLoop.main.add(monitor, forMode: .common)
            }
            refreshPointer()
        } else {
            stopPointerMonitoring()
            eventView?.cancelPendingClick()
            eventView?.setHovered(false)
            eventView?.onPresentationChanged?(false)
            panel?.orderOut(nil)
            tooltipPanel?.orderOut(nil)
        }
    }

    private func createPanel() {
        guard let timer = timer else { return }
        let size = desiredSize
        let saved = loadSavedPosition()
        let panel = DesktopPetPanel(contentRect: NSRect(origin: saved == .zero ? defaultPosition(for: size) : saved, size: size))
        panel.title = "Tomy 桌面伴侣"
        self.panel = panel
        panel.contentViewController = NSHostingController(rootView: DesktopPetRootView(timer: timer))
        panel.delegate = self
        ensurePanelOnScreen()
    }

    func updatePanelSize() {
        guard let panel = panel else { return }
        let size = desiredSize
        if panel.frame.size != size {
            var frame = panel.frame
            frame.origin.x += (frame.width - size.width) / 2
            frame.size = size
            panel.setFrame(frame, display: true)
            ensurePanelOnScreen()
        }
        if !compact { tooltipPanel?.orderOut(nil) }
    }

    func setDragging(_ value: Bool) {
        dragging = value
        if value {
            panel?.ignoresMouseEvents = false
            tooltipPanel?.orderOut(nil)
        } else {
            ensurePanelOnScreen()
            refreshPointer()
        }
    }

    private func refreshPointer() {
        guard let panel = panel, panel.isVisible, !sleeping, !dragging, !menuOpen,
              let view = eventView else { return }
        let local = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let hit = view.accepts(view.convert(local, from: nil))
        // NSView.hitTest alone cannot pass an empty pixel through to another app.
        panel.ignoresMouseEvents = !hit
        view.setHovered(hit)
        if compact && hit { showTooltip() }
        else { tooltipPanel?.orderOut(nil) }
    }

    private func showTooltip() {
        if tooltipPanel == nil, let timer = timer {
            let bubble = DesktopPetPanel(contentRect: NSRect(x: 0, y: 0, width: 214, height: 34))
            bubble.ignoresMouseEvents = true
            bubble.contentViewController = NSHostingController(rootView: CompactPetTooltipView(timer: timer))
            tooltipPanel = bubble
        }
        positionTooltip()
        if tooltipPanel?.isVisible == false { tooltipPanel?.orderFront(nil) }
    }

    private func positionTooltip() {
        guard let panel = panel, let bubble = tooltipPanel, let screen = screen(for: panel.frame) else { return }
        let visible = screen.visibleFrame
        let y = panel.frame.maxY + 5 + bubble.frame.height <= visible.maxY
            ? panel.frame.maxY + 5 : panel.frame.minY - bubble.frame.height - 5
        let proposed = NSRect(x: panel.frame.midX - bubble.frame.width / 2, y: y,
                              width: bubble.frame.width, height: bubble.frame.height)
        bubble.setFrameOrigin(Self.clamped(proposed, to: visible).origin)
    }

    func showCompactContextMenu(with event: NSEvent) {
        guard let timer = timer else { return }
        menuOpen = true
        defer { menuOpen = false; refreshPointer() }
        tooltipPanel?.orderOut(nil)
        DesktopPetView(timer: timer).showContextMenu(with: event)
    }

    func saveCurrentPosition() {
        guard let panel = panel else { return }
        let x = Double(panel.frame.minX), y = Double(panel.frame.minY)
        if UserDefaults.standard.double(forKey: originXKey) != x { UserDefaults.standard.set(x, forKey: originXKey) }
        if UserDefaults.standard.double(forKey: originYKey) != y { UserDefaults.standard.set(y, forKey: originYKey) }
    }
    private func loadSavedPosition() -> NSPoint {
        let x = UserDefaults.standard.double(forKey: originXKey), y = UserDefaults.standard.double(forKey: originYKey)
        return x.isFinite && y.isFinite ? NSPoint(x: x, y: y) : .zero
    }
    private func defaultPosition(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 200, y: 200) }
        return NSPoint(x: screen.visibleFrame.maxX - size.width - 24, y: screen.visibleFrame.minY + 48)
    }
    private func screen(for frame: NSRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            let left = a.visibleFrame.intersection(frame), right = b.visibleFrame.intersection(frame)
            let la = left.isNull ? 0 : left.width * left.height
            let ra = right.isNull ? 0 : right.width * right.height
            return la < ra
        } ?? NSScreen.main
    }
    static func clamped(_ frame: NSRect, to visible: NSRect) -> NSRect {
        var result = frame
        result.origin.x = min(max(frame.minX, visible.minX + 4), max(visible.minX + 4, visible.maxX - frame.width - 4))
        result.origin.y = min(max(frame.minY, visible.minY + 4), max(visible.minY + 4, visible.maxY - frame.height - 4))
        return result
    }
    private func ensurePanelOnScreen() {
        guard let panel = panel, let screen = screen(for: panel.frame) else { return }
        let frame = Self.clamped(panel.frame, to: screen.visibleFrame)
        if frame.origin != panel.frame.origin { panel.setFrameOrigin(frame.origin); saveCurrentPosition() }
    }
    func windowDidMove(_ notification: Notification) { saveCurrentPosition(); positionTooltip() }

    func shutdown() {
        stopPointerMonitoring()
        eventView?.cancelPendingClick()
        eventView?.onPresentationChanged?(false)
        panel?.orderOut(nil); panel?.contentViewController = nil; panel = nil
        tooltipPanel?.orderOut(nil); tooltipPanel?.contentViewController = nil; tooltipPanel = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if Self.shared === self { Self.shared = nil }
    }
    private func stopPointerMonitoring() {
        pointerTimer?.invalidate(); pointerTimer = nil
        if let monitor = globalPointerMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localPointerMonitor { NSEvent.removeMonitor(monitor) }
        globalPointerMonitor = nil; localPointerMonitor = nil
    }
    deinit { stopPointerMonitoring() }
}
