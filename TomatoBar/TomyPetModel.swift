import CoreGraphics
import Foundation

enum TomyAtlasRow: Int, CaseIterable, Equatable {
    case idle = 0
    case work = 1
    case paused = 2
    case rest = 3
    case celebrate = 4
    case wave = 5
    case drag = 6
    case sad = 7
    case react = 8

    static let columns = 8
    static let rows = 9
    static let cellWidth: Double = 96.0
    static let cellHeight: Double = 104.0
    /// Foot contact baseline inside the 96x104 cell, used as the squash/rebound anchor.
    static let feetBaselineRatio: Double = 93.0 / 104.0
    /// Top stem pivot ratio inside the 96x104 cell, used for drag pendulum tilt.
    static let stemPivotRatio: Double = 0.15

    var frameCount: Int { TomyAtlasRow.columns }

    var staticFrame: Int {
        switch self {
        case .celebrate: return 4
        case .wave, .sad: return 3
        case .idle, .work, .paused, .rest, .drag, .react: return 0
        }
    }
}

enum TomyGlanceDirection: Equatable {
    case left
    case right
    case upLeft
    case upRight

    var colIndex: Int {
        switch self {
        case .left: return 2
        case .right: return 3
        case .upLeft: return 4
        case .upRight: return 5
        }
    }

    /// Resolves cursor glance direction from AppKit screen coordinates (Y points upward).
    static func resolve(petCenter: CGPoint, mousePoint: CGPoint,
                        minRadius: CGFloat = 18, maxRadius: CGFloat = 175) -> TomyGlanceDirection? {
        let dx = mousePoint.x - petCenter.x
        let dy = mousePoint.y - petCenter.y
        let dist = hypot(dx, dy)
        guard dist >= minRadius, dist <= maxRadius else { return nil }
        let isUp = dy > 24
        if dx >= 0 {
            return isUp ? .upRight : .right
        } else {
            return isUp ? .upLeft : .left
        }
    }
}

enum TomyPetSize: Int, CaseIterable, Equatable {
    case small = 64
    case medium = 80
    case large = 96

    static func resolved(_ rawValue: Int) -> TomyPetSize {
        TomyPetSize(rawValue: rawValue) ?? .medium
    }

    var pointSize: CGSize {
        let w = CGFloat(rawValue)
        let h = (w * CGFloat(TomyAtlasRow.cellHeight / TomyAtlasRow.cellWidth)).rounded()
        return CGSize(width: w, height: h)
    }

    var menuTitle: String {
        switch self {
        case .small: return "小号 (64pt)"
        case .medium: return "标准 (80pt)"
        case .large: return "大号 (96pt)"
        }
    }

    var shortTitle: String { "\(rawValue)pt" }
}

enum TomyClickAction: Equatable {
    case wave
    case confirmAttention

    static func singleClick(for phase: FocusPhase) -> TomyClickAction {
        (phase == .workFinished || phase == .restFinished) ? .confirmAttention : .wave
    }
}

enum TomyGhostPolicy {
    static let ghostOpacity: Double = 0.28

    static func resolve(locked: Bool, optionPressed: Bool, hitOpaquePixel: Bool,
                        pointerInsideBounds: Bool) -> (ignoresMouseEvents: Bool, opacity: Double) {
        if locked && !optionPressed {
            return (ignoresMouseEvents: true, opacity: pointerInsideBounds ? ghostOpacity : 1.0)
        }
        return (ignoresMouseEvents: !hitOpaquePixel, opacity: 1.0)
    }
}

enum TomyPetPlacement {
    static let edgeMargin: CGFloat = 6
    static let bottomSnapThreshold: CGFloat = 14
    static let sideSnapThreshold: CGFloat = 10

    static func defaultOrigin(size: CGSize, visibleFrame: CGRect) -> CGPoint {
        let x = max(visibleFrame.minX + edgeMargin, visibleFrame.maxX - size.width - 20)
        let y = visibleFrame.minY
        return CGPoint(x: x, y: y)
    }

