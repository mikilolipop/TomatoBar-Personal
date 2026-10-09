import Foundation

/// Presentation states preserve whether a pause happened during work or rest.
enum PetMotionState: CaseIterable, Equatable {
    case idle, work, rest, workPaused, restPaused, workFinished, restFinished

    init(phase: FocusPhase, paused: Bool) {
        switch phase {
        case .idle: self = .idle
        case .work: self = paused ? .workPaused : .work
        case .rest: self = paused ? .restPaused : .rest
        case .workFinished: self = .workFinished
        case .restFinished: self = .restFinished
        }
    }
    var clip: SeatedPetClip? {
        switch self {
        case .idle: return nil
        case .work, .workPaused, .workFinished: return .work
        case .rest, .restPaused, .restFinished: return .rest
        }
    }
    var playsClip: Bool { self == .work || self == .rest }
    var finishesOnce: Bool { self == .workFinished || self == .restFinished }
    var label: String {
        switch self {
        case .idle: return "准备中"
        case .work: return "专注中"
        case .rest: return "休息中"
        case .workPaused: return "专注暂停"
        case .restPaused: return "休息暂停"
        case .workFinished: return "专注达成"
        case .restFinished: return "休息结束"
        }
    }
}

/// Shared camera and authored timeline match tomy-seated-motion-v1.json.
/// The bridge checks compare these values with the independent browser player.
enum SeatedPetClip: String, CaseIterable {
    case work, rest
    struct Step: Codable, Equatable {
        let frame: Int
        let duration: Double
        init(_ frame: Int, _ duration: Double) { self.frame = frame; self.duration = duration }
    }
    var assetName: String { "pet_tomy_seated_\(rawValue)_v1" }
    var offsets: [[Double]] {
        self == .work ? [[0,0],[20,0],[40,0],[-4,30],[20,31],[39,31]] :
                        [[0,0],[32,0],[58,0],[-1,33],[29,33],[56,34]]
    }
    var bounds: [Double] { self == .work ? [61,73,495,495] : [88,73,498,497] }
    var timeline: [Step] {
        if self == .rest {
            return [Step(0,1.2),Step(1,0.24),Step(2,0.3),Step(3,0.7),Step(2,0.2),
                    Step(1,0.24),Step(4,0.3),Step(5,1)]
        }
        let typing = [Step(0,0.22),Step(1,0.14),Step(2,0.14),Step(1,0.14),Step(0,0.18),
                      Step(1,0.14),Step(2,0.14),Step(0,0.32)]
        return Array(repeating: typing, count: 4).flatMap { $0 } + [Step(3,0.07),Step(4,0.08),Step(5,0.12)]
    }
    var duration: Double { timeline.reduce(0) { $0 + $1.duration } }
    func frame(at elapsed: Double) -> Int {
        var time = max(0, elapsed).truncatingRemainder(dividingBy: duration)
        for step in timeline {
            if time < step.duration { return step.frame }
            time -= step.duration
        }
        return 0
    }
}

struct PetPose: Equatable {
    var eyes = 0
    var x = 0.0
    var y = 0.0
    var scaleX = 1.0
    var scaleY = 1.0
    var angle = 0.0
    var scene = PetMotionState.idle
    var frame = 0
    var previousScene = PetMotionState.idle
    var previousFrame = 0
    var previousEyes = 0
    var sceneProgress = 1.0

    static func blend(_ from: PetPose, _ to: PetPose, progress: Double) -> PetPose {
        let t = min(1, max(0, progress)), eased = t * t * (3 - 2 * t)
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * eased }
        return PetPose(eyes: Int(mix(Double(from.eyes), Double(to.eyes)).rounded()),
                       x: mix(from.x, to.x), y: mix(from.y, to.y),
                       scaleX: mix(from.scaleX, to.scaleX), scaleY: mix(from.scaleY, to.scaleY),
                       angle: mix(from.angle, to.angle))
    }
}

/// A monotonic clip clock freezes during pause/drag/reduced motion, and resumes
/// at the same authored frame. Hover and resizing never restart the clip.
struct PetMotionDriver {
    static let transitionDuration = 0.34
    static let completionDuration = 2.1
    private(set) var state: PetMotionState
    private(set) var enteredAt: Double
    private var hovered = false
    private var dragging = false
    private var enabled = true
    private var reduced = false
    private var clipTime = 0.0
    private var clipStartedAt: Double?
    private var releaseAt: Double?
    private var transitionAt: Double?
    private var transitionFrom = PetPose()
    private var sceneFrom = PetMotionState.idle
    private var frameFrom = 0
    private var eyesFrom = 0
    private var sceneTransitionAt: Double?

