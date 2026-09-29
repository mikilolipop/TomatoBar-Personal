import Foundation
import Combine

// Compile the real UI/bridge sources, but do not construct TBApp or launch windows.
// All IO is confined to a new child of QA13, never the live or existing QA sessions file.
let qaRoot = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Containers/com.dilyar.TomatoBarPersonal.QA13/Data/Library/Application Support/TomatoBarPersonal")
let scratch = qaRoot.appendingPathComponent("review-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: scratch) }
let now = Date(timeIntervalSince1970: 1_800_000_000)
func record(_ tag: String) -> FocusRecord {
    FocusRecord(id: UUID(), name: "QA13 REVIEW", startedAt: now, endedAt: now.addingTimeInterval(60),
        plannedSeconds: 60, completed: true, segments: [FocusSegment(start: now, end: now.addingTimeInterval(60))], tags: [tag])
}
var checks = 0
func check(_ value: @autoclosure () -> Bool, _ name: String) {
    precondition(value(), name); checks += 1
}
let a = record("Swift"), b = record("阅读")
var initial = FocusState()
initial.records = [a, b]
initial.rounds = 3
let store = FocusStore(url: scratch.appendingPathComponent("success/sessions.json"))
try store.save(initial)
let timer = TBTimer(store: store)
var historyEvents = 0
let observation = timer.history.$records.dropFirst().sink { _ in historyEvents += 1 }
check(timer.editRecord(id: a.id, name: a.name, tags: ["swift"], styles: ["swift": "star"]) == nil, "actual bridge style edit succeeds")
check(timer.categorySymbol("SWIFT") == "star", "actual bridge resolves ASCII override")
check(historyEvents == 1, "style-only edit publishes history even with unchanged records")
check(timer.deleteRecord(id: a.id) == nil, "actual bridge deletes by UUID")
check(timer.state.records.map(\.id) == [b.id] && timer.history.records.map(\.id) == [b.id], "history and state commit together")
let disk = try store.load()
check(disk.records.map(\.id) == [b.id] && disk.rounds == 3, "persisted delete preserves rounds")
check(timer.deleteRecord(id: a.id) != nil && timer.state.records.map(\.id) == [b.id], "repeated delete cannot remove another record")

let failureParent = scratch.appendingPathComponent("failure")
let failingStore = FocusStore(url: failureParent.appendingPathComponent("sessions.json"))
try failingStore.save(initial)
let failing = TBTimer(store: failingStore)
// Turn ONLY this probe's own parent into a regular file to force createDirectory failure.
try FileManager.default.removeItem(at: failureParent)
try Data("QA13 write failure".utf8).write(to: failureParent)
check(failing.deleteRecord(id: a.id) != nil, "actual bridge returns write failure")
check(failing.state.records == initial.records && failing.history.records == initial.records, "failed delete preserves real bridge memory and history")
check(!failing.hasUnsavedChanges, "failed deletion does not invent an unsaved-change exit block")
check(failing.editRecord(id: a.id, name: "changed", tags: ["数学"], styles: ["数学": "star"]) != nil,
      "actual bridge edit also returns write failure")
check(failing.state.records == initial.records && failing.state.categoryStyles.isEmpty, "failed edit preserves records and styles")
print("PASS: \(checks) actual TBTimer bridge checks; isolated QA13 IO, no UI interaction")
withExtendedLifetime(observation) {}