    static func clampAndSnap(origin: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGPoint {
        let minX = visibleFrame.minX + edgeMargin
        let maxX = max(minX, visibleFrame.maxX - size.width - edgeMargin)
        let minY = visibleFrame.minY
        let maxY = max(minY, visibleFrame.maxY - size.height - edgeMargin)

        var x = min(max(origin.x, minX), maxX)
        var y = min(max(origin.y, minY), maxY)

        if y - minY <= bottomSnapThreshold {
            y = minY
        }
        if x - minX <= sideSnapThreshold {
            x = minX
        } else if maxX - x <= sideSnapThreshold {
            x = maxX
        }
        return CGPoint(x: x.rounded(), y: y.rounded())
    }
}

struct TomyHoverHUDModel: Equatable {
    enum Tone: Equatable {
        case idle
        case work
        case paused
        case rest
        case attention
    }

    let tone: Tone
    let title: String
    let detail: String
    let badge: String?
    let progress: Double?

    init(phase: FocusPhase, paused: Bool, taskTitle: String, timeLeft: String,
         progress: Double? = nil, todayCompletedCount: Int = 0, workIntervalsInSet: Int = 4) {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortTask: String? = {
            guard !trimmed.isEmpty else { return nil }
            if trimmed.count <= 12 { return trimmed }
            return String(trimmed.prefix(11)) + "…"
        }()
        let groupSize = max(1, workIntervalsInSet)
        let milestoneBadge: String? = (todayCompletedCount > 0 && (phase == .workFinished || todayCompletedCount % groupSize == 0))
            ? "🍅×\(todayCompletedCount)" : nil

        switch phase {
        case .idle:
            tone = .idle
            title = shortTask ?? "准备开始"
            detail = "右键开启专注"
            badge = milestoneBadge
            self.progress = nil
        case .work:
            tone = paused ? .paused : .work
            title = paused ? "已暂停" : (shortTask ?? "正在专注")
            detail = timeLeft
            badge = nil
            self.progress = progress.map { min(max($0, 0), 1) }
        case .rest:
            tone = paused ? .paused : .rest
            title = paused ? "休息暂停" : "正在休息"
            detail = timeLeft
            badge = milestoneBadge
            self.progress = progress.map { min(max($0, 0), 1) }
        case .workFinished:
            tone = .attention
            title = "专注完成！"
            detail = "点我进入休息"
            badge = milestoneBadge
            self.progress = 1.0
        case .restFinished:
            tone = .attention
            title = "休息结束"
            detail = "点我开启下一轮"
            badge = milestoneBadge
            self.progress = 1.0
        }
    }
}

struct TomyRNG: Equatable {
    private var state: UInt64

    init(seed: UInt64 = 0x544F_4D59_2026_1118) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(nextUInt64() >> 11) * (1.0 / 9007199254740992.0)
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextUnit()
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        guard range.upperBound > range.lowerBound else { return range.lowerBound }
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(nextUInt64() % span)
    }
}

struct TomyPose: Equatable {
    var row: TomyAtlasRow
    var col: Int
    var scaleX: Double = 1.0
    var scaleY: Double = 1.0
    /// Upward visual offset in points used during post-drop gravity settle.
    var offsetY: Double = 0.0
    /// Pendulum rotation in degrees around the top stem pivot during dragging and post-drop settle.
    var tiltDegrees: Double = 0.0
}

struct TomyPetEngine {
    struct Step: Equatable {
        let row: TomyAtlasRow
        let col: Int
        let duration: TimeInterval
    }

    private enum Transient: Equatable {
        case none
        case wave
        case hoverPerk
        case sad
        case celebrateIntro
        case restWaveIntro
        case attentionWait(afterWork: Bool)
    }

    static let dropDuration: TimeInterval = 0.11
    static let squashDuration: TimeInterval = 0.13
    static var totalLandingDuration: TimeInterval { dropDuration + squashDuration }

    private var rng: TomyRNG
    private(set) var phase: FocusPhase = .idle
    private(set) var paused = false
    private(set) var isSprint = false
    private(set) var dragging = false
    private(set) var animationsEnabled = true
    private(set) var reducedMotion = false

