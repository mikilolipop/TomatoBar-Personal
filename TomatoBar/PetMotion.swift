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

struct PetPose: Equatable {
    var eyes = 0
    var x = 0.0
    var y = 0.0
    var scaleX = 1.0
    var scaleY = 1.0
    var angle = 0.0

    static func blend(_ from: PetPose, _ to: PetPose, progress: Double) -> PetPose {
        let t = min(1, max(0, progress))
        let eased = t * t * (3 - 2 * t)
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * eased }
        return PetPose(eyes: Int(mix(Double(from.eyes), Double(to.eyes)).rounded()),
                       x: mix(from.x, to.x), y: mix(from.y, to.y),
                       scaleX: mix(from.scaleX, to.scaleX), scaleY: mix(from.scaleY, to.scaleY),
                       angle: mix(from.angle, to.angle))
    }
}

/// Monotonic time is supplied by the caller. No frame count or timer cadence changes
/// the pose, and hover/resizing never restarts a completion celebration.
struct PetMotionDriver {
    static let transitionDuration = 0.34
    static let completionDuration = 2.1
    private(set) var state: PetMotionState
    private(set) var enteredAt: Double
    private var hovered = false
    private var dragging = false
    private var enabled = true
    private var reduced = false
    private var releaseAt: Double?
    private var transitionAt: Double?
    private var transitionFrom = PetPose()

    init(state: PetMotionState = .idle, now: Double) {
        self.state = state
        self.enteredAt = now
    }

    mutating func configure(state: PetMotionState, hovered: Bool, dragging: Bool,
                            enabled: Bool, reduced: Bool, now: Double) {
        guard self.state != state || self.hovered != hovered || self.dragging != dragging ||
              self.enabled != enabled || self.reduced != reduced else { return }
        let previous = pose(at: now)
        if self.state != state { enteredAt = now }
        if self.dragging && !dragging { releaseAt = now }
        self.state = state
        self.hovered = hovered
        self.dragging = dragging
        self.enabled = enabled
        self.reduced = reduced
        transitionFrom = previous
        transitionAt = enabled && !reduced && !dragging ? now : nil
    }

    func pose(at now: Double) -> PetPose {
        let elapsed = max(0, now - enteredAt)
        let dynamic = enabled && !reduced && !dragging
        let breath = dynamic ? sin(elapsed * .pi * 2 / 4.7) : 0
        var result = PetPose()
        switch state {
        case .idle:
            result.eyes = dynamic ? Self.blink(at: elapsed, cycle: 10) : 0
            result.scaleX -= breath * 0.0025
            result.scaleY += breath * 0.005
            result.angle = dynamic ? sin(elapsed * .pi * 2 / 9.7) * 0.7 : 0
        case .work, .workPaused:
            result.angle = -2.2
            result.eyes = dynamic ? Self.blink(at: elapsed, cycle: state == .work ? 10 : 13) : 0
            if dynamic && state == .work {
                result.scaleY += breath * 0.003
                let nod = elapsed.truncatingRemainder(dividingBy: 6.4)
                if nod > 3.5 && nod < 4.4 {
                    result.angle -= sin((nod - 3.5) / 0.9 * .pi) * 0.9
                }
            }
        case .rest, .restPaused:
            result.eyes = 2
            result.angle = 5.5
            result.scaleX = 1.015
            result.scaleY = 0.97
            if dynamic && state == .rest {
                result.scaleY += sin(elapsed * .pi * 2 / 5.8) * 0.006
            }
        case .workFinished:
            if dynamic && elapsed > 0.25 && elapsed < 1.65 {
                let t = (elapsed - 0.25) / 1.4
                let lift = pow(sin(t * .pi), 2)
                result.y = -4 * lift
                result.scaleX += lift * 0.016
                result.scaleY += lift * 0.018
                result.angle = sin(t * .pi * 2) * 2.5
            }
        case .restFinished:
            if dynamic && elapsed > 0.15 && elapsed < 1.65 {
                let stretch = sin((elapsed - 0.15) / 1.5 * .pi)
                result.scaleX -= stretch * 0.014
                result.scaleY += stretch * 0.045
            }
        }
        if hovered && !dragging {
            if state == .rest || state == .restPaused { result.eyes = 1 }
            if dynamic { result.angle += 1.0 }
        }
        if dragging {
            result.eyes = 0
            result.angle = 0
            result.scaleX = 1
            result.scaleY = 1
        }
        if dynamic, let releaseAt = releaseAt {
            let t = (now - releaseAt) / 0.42
            if t >= 0 && t < 1 {
                let settle = sin(t * .pi) * (1 - t)
                result.scaleX += settle * 0.018
                result.scaleY -= settle * 0.015
            }
        }
        if let start = transitionAt {
            return .blend(transitionFrom, result,
                          progress: (now - start) / Self.transitionDuration)
        }
        return result
    }

    func requiresTicks(at now: Double) -> Bool {
        guard enabled && !reduced && !dragging else { return false }
        if let start = transitionAt, now - start < Self.transitionDuration { return true }
        if let release = releaseAt, now - release < 0.42 { return true }
        if state == .restPaused { return false }
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
