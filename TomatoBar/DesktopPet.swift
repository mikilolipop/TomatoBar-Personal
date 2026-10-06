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

private struct PetSpriteStripView: View {
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
        case .tomy: return "敲击键盘的番茄小极客，滴答沉浸在每一段心流"
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
                return ["pet_chip_work_0", "pet_chip_work_1", "pet_chip_work_2", "pet_chip_work_3"]
            case .rest:
                return ["pet_chip_rest", "pet_chip_rest", "pet_chip_rest", "pet_chip_rest"]
            case .workFinished, .restFinished:
                return ["pet_chip_work_3", "pet_chip_work_2", "pet_chip_work_1", "pet_chip_work_0"]
            case .idle:
                return ["pet_chip_idle", "pet_chip_idle", "pet_chip_idle", "pet_chip_idle"]
            }
        case .sprout:
            let single = singleImageName(for: phase)
            return [single, single, single, single]
        case .clay:
            let single = singleImageName(for: phase)
            return [single, single, single, single]
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
}

// MARK: - Native Mouse Event & Drag Handling

final class DesktopPetEventView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    var onDragEnded: (() -> Void)?
    var onHoverStateChanged: ((Bool) -> Void)?

    private var didDrag = false
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { false }

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
        onHoverStateChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverStateChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        didDrag = true
        window?.performDrag(with: event)
        onDragEnded?()
    }

    override func mouseUp(with event: NSEvent) {
        guard !didDrag else {
            didDrag = false
            return
        }
        if event.clickCount == 2 {
            onDoubleClick?()
        } else if event.clickCount == 1 {
            onSingleClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
}

struct DesktopPetEventRepresentable: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void
    let onRightClick: (NSEvent) -> Void
    let onDragEnded: () -> Void
    let onHoverStateChanged: (Bool) -> Void

    func makeNSView(context: Context) -> DesktopPetEventView {
        let view = DesktopPetEventView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        view.onRightClick = onRightClick
        view.onDragEnded = onDragEnded
        view.onHoverStateChanged = onHoverStateChanged
        return view
    }

    func updateNSView(_ nsView: DesktopPetEventView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
        nsView.onRightClick = onRightClick
        nsView.onDragEnded = onDragEnded
        nsView.onHoverStateChanged = onHoverStateChanged
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

    private var petKind: PetKind {
        PetKind(rawValue: petKindRaw) ?? .tomy
    }

    private var spriteWidth: CGFloat {
        110 * CGFloat(petScale)
    }

    private var spriteHeight: CGFloat {
        110 * CGFloat(petScale)
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

            // Main Pet Sprite. Tomy uses deterministic sprite strips; legacy pets keep frame assets.
            ZStack {
                if let strip = petKind.stripAnimation(for: timer.state.phase, paused: timer.state.paused) {
                    PetSpriteStripView(
                        assetName: strip.assetName,
                        frameCount: strip.frameCount,
                        frameIndex: frameIndex,
                        width: spriteWidth,
                        height: spriteHeight
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                } else {
                    let frames = petKind.frameNames(for: timer.state.phase)
                    let currentFrameName = (frameIndex < frames.count)
                        ? frames[frameIndex]
                        : petKind.singleImageName(for: timer.state.phase)

                    Image(currentFrameName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: spriteWidth, height: spriteHeight)
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                        .offset(y: microYOffset)
                        .scaleEffect(microScale)
                }

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
                        DesktopPetController.shared?.saveCurrentPosition()
                    },
                    onHoverStateChanged: { hovering in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isHovered = hovering
                        }
                    }
                )
                .frame(width: spriteWidth + 20, height: spriteHeight + 20)
            }

            // Bottom Status Capsule
            statusPill
                .padding(.bottom, 8)
        }
        .frame(width: 220 * CGFloat(petScale), height: 250 * CGFloat(petScale))
        .onAppear {
            updateAnimationTimer()
        }
        .onDisappear {
            animTimer?.invalidate()
            animTimer = nil
        }
        .onChange(of: timer.state.phase) { _ in
            updateAnimationTimer()
        }
        .onChange(of: timer.state.paused) { _ in
            updateAnimationTimer()
        }
        .onChange(of: animations) { _ in
            updateAnimationTimer()
        }
        .onChange(of: showDesktopPet) { isShowing in
            if !isShowing {
                animTimer?.invalidate()
                animTimer = nil
            } else {
                updateAnimationTimer()
            }
        }
        .onChange(of: petKindRaw) { _ in
            frameIndex = 0
            updateAnimationTimer()
        }
    }

    // MARK: - Animation Driver

    private func updateAnimationTimer() {
        animTimer?.invalidate()
        animTimer = nil
        frameIndex = 0

        guard animations, showDesktopPet else {
            return
        }

        if let strip = petKind.stripAnimation(for: timer.state.phase, paused: timer.state.paused) {
            scheduleStripFrame(strip)
            return
        }

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
            guard animations, showDesktopPet,
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

    private var microYOffset: CGFloat {
        guard animations else { return 0 }
        if petKind == .tomy || petKind == .sprout { return 0 }
        if timer.state.needsAttention {
            return (frameIndex % 2 == 1) ? -6 : 0
        }
        return 0
    }

    private var microScale: CGFloat {
        guard animations else { return 1.0 }
        if petKind == .tomy || petKind == .sprout { return 1.0 }
        if timer.state.needsAttention {
            return (frameIndex % 2 == 1) ? 1.06 : 1.0
        }
        return 1.0
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
        switch timer.state.phase {
        case .idle: return "准备中"
        case .work: return timer.state.paused ? "已暂停" : "专注中"
        case .rest: return timer.state.paused ? "已暂停" : "休息中"
        case .workFinished: return "专注达成"
        case .restFinished: return "休息结束"
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        if timer.state.phase != .idle || timer.state.needsAttention {
            HStack(spacing: 5) {
                Circle()
                    .fill(statusIndicatorColor)
                    .frame(width: 6, height: 6)

                Text(pillText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Garden.ink)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Garden.paper.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
                    .overlay(
                        Capsule().stroke(Garden.line, lineWidth: 0.8)
                    )
            )
        } else {
            // Idle character badge
            Text(petKind.shortName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Garden.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Garden.paper.opacity(0.85))
                        .overlay(Capsule().stroke(Garden.line.opacity(0.7), lineWidth: 0.6))
                )
        }
    }

    private var statusIndicatorColor: Color {
        if timer.state.needsAttention {
            return Color.orange
        }
        if timer.state.paused {
            return Garden.muted
        }
        switch timer.state.phase {
        case .work: return Garden.red
        case .rest: return Color.green
        default: return Garden.muted
        }
    }

    private var pillText: String {
        if timer.state.needsAttention {
            return timer.state.phase == .workFinished ? "🎉 达成" : "☕️ 结束"
        }
        if timer.state.paused {
            return "⏸ \(timer.timeLeft)"
        }
        return timer.timeLeft
    }

    // MARK: - Native Context Menu

    private func showContextMenu(with event: NSEvent) {
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
        let scales: [(String, Double)] = [("小号 (80%)", 0.8), ("标准 (100%)", 1.0), ("大号 (125%)", 1.25)]
        for (title, value) in scales {
            let item = NSMenuItem(title: title, action: #selector(ContextMenuTarget.selectScale(_:)), keyEquivalent: "")
            item.target = ContextMenuTarget.shared
            item.representedObject = value
            if abs(petScale - value) < 0.05 {
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

        if let window = NSApp.windows.first(where: { $0 is DesktopPetPanel }) {
            let location = event.locationInWindow
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
    weak var timer: TBTimer?

    private let originXKey = "desktopPetOriginX"
    private let originYKey = "desktopPetOriginY"
    private let showKey = "showDesktopPet"
    private let scaleKey = "desktopPetScale"

    init(timer: TBTimer) {
        self.timer = timer
        super.init()
        Self.shared = self
        setupNotifications()
    }

    func setup() {
        UserDefaults.standard.set(true, forKey: showKey)
        if UserDefaults.standard.object(forKey: "desktopPetKind") == nil {
            UserDefaults.standard.set(PetKind.tomy.rawValue, forKey: "desktopPetKind")
        }
        if UserDefaults.standard.object(forKey: scaleKey) == nil {
            UserDefaults.standard.set(1.0, forKey: scaleKey)
        }

        updateVisibility()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func defaultsChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateVisibility()
        }
    }

    @objc private func screenParametersChanged() {
        ensurePanelOnScreen()
    }

    func updateVisibility() {
        let isEnabled = UserDefaults.standard.bool(forKey: showKey)
        if isEnabled {
            if panel == nil {
                createPanel()
            }
            panel?.orderFront(nil)
        } else {
            panel?.orderOut(nil)
        }
    }

    private func createPanel() {
        guard let timer = timer else { return }

        let scale = UserDefaults.standard.double(forKey: scaleKey)
        let actualScale = scale > 0.5 ? scale : 1.0
        // Generous panel dimensions (220x250) completely eliminates clipping of bottom status pill!
        let panelSize = NSSize(width: 220 * actualScale, height: 250 * actualScale)

        var origin = loadSavedPosition()
        if origin == .zero {
            origin = defaultPosition(for: panelSize)
        }

        let panel = DesktopPetPanel(contentRect: NSRect(origin: origin, size: panelSize))
        let hosting = NSHostingController(rootView: DesktopPetView(timer: timer))
        panel.contentViewController = hosting
        panel.delegate = self
        self.panel = panel

        ensurePanelOnScreen()
    }

    func updatePanelSize() {
        guard let panel = panel else { return }
        let scale = UserDefaults.standard.double(forKey: scaleKey)
        let actualScale = scale > 0.5 ? scale : 1.0
        let newSize = NSSize(width: 220 * actualScale, height: 250 * actualScale)
        var frame = panel.frame
        frame.size = newSize
        panel.setFrame(frame, display: true)
        ensurePanelOnScreen()
    }

    func saveCurrentPosition() {
        guard let panel = panel else { return }
        UserDefaults.standard.set(Double(panel.frame.origin.x), forKey: originXKey)
        UserDefaults.standard.set(Double(panel.frame.origin.y), forKey: originYKey)
    }

    private func loadSavedPosition() -> NSPoint {
        let x = UserDefaults.standard.double(forKey: originXKey)
        let y = UserDefaults.standard.double(forKey: originYKey)
        guard x != 0 || y != 0 else { return .zero }
        return NSPoint(x: x, y: y)
    }

    private func defaultPosition(for size: NSSize) -> NSPoint {
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            return NSPoint(
                x: visible.maxX - size.width - 24,
                y: visible.minY + 48
            )
        }
        return NSPoint(x: 200, y: 200)
    }

    private func ensurePanelOnScreen() {
        guard let panel = panel else { return }
        let frame = panel.frame

        let screens = NSScreen.screens
        let isOnScreen = screens.contains { $0.visibleFrame.intersects(frame) }

        if !isOnScreen, NSScreen.main != nil {
            let defaultPos = defaultPosition(for: frame.size)
            panel.setFrameOrigin(defaultPos)
            saveCurrentPosition()
        }
    }

    // NSWindowDelegate
    func windowDidMove(_ notification: Notification) {
        saveCurrentPosition()
    }
}