    private var transient: Transient = .none
    private var steps: [Step] = []
    private var stepIndex = 0
    private var stepDeadline: TimeInterval = 0
    private var workBurstsSinceBlink = 0
    private var nextAmbientWaveAt: TimeInterval = 75
    private(set) var cursorGlance: TomyGlanceDirection?
    private var lastHoverPerkAt: TimeInterval?

    private var landingStart: TimeInterval?
    private var landingDropPt: Double = 0
    private var landingVisualLiftPt: Double = 0

    init(seed: UInt64 = 0x544F_4D59_2026_1118, now uptime: TimeInterval = 0) {
        self.rng = TomyRNG(seed: seed)
        self.nextAmbientWaveAt = uptime + self.rng.double(in: 55.0...105.0)
        rebuildBaseBatch(at: uptime)
    }

    var isLandingActive: Bool { landingStart != nil }

    var isPlayingTransient: Bool {
        switch transient {
        case .none: return false
        case .wave, .hoverPerk, .sad, .celebrateIntro, .restWaveIntro, .attentionWait: return true
        }
    }

    mutating func sync(phase nextPhase: FocusPhase, paused nextPaused: Bool,
                       timeLeftSeconds: TimeInterval? = nil,
                       animationsEnabled: Bool = true, reducedMotion: Bool = false,
                       at uptime: TimeInterval) {
        let prevPhase = phase
        let prevPaused = paused
        let prevAnim = self.animationsEnabled && !self.reducedMotion
        let nextAnim = animationsEnabled && !reducedMotion

        self.phase = nextPhase
        self.paused = nextPaused
        self.isSprint = (nextPhase == .work && !nextPaused && (timeLeftSeconds ?? 9999) <= 180)
        self.animationsEnabled = animationsEnabled
        self.reducedMotion = reducedMotion

        if nextPhase != .idle || nextPaused || !nextAnim {
            cursorGlance = nil
        }

        guard !dragging else { return }

        if prevPhase != nextPhase {
            switch nextPhase {
            case .workFinished:
                startTransient(.celebrateIntro, at: uptime)
                return
            case .restFinished:
                startTransient(.restWaveIntro, at: uptime)
                return
            case .idle, .work, .rest:
                if transient == .sad && nextPhase == .idle {
                    // Preserve explicit cancel-sad reaction (including when freezeForCancel paused work first).
                    return
                }
                transient = .none
                if nextPhase == .idle {
                    nextAmbientWaveAt = uptime + rng.double(in: 55.0...105.0)
                }
                rebuildBaseBatch(at: uptime)
                return
            }
        }

        if prevPaused != nextPaused || (!prevAnim && nextAnim) {
            if case .attentionWait = transient {} else if transient != .sad {
                transient = .none
            }
            rebuildBaseBatch(at: uptime)
        }
    }

    mutating func triggerWave(at uptime: TimeInterval) {
        guard !dragging, animationsEnabled, !reducedMotion else { return }
        startTransient(.wave, at: uptime)
    }

    mutating func setCursorGlance(_ direction: TomyGlanceDirection?, at uptime: TimeInterval) {
        cursorGlance = direction
    }

    mutating func triggerHoverPerk(at uptime: TimeInterval) {
        guard phase == .idle, !paused, !dragging,
              animationsEnabled, !reducedMotion,
              !isPlayingTransient else { return }
        if let last = lastHoverPerkAt, uptime - last < 12.0 {
            return
        }
        lastHoverPerkAt = uptime
        startTransient(.hoverPerk, at: uptime)
    }

    mutating func triggerCancelSad(at uptime: TimeInterval) {
        guard !dragging else { return }
        cursorGlance = nil
        if !animationsEnabled || reducedMotion {
            transient = .sad
            steps = [Step(row: .sad, col: TomyAtlasRow.sad.staticFrame, duration: 1.8)]
            stepIndex = 0
            stepDeadline = uptime + 1.8
            return
        }
        startTransient(.sad, at: uptime)
    }

