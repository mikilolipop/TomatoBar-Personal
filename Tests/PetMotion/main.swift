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
      idle.pose(at: 1.43).eyes == 1 && idle.pose(at: 1.5).eyes == 0, "approved idle blink remains intact")
check(idle.pose(at: 11.35).eyes == idle.pose(at: 1.35).eyes, "blink repeats on absolute elapsed time")
check(configured(.work).pose(at: 0.3).frame == 1 && configured(.work).pose(at: 0.4).frame == 2,
      "focus advances through alternating hand poses")
check(configured(.rest).pose(at: 1.6).frame == 2 && configured(.rest).pose(at: 2).frame == 3 &&
      configured(.rest).pose(at: 2.5).frame == 2 && configured(.rest).pose(at: 2.7).frame == 1,
      "mug raising and lowering reuse intermediate poses in reverse")
for (active, paused) in [(PetMotionState.work, PetMotionState.workPaused), (.rest, .restPaused)] {
    var driver = configured(active)
    let time = active == .work ? 0.4 : 2.0
    let before = driver.pose(at: time)
    driver.configure(state: paused, hovered: false, dragging: false, enabled: true, reduced: false, now: time)
    check(driver.pose(at: time).frame == before.frame && driver.pose(at: 600).frame == before.frame,
          "pause freezes the current authored frame: \(active)")
    check(!driver.requiresTicks(at: time + 1), "pause releases its frame timer: \(active)")
    driver.configure(state: active, hovered: false, dragging: false, enabled: true, reduced: false, now: 600)
    check(driver.pose(at: 600).frame == before.frame &&
          driver.pose(at: 600.3).frame == configured(active).pose(at: time + 0.3).frame,
          "resume preserves clip time rather than resetting: \(active)")
    driver.configure(state: active, hovered: true, dragging: false, enabled: true, reduced: false, now: 601)
    check(driver.pose(at: 601.5).frame == configured(active).pose(at: time + 1.5).frame,
          "hover does not restart the authored clip: \(active)")
}
var transition = configured(.work)
let previous = transition.pose(at: 0.4)
transition.configure(state: .rest, hovered: false, dragging: false, enabled: true, reduced: false, now: 0.4)
check(transition.pose(at: 0.4).sceneProgress == 0 && transition.pose(at: 0.4).previousFrame == previous.frame,
      "new phase begins from the exact previous full pose")
check(transition.pose(at: 0.57).sceneProgress > 0.49 && transition.pose(at: 0.75).sceneProgress == 1 &&
      transition.pose(at: 0.57).previousScene == .work, "full bodies crossfade on phase change")
for state in [PetMotionState.workFinished, .restFinished] {
    var finished = configured(state)
    check(finished.pose(at: 0.95) != finished.pose(at: 2.2), "completion has one brief response: \(state)")
    check(finished.pose(at: 2.2).frame == 0 && !finished.requiresTicks(at: 2.2),
          "completion settles on its seated pose and stops ticking: \(state)")
    finished.configure(state: state, hovered: true, dragging: false, enabled: true, reduced: false, now: 5)
    check(finished.enteredAt == 0 && finished.pose(at: 5.4) == finished.pose(at: 50) && !finished.requiresTicks(at: 5.4),
          "hover does not replay completion: \(state)")
}
for state in PetMotionState.allCases {
    let reduced = configured(state, reduced: true), disabled = configured(state, enabled: false)
    check(!reduced.requiresTicks(at: 4) && !disabled.requiresTicks(at: 4), "reduced/off stops ticking: \(state)")
    check(reduced.pose(at: 4) == reduced.pose(at: 400), "reduced motion stays still: \(state)")
    let regular = configured(state)
    var bounded = true
    for sample in 0..<1600 {
        let pose = regular.pose(at: Double(sample) / 60)
        bounded = bounded && (0...2).contains(pose.eyes) && (0...5).contains(pose.frame) &&
            [pose.x, pose.y, pose.scaleX, pose.scaleY, pose.angle].allSatisfy(\.isFinite) &&
            pose.x == 0 && pose.y >= -6.01 && pose.y <= 0 &&
            (0.98...1.02).contains(pose.scaleX) && (0.99...1.04).contains(pose.scaleY) && abs(pose.angle) <= 0.71
    }
    check(bounded, "all sampled poses stay within compact motion bounds: \(state)")
}
var drag = configured(.rest)
let draggedFrame = drag.pose(at: 2).frame
drag.configure(state: .rest, hovered: true, dragging: true, enabled: true, reduced: false, now: 2)
check(drag.pose(at: 10).frame == draggedFrame && !drag.requiresTicks(at: 10), "drag freezes the complete current pose")
drag.configure(state: .rest, hovered: false, dragging: false, enabled: true, reduced: false, now: 10)
check(drag.pose(at: 10).frame == draggedFrame && drag.pose(at: 10.5).frame == configured(.rest).pose(at: 2.5).frame,
      "release resumes the mug action without resetting")
var toggle = configured(.work)
let stoppedFrame = toggle.pose(at: 0.4).frame
toggle.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: true, now: 0.4)
check(toggle.pose(at: 100).frame == stoppedFrame && !toggle.requiresTicks(at: 100), "reduce motion freezes an active clip")
toggle.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: false, now: 100)
check(toggle.pose(at: 100).frame == stoppedFrame, "turning motion back on resumes the same frame")
var sparse = configured(.idle), dense = configured(.idle)
for time in stride(from: 0.0, to: 7.0, by: 1.0 / 24) { _ = dense.pose(at: time) }
sparse.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: false, now: 7)
dense.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: false, now: 7)
check(sparse.pose(at: 7.4) == dense.pose(at: 7.4), "frame cadence never changes timing or shape")
print("PASS \(checks) desktop pet motion checks")