    init(state: PetMotionState = .idle, now: Double) {
        self.state = state
        self.enteredAt = now
        clipStartedAt = state.playsClip ? now : nil
    }
    private func elapsedClip(at now: Double) -> Double {
        clipTime + (clipStartedAt.map { max(0, now - $0) } ?? 0)
    }

    mutating func configure(state: PetMotionState, hovered: Bool, dragging: Bool,
                            enabled: Bool, reduced: Bool, now: Double) {
        guard self.state != state || self.hovered != hovered || self.dragging != dragging ||
              self.enabled != enabled || self.reduced != reduced else { return }
        let previous = pose(at: now)
        clipTime = elapsedClip(at: now)
        if self.state != state {
            if self.state.clip != state.clip {
                sceneFrom = previous.scene; frameFrom = previous.frame; eyesFrom = previous.eyes
                sceneTransitionAt = enabled && !reduced ? now : nil
                clipTime = 0
            }
            if state.finishesOnce { clipTime = 0 }
            enteredAt = now
        }
        if self.dragging && !dragging { releaseAt = now }
        self.state = state; self.hovered = hovered; self.dragging = dragging
        self.enabled = enabled; self.reduced = reduced
        clipStartedAt = state.playsClip && enabled && !reduced && !dragging ? now : nil
        transitionFrom = previous
        transitionAt = enabled && !reduced && !dragging ? now : nil
    }

    func pose(at now: Double) -> PetPose {
        let elapsed = max(0, now - enteredAt)
        let dynamic = enabled && !reduced && !dragging
        var result = PetPose()
        switch state {
        case .idle:
            let breath = dynamic ? sin(elapsed * .pi * 2 / 4.7) : 0
            result.eyes = dynamic ? Self.blink(at: elapsed, cycle: 10) : 0
            result.scaleX -= breath * 0.0025; result.scaleY += breath * 0.005
            result.angle = dynamic ? sin(elapsed * .pi * 2 / 9.7) * 0.7 : 0
        case .work, .rest, .workPaused, .restPaused: break
        case .workFinished:
            if dynamic && elapsed > 0.25 && elapsed < 1.65 {
                let lift = pow(sin((elapsed - 0.25) / 1.4 * .pi), 2)
                result.y = -6 * lift
                result.scaleX += lift * 0.012; result.scaleY += lift * 0.015
            }
        case .restFinished:
            if dynamic && elapsed > 0.15 && elapsed < 1.65 {
                let stretch = sin((elapsed - 0.15) / 1.5 * .pi)
                result.scaleX -= stretch * 0.015; result.scaleY += stretch * 0.03
            }
        }
        if hovered && dynamic && state == .idle { result.angle += 1 }
        if dynamic, let releaseAt = releaseAt {
            let t = (now - releaseAt) / 0.42
            if t >= 0 && t < 1 {
                let settle = sin(t * .pi) * (1 - t)
                result.scaleX += settle * 0.018; result.scaleY -= settle * 0.015
            }
        }
        if let start = transitionAt, dynamic {
            result = .blend(transitionFrom, result, progress: (now - start) / Self.transitionDuration)
        }
        result.scene = state
        result.frame = state.clip?.frame(at: elapsedClip(at: now)) ?? 0
        result.previousScene = sceneFrom; result.previousFrame = frameFrom; result.previousEyes = eyesFrom
        if dynamic, let start = sceneTransitionAt {
            let t = min(1, max(0, (now - start) / Self.transitionDuration))
            result.sceneProgress = t * t * (3 - 2 * t)
        }
        return result
    }

    func requiresTicks(at now: Double) -> Bool {
        guard enabled && !reduced && !dragging else { return false }
        if let start = transitionAt, now - start < Self.transitionDuration { return true }
        if let start = sceneTransitionAt, now - start < Self.transitionDuration { return true }
        if let release = releaseAt, now - release < 0.42 { return true }
        if state == .restPaused || state == .workPaused { return false }
        return !state.finishesOnce || now - enteredAt < Self.completionDuration
    }
    private static func blink(at elapsed: Double, cycle: Double) -> Int {
        let time = elapsed.truncatingRemainder(dividingBy: cycle)
        for start in [1.25, cycle * 0.555, cycle * 0.81] {
            let delta = time - start
            if delta >= 0 && delta < 0.08 { return 1 }
            if delta >= 0.08 && delta < 0.15 { return 2 }
            if delta >= 0.15 && delta < 0.23 { return 1 }
        }
        return 0
    }
}