    mutating func setDragging(_ value: Bool, dropDistancePt: Double = 0, at uptime: TimeInterval) {
        guard dragging != value else { return }
        dragging = value
        if value {
            cursorGlance = nil
            landingStart = nil
            landingDropPt = 0
            landingVisualLiftPt = 0
            if transient == .wave || transient == .hoverPerk || transient == .sad { transient = .none }
            steps = Self.dragSteps
            stepIndex = 0
            stepDeadline = uptime + steps[0].duration
        } else {
            if dropDistancePt > 4.0 && animationsEnabled && !reducedMotion {
                landingStart = uptime
                landingDropPt = min(dropDistancePt, 48.0)
                // Cap in-cell lift to 9pt so the top leaf stem never clips the panel ceiling.
                landingVisualLiftPt = min(dropDistancePt * 0.42, 9.0)
            } else {
                landingStart = nil
                landingDropPt = 0
                landingVisualLiftPt = 0
            }
            if phase == .workFinished {
                startTransient(.attentionWait(afterWork: true), at: uptime)
            } else if phase == .restFinished {
                startTransient(.attentionWait(afterWork: false), at: uptime)
            } else {
                transient = .none
                rebuildBaseBatch(at: uptime)
            }
        }
    }

    mutating func advance(to uptime: TimeInterval) -> TomyPose {
        if let start = landingStart, uptime - start >= Self.totalLandingDuration {
            landingStart = nil
            landingDropPt = 0
        }

        if !animationsEnabled || reducedMotion {
            let row = staticRowForCurrentState()
            return TomyPose(row: row, col: row.staticFrame)
        }

        if uptime - stepDeadline > 10.0 {
            onBatchCompleted(at: uptime)
            if steps.isEmpty { rebuildBaseBatch(at: uptime) }
            stepDeadline = uptime + steps[0].duration
        } else {
            var guardIterations = 0
            while uptime >= stepDeadline && guardIterations < 64 {
                guardIterations += 1
                let finishedAt = stepDeadline
                stepIndex += 1
                if stepIndex < steps.count {
                    stepDeadline = finishedAt + steps[stepIndex].duration
                } else {
                    onBatchCompleted(at: finishedAt)
                    if steps.isEmpty {
                        rebuildBaseBatch(at: uptime)
                        break
                    }
                }
            }
            if uptime >= stepDeadline {
                onBatchCompleted(at: uptime)
            }
        }

        let current = steps.isEmpty ? Step(row: .idle, col: 0, duration: 0.135) : steps[min(stepIndex, steps.count - 1)]
        var pose = TomyPose(row: current.row, col: current.col)
        applyLandingPhysics(to: &pose, at: uptime)
        if !dragging, !isPlayingTransient, phase == .idle, !paused,
           current.row == .idle, let glance = cursorGlance {
            pose.row = .react
            pose.col = glance.colIndex
            // Layer subtle breathing onto the held glance frame so Tomy never freezes rigidly while watching.
            let breathWave = sin(Double(current.col) * .pi / 4.0)
            pose.scaleX *= (1.0 - 0.007 * breathWave)
            pose.scaleY *= (1.0 + 0.011 * breathWave)
        }
        return pose
    }

    func nextWakeDelay(at uptime: TimeInterval, isVisible: Bool) -> TimeInterval? {
        guard isVisible, animationsEnabled, !reducedMotion else { return nil }
        if let start = landingStart, uptime - start < Self.totalLandingDuration {
            return 1.0 / 60.0
        }
        return max(0.02, stepDeadline - uptime)
    }

    // MARK: - Internal Schedule Builders

    private func staticRowForCurrentState() -> TomyAtlasRow {
        if dragging { return .drag }
        if transient == .sad { return .sad }
        if transient == .wave || transient == .hoverPerk { return .wave }
        if paused && (phase == .work || phase == .rest) { return .paused }
        switch phase {
        case .idle: return .idle
        case .work: return .work
        case .rest: return .rest
        case .workFinished: return .celebrate
        case .restFinished: return .wave
        }
    }

