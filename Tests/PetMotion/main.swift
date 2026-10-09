import Foundation

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    precondition(condition(), name); checks += 1
}
func configured(_ state: PetMotionState, enabled: Bool = true, reduced: Bool = false) -> PetMotionDriver {
    var driver = PetMotionDriver(state: state, now: 0)
    driver.configure(state: state, hovered: false, dragging: false, enabled: enabled, reduced: reduced, now: 0)
    return driver
}
check(PetMotionState.allCases.count == 7, "all seven presentation states")
check(PetMotionState(phase: .work, paused: true) == .workPaused &&
      PetMotionState(phase: .rest, paused: true) == .restPaused, "pause preserves focus/rest context")
check(PetMotionState(phase: .workFinished, paused: true) == .workFinished &&
      PetMotionState(phase: .restFinished, paused: false) == .restFinished, "completion mapping")
let idle = configured(.idle)
check(idle.pose(at: 1.27).eyes == 1 && idle.pose(at: 1.35).eyes == 2 &&
      idle.pose(at: 1.43).eyes == 1 && idle.pose(at: 1.5).eyes == 0, "open-half-closed-half-open blink")
check(idle.pose(at: 11.35).eyes == idle.pose(at: 1.35).eyes, "blink repeats on absolute elapsed time")
check(configured(.rest).pose(at: 4).eyes == 2 && configured(.restPaused).pose(at: 4).eyes == 0,
      "rest sleeps on its pillow; rest pause wakes up")
check(configured(.workPaused).pose(at: 4).scaleY == 0.98 &&
      configured(.restPaused).pose(at: 1).scaleY == configured(.restPaused).pose(at: 4).scaleY,
      "pause stops breathing motion")
var transition = configured(.work)
let previous = transition.pose(at: 5)
transition.configure(state: .rest, hovered: false, dragging: false, enabled: true, reduced: false, now: 5)
let transitionStart = transition.pose(at: 5)
check(transitionStart.eyes == previous.eyes && transitionStart.x == previous.x &&
      transitionStart.y == previous.y && transitionStart.angle == previous.angle &&
      transitionStart.scaleX == previous.scaleX && transitionStart.scaleY == previous.scaleY,
      "phase transition starts exactly at the current body pose")
check(transition.pose(at: 5.17).eyes == 1 && transition.pose(at: 5.35).eyes == 2,
      "open-to-sleep transition passes through half-closed eyes")
check(transition.pose(at: 5.17).angle > previous.angle && transition.pose(at: 5.17).angle < 24,
      "reading-to-pillow turn passes through an intermediate orientation")
check(transition.pose(at: 5).sceneProgress == 0 && transition.pose(at: 5.17).sceneProgress > 0.49 &&
      transition.pose(at: 5.35).sceneProgress == 1 && transition.pose(at: 5.17).previousScene == .work,
      "scene props fade across the same continuous transition")
var finished = configured(.workFinished)
check(finished.pose(at: 0.95).y < -7.9, "one visible focus celebration")
check(finished.pose(at: 2.2).y == 0 && finished.pose(at: 2.2).scene == .workFinished && !finished.requiresTicks(at: 2.2),
      "celebration settles, retains its star scene and stops timer")
finished.configure(state: .workFinished, hovered: true, dragging: false, enabled: true, reduced: false, now: 5)
check(finished.enteredAt == 0 && finished.pose(at: 5.4).y == 0 && !finished.requiresTicks(at: 5.4),
      "hover does not replay a completed celebration")
finished.configure(state: .workFinished, hovered: true, dragging: false, enabled: true, reduced: false, now: 8)
check(finished.enteredAt == 0, "identical configuration does not reset state time")
let stretch = configured(.restFinished)
check(stretch.pose(at: 0.9).scaleY > 1.04 && stretch.pose(at: 2.2).scaleY == 0.98 &&
      stretch.pose(at: 2.2).scene == .restFinished, "rest finish stretches once and retains the wake-up scene")
check(configured(.work).pose(at: 3.9).pageTurn && !configured(.work).pose(at: 4.3).pageTurn &&
      !configured(.workPaused).pose(at: 3.9).pageTurn, "page turns only while reading")
check(!configured(.workPaused).requiresTicks(at: 4), "closed-book pause releases its frame timer")
for state in PetMotionState.allCases {
    let reduced = configured(state, reduced: true), disabled = configured(state, enabled: false)
    check(!reduced.requiresTicks(at: 4) && !disabled.requiresTicks(at: 4), "reduced/off stops ticking: \(state)")
    check(reduced.pose(at: 4) == reduced.pose(at: 400), "reduced motion stays still: \(state)")
    let regular = configured(state)
    var bounded = true
    for sample in 0..<1600 {
        let pose = regular.pose(at: Double(sample) / 60)
        bounded = bounded && (0...2).contains(pose.eyes) &&
            [pose.x, pose.y, pose.scaleX, pose.scaleY, pose.angle].allSatisfy(\.isFinite) &&
            abs(pose.x) <= 18 && pose.y >= -8.01 && pose.y <= 1 &&
            (0.83...1.06).contains(pose.scaleX) && (0.83...1.06).contains(pose.scaleY) && abs(pose.angle) <= 25
    }
    check(bounded, "all sampled poses stay within compact motion bounds: \(state)")
}
check(!configured(.restPaused).requiresTicks(at: 4), "still rest pause releases its frame timer")
var drag = configured(.rest)
drag.configure(state: .rest, hovered: true, dragging: true, enabled: true, reduced: false, now: 1)
check(drag.pose(at: 2).x == 0 && drag.pose(at: 2).angle == 0 && drag.pose(at: 2).eyes == 0 &&
      drag.pose(at: 2).scene == .rest && !drag.requiresTicks(at: 2), "drag stabilizes body while preserving scene context")
drag.configure(state: .rest, hovered: false, dragging: false, enabled: true, reduced: false, now: 2)
check(drag.pose(at: 2).angle == 0 && drag.pose(at: 2.5).eyes == 2, "release smoothly returns to its real state")
var sparse = configured(.idle), dense = configured(.idle)
for time in stride(from: 0.0, to: 7.0, by: 1.0 / 24) { _ = dense.pose(at: time) }
sparse.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: false, now: 7)
dense.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: false, now: 7)
check(sparse.pose(at: 7.17) == dense.pose(at: 7.17), "frame cadence never changes timing or shape")
print("PASS \(checks) desktop pet motion checks")
