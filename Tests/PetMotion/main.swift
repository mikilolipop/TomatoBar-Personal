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
check(configured(.rest).pose(at: 4).eyes == 2 && configured(.restPaused).pose(at: 4).eyes == 2,
      "rest and rest pause keep their sleeping silhouette")
check(configured(.workPaused).pose(at: 4).scaleY == 1 &&
      configured(.restPaused).pose(at: 1).scaleY == configured(.restPaused).pose(at: 4).scaleY,
      "pause stops breathing motion")
var transition = configured(.work)
let previous = transition.pose(at: 5)
transition.configure(state: .rest, hovered: false, dragging: false, enabled: true, reduced: false, now: 5)
check(transition.pose(at: 5) == previous, "phase transition starts exactly at the current pose")
check(transition.pose(at: 5.17).eyes == 1 && transition.pose(at: 5.35).eyes == 2,
      "open-to-sleep transition passes through half-closed eyes")
check(abs(transition.pose(at: 5.17).angle - previous.angle) < 5, "phase transition avoids orientation jumps")
var finished = configured(.workFinished)
check(finished.pose(at: 0.95).y < -3.9, "one gentle focus celebration")
check(finished.pose(at: 2.2) == PetPose() && !finished.requiresTicks(at: 2.2), "celebration settles and stops timer")
finished.configure(state: .workFinished, hovered: true, dragging: false, enabled: true, reduced: false, now: 5)
check(finished.enteredAt == 0 && finished.pose(at: 5.4).y == 0 && !finished.requiresTicks(at: 5.4),
      "hover does not replay a completed celebration")
finished.configure(state: .workFinished, hovered: true, dragging: false, enabled: true, reduced: false, now: 8)
check(finished.enteredAt == 0, "identical configuration does not reset state time")
let stretch = configured(.restFinished)
check(stretch.pose(at: 0.9).scaleY > 1.04 && stretch.pose(at: 2.2) == PetPose(), "rest finish stretches once and settles")
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
            abs(pose.x) < 5 && pose.y >= -4.01 && pose.y <= 1 &&
            (0.94...1.06).contains(pose.scaleX) && (0.94...1.06).contains(pose.scaleY) && abs(pose.angle) <= 6
    }
    check(bounded, "all sampled poses stay within compact motion bounds: \(state)")
}
check(!configured(.restPaused).requiresTicks(at: 4), "still rest pause releases its frame timer")
var drag = configured(.rest)
drag.configure(state: .rest, hovered: true, dragging: true, enabled: true, reduced: false, now: 1)
check(drag.pose(at: 2) == PetPose() && !drag.requiresTicks(at: 2), "drag keeps the character stable and eyes open")
drag.configure(state: .rest, hovered: false, dragging: false, enabled: true, reduced: false, now: 2)
check(drag.pose(at: 2) == PetPose() && drag.pose(at: 2.5).eyes == 2, "release smoothly returns to its real state")
var sparse = configured(.idle), dense = configured(.idle)
for time in stride(from: 0.0, to: 7.0, by: 1.0 / 24) { _ = dense.pose(at: time) }
sparse.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: false, now: 7)
dense.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: false, now: 7)
check(sparse.pose(at: 7.17) == dense.pose(at: 7.17), "frame cadence never changes timing or shape")
print("PASS \(checks) desktop pet motion checks")