    private mutating func startTransient(_ mode: Transient, at uptime: TimeInterval) {
        transient = mode
        switch mode {
        case .none:
            rebuildBaseBatch(at: uptime)
            return
        case .wave:
            steps = Self.waveCycleSteps + Self.waveCycleSteps
        case .hoverPerk:
            steps = [
                Step(row: .react, col: 6, duration: 0.085),
                Step(row: .react, col: 7, duration: 0.135)
            ] + Self.waveCycleSteps
        case .sad:
            steps = [
                Step(row: .sad, col: 0, duration: 0.14),
                Step(row: .sad, col: 1, duration: 0.16),
                Step(row: .sad, col: 2, duration: 0.22),
                Step(row: .sad, col: 3, duration: 0.24),
                Step(row: .sad, col: 4, duration: 0.24),
                Step(row: .sad, col: 5, duration: 0.26),
                Step(row: .sad, col: 6, duration: 0.28),
                Step(row: .sad, col: 7, duration: 0.30)
            ]
        case .celebrateIntro:
            steps = Self.celebrateCycleSteps + Self.celebrateCycleSteps
        case .restWaveIntro:
            steps = Self.waveCycleSteps + Self.waveCycleSteps
        case .attentionWait(let afterWork):
            let breaths = afterWork ? 2 : 3
            var batch: [Step] = []
            for _ in 0..<breaths {
                batch.append(contentsOf: Self.idleCycleSteps)
            }
            batch.append(contentsOf: Self.waveCycleSteps)
            steps = batch
        }
        stepIndex = 0
        stepDeadline = uptime + steps[0].duration
    }

    private mutating func onBatchCompleted(at time: TimeInterval) {
        if dragging {
            steps = Self.dragSteps
            stepIndex = 0
            stepDeadline = time + steps[0].duration
            return
        }

        switch transient {
        case .wave, .hoverPerk, .sad:
            transient = .none
            if phase == .workFinished {
                startTransient(.attentionWait(afterWork: true), at: time)
            } else if phase == .restFinished {
                startTransient(.attentionWait(afterWork: false), at: time)
            } else {
                rebuildBaseBatch(at: time)
            }
        case .celebrateIntro:
            startTransient(.attentionWait(afterWork: true), at: time)
        case .restWaveIntro:
            startTransient(.attentionWait(afterWork: false), at: time)
        case .attentionWait(let afterWork):
            startTransient(.attentionWait(afterWork: afterWork), at: time)
        case .none:
            rebuildBaseBatch(at: time)
        }
    }

    private mutating func rebuildBaseBatch(at time: TimeInterval) {
        if dragging {
            steps = Self.dragSteps
        } else if paused && (phase == .work || phase == .rest) {
            steps = Self.pausedCycleSteps
        } else {
            switch phase {
            case .idle:
                if time >= nextAmbientWaveAt {
                    nextAmbientWaveAt = time + rng.double(in: 60.0...115.0)
                    steps = Self.waveCycleSteps
                } else {
                    let cycles = rng.int(in: 1...2)
                    var batch: [Step] = []
                    for _ in 0..<cycles {
                        batch.append(contentsOf: Self.idleCycleSteps)
                    }
                    // 3-stage soft natural blink right on the neutral cycle boundary
                    batch.append(contentsOf: Self.idleBlinkSteps)
                    if rng.nextUnit() < 0.18 {
                        batch.append(Step(row: .idle, col: 0, duration: 0.12))
                        batch.append(contentsOf: Self.idleBlinkSteps)
                    }
                    steps = batch
                }
            case .work:
                let bursts = rng.int(in: 1...2)
                let speedScale = isSprint ? 0.82 : 1.0
                var batch: [Step] = []
                for _ in 0..<bursts {
                    let jitter = rng.double(in: 0.94...1.08) * speedScale
                    for col in 0...5 {
                        batch.append(Step(row: .work, col: col, duration: 0.115 * jitter))
                    }
                }
                workBurstsSinceBlink += 1
                if workBurstsSinceBlink >= rng.int(in: 2...3) {
                    workBurstsSinceBlink = 0
                    batch.append(Step(row: .work, col: 0, duration: rng.double(in: 0.22...0.45) * speedScale))
                    batch.append(Step(row: .work, col: 6, duration: 0.045))
                    batch.append(Step(row: .work, col: 7, duration: 0.115))
                    batch.append(Step(row: .work, col: 6, duration: 0.045))
                    batch.append(Step(row: .work, col: 0, duration: rng.double(in: 0.25...0.55) * speedScale))
                } else {
                    batch.append(Step(row: .work, col: 0, duration: rng.double(in: 0.18...0.45) * speedScale))
                }
                steps = batch
            case .rest:
                let steamCycles = rng.int(in: 2...3)
                var batch: [Step] = []
                for _ in 0..<steamCycles {
                    for col in 0...3 {
                        batch.append(Step(row: .rest, col: col, duration: 0.25))
                    }
                }
                batch.append(Step(row: .rest, col: 4, duration: 0.16))
                batch.append(Step(row: .rest, col: 5, duration: 0.20))
                batch.append(Step(row: .rest, col: 6, duration: 0.42))
                batch.append(Step(row: .rest, col: 5, duration: 0.16))
                batch.append(Step(row: .rest, col: 7, duration: 0.22))
                steps = batch
            case .workFinished:
                startTransient(.attentionWait(afterWork: true), at: time)
                return
            case .restFinished:
                startTransient(.attentionWait(afterWork: false), at: time)
                return
            }
        }
        stepIndex = 0
        stepDeadline = time + steps[0].duration
    }

    private func applyLandingPhysics(to pose: inout TomyPose, at uptime: TimeInterval) {
        guard let start = landingStart else { return }
        let elapsed = uptime - start
        guard elapsed >= 0, elapsed < Self.totalLandingDuration else { return }

        if elapsed < Self.dropDuration {
            let t = elapsed / Self.dropDuration
            // Gravity quadratic fall: offsetY drops smoothly from landingVisualLiftPt -> 0.
            pose.offsetY = landingVisualLiftPt * (1.0 - t * t)
            let stretch = 0.03 * t
            pose.scaleX = 1.0 - stretch * 0.6
            pose.scaleY = 1.0 + stretch
        } else {
            let s = (elapsed - Self.dropDuration) / Self.squashDuration
            let amp = min(0.075, max(0.032, landingDropPt / 320.0))
            // Foot-anchored damped squash -> slight rebound -> settle to 1.0.
            let wave = sin(s * .pi * 1.5) * (1.0 - s)
            pose.offsetY = 0
            pose.scaleX = 1.0 + amp * wave
            pose.scaleY = 1.0 - amp * wave
        }
    }

    private static let idleCycleSteps: [Step] = (0..<8).map {
        Step(row: .idle, col: $0, duration: 0.135)
    }

    private static let idleBlinkSteps: [Step] = [
        Step(row: .react, col: 0, duration: 0.045),
        Step(row: .react, col: 1, duration: 0.11),
        Step(row: .react, col: 0, duration: 0.045)
    ]

    private static let pausedCycleSteps: [Step] = (0..<8).map {
        Step(row: .paused, col: $0, duration: 0.22)
    }

    private static let waveCycleSteps: [Step] = (0..<8).map {
        Step(row: .wave, col: $0, duration: 0.080)
    }

    private static let celebrateCycleSteps: [Step] = [
        Step(row: .celebrate, col: 0, duration: 0.085),
        Step(row: .celebrate, col: 1, duration: 0.085),
        Step(row: .celebrate, col: 2, duration: 0.095),
        Step(row: .celebrate, col: 3, duration: 0.115),
        Step(row: .celebrate, col: 4, duration: 0.115),
        Step(row: .celebrate, col: 5, duration: 0.090),
        Step(row: .celebrate, col: 6, duration: 0.095),
        Step(row: .celebrate, col: 7, duration: 0.110)
    ]

    private static let dragSteps: [Step] = (0..<8).map {
        Step(row: .drag, col: $0, duration: 0.085)
    }
}
