import Foundation
import Combine

// Compile the real UI/bridge sources, but do not construct TBApp or launch windows.
// All IO is confined to a new child of QA13, never the live or existing QA sessions file.
let defaultQaRoot = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Containers/com.dilyar.TomatoBarPersonal.QA13/Data/Library/Application Support/TomatoBarPersonal")
let qaRoot: URL = {
    if let custom = ProcessInfo.processInfo.environment["TOMATOBAR_QA_ROOT"] {
        return URL(fileURLWithPath: custom)
    }
    do {
        try FileManager.default.createDirectory(at: defaultQaRoot, withIntermediateDirectories: true)
        let probe = defaultQaRoot.appendingPathComponent(".write_test_\(UUID().uuidString)")
        try Data("probe".utf8).write(to: probe)
        try FileManager.default.removeItem(at: probe)
        return defaultQaRoot
    } catch {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("TomatoBarPersonalQA13")
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        return tempRoot
    }
}()
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
check(timer.editRecord(id: a.id, name: a.name, tags: ["swift"], styleChanges: ["swift": "star"]) == nil, "actual bridge style edit succeeds")
check(timer.categorySymbol("SWIFT") == "star", "actual bridge resolves ASCII override")
check(historyEvents == 1, "style-only edit publishes history even with unchanged records")
check(timer.deleteRecord(id: a.id) == nil, "actual bridge deletes by UUID")
check(timer.state.records.map(\.id) == [b.id] && timer.history.records.map(\.id) == [b.id], "history and state commit together")
let disk = try store.load()
check(disk.records.map(\.id) == [b.id] && disk.rounds == 3, "persisted delete preserves rounds")
check(timer.deleteRecord(id: a.id) != nil && timer.state.records.map(\.id) == [b.id], "repeated delete cannot remove another record")
timer.startWork()
check(timer.state.phase == .work && timer.state.startedAt != nil, "bridge starts a real work session")
timer.cancel()
check(timer.state.phase == .idle && timer.state.records.map(\.id) == [b.id] && timer.state.rounds == 3,
      "bridge cancel leaves no record and keeps rounds")
let diskAfterCancel = try store.load()
check(diskAfterCancel.phase == .idle && diskAfterCancel.records.map(\.id) == [b.id] && diskAfterCancel.rounds == 3
    && diskAfterCancel.startedAt == nil && diskAfterCancel.segments.isEmpty, "cancelled session persists as clean idle")

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
check(failing.editRecord(id: a.id, name: "changed", tags: ["数学"], styleChanges: ["数学": "star"]) != nil,
      "actual bridge edit also returns write failure")
check(failing.state.records == initial.records && failing.state.categoryStyles.isEmpty, "failed edit preserves records and styles")

// P1 regression: the UI delta builder must keep removed keys with an explicit nil
// value; a bare `delta[key] = nil` on [Key: Value?] removes the key and the domain
// layer never learns the override should go away.
let delta = RecordEditor.styleDelta(initial: ["数学": "star", "阅读": "leaf"], current: ["阅读": "book"])
check(delta.keys.contains("数学") && delta["数学"] == .some(nil), "styleDelta keeps removals as explicit nil")
check(delta["阅读"] == "book" && delta.keys.count == 2, "styleDelta carries changes and nothing else")

// P3 regression: a completed-but-unsaved focus must not advance into rest.
let gateDir = scratch.appendingPathComponent("restgate")
let gateStore = FocusStore(url: gateDir.appendingPathComponent("sessions.json"))
var gate = FocusState()
gate.phase = .workFinished
gate.rounds = 1
gate.records = [record("复习")]
try gateStore.save(gate)
let gated = TBTimer(store: gateStore)
try FileManager.default.removeItem(at: gateDir)
try Data("QA13 rest gate".utf8).write(to: gateDir)
gated.pause()
check(gated.storageError != nil, "rest-gate probe reached the failed-save state")
gated.startRest()
check(gated.state.phase == .workFinished, "startRest blocked while the completion is unsaved")
try FileManager.default.removeItem(at: gateDir)
gated.retryStorage()
check(gated.storageError == nil, "retryStorage recovers once the disk is writable again")
gated.startRest()
check(gated.state.phase == .rest, "startRest proceeds after the record is on disk")
let gateOnDisk = try gateStore.load()
check(gateOnDisk.phase == .rest && gateOnDisk.records.count == 1, "rest advance persisted with the saved completion")

// P24 regression: a successful write must CLEAR the 30s failure backoff. Without the
// reset, the designed "≤5s of checkpoints lost on crash" guarantee silently degrades to
// ~30s right after the user recovers from a storage failure.
let backoffDir = scratch.appendingPathComponent("backoff")
let backoffStore = FocusStore(url: backoffDir.appendingPathComponent("sessions.json"))
var backoffSeed = FocusState()
backoffSeed.records = [record("复盘")]
try backoffStore.save(backoffSeed)
let recovering = TBTimer(store: backoffStore)
recovering.startWork()
check(recovering.state.phase == .work, "backoff probe started a work session")
try FileManager.default.removeItem(at: backoffDir)
try Data("QA13 backoff".utf8).write(to: backoffDir)
recovering.pause()
check(recovering.storageError != nil && recovering.lastFailedSave != .distantPast, "failed persist armed the 30s backoff")
try FileManager.default.removeItem(at: backoffDir)
recovering.retryStorage()
check(recovering.storageError == nil && recovering.lastFailedSave == .distantPast, "manual retry success clears the backoff")
try FileManager.default.removeItem(at: backoffDir)
try Data("QA13 backoff".utf8).write(to: backoffDir)
recovering.cancel()
check(recovering.storageError != nil && recovering.lastFailedSave != .distantPast, "second failure re-armed the backoff")
try FileManager.default.removeItem(at: backoffDir)
let backoffRecord = recovering.state.records[0]
check(recovering.editRecord(id: backoffRecord.id, name: "重命名", tags: backoffRecord.tags, expected: backoffRecord) == nil,
      "direct edit write succeeds once the disk is writable again")
check(recovering.lastFailedSave == .distantPast && recovering.storageError == nil, "editRecord success also clears the backoff")

// P25 regression: the cancel dialog may only open while the session is still .work.
// pause() ticks first, so clicking at the exact deadline completes instead — the bridge
// must refuse to raise a dialog whose 「放弃这段」 would be a silent no-op.
let freezeDir = scratch.appendingPathComponent("freeze")
let freezeStore = FocusStore(url: freezeDir.appendingPathComponent("sessions.json"))
var freezeSeed = FocusState()
freezeSeed.records = [record("复盘")]
try freezeStore.save(freezeSeed)
let freezable = TBTimer(store: freezeStore)
freezable.startWork()
check(freezable.freezeForCancel(), "cancel dialog opens for live work")
check(freezable.state.phase == .work && freezable.state.paused, "freeze pauses without leaving the work phase")
freezable.cancel()
check(!freezable.freezeForCancel(), "idle session refuses the dialog")
check(gated.state.phase == .rest && !gated.freezeForCancel() && !gated.state.paused,
      "rest session refuses the dialog without freezing the rest")

// P26 regression across the real bridge: the UI hands its open-time snapshot to
// editRecord; a stale one returns the conflict message and nothing moves on disk.
let staleDraft = freezable.state.records[0]
check(freezable.editRecord(id: staleDraft.id, name: "另一窗口改名", tags: staleDraft.tags, expected: staleDraft) == nil,
      "bridge accepts a fresh snapshot edit")
check(freezable.editRecord(id: staleDraft.id, name: "旧草稿覆盖", tags: staleDraft.tags, expected: staleDraft) != nil,
      "bridge refuses the stale draft with an error")
let p26Disk = try freezeStore.load()
check(p26Disk.records[0].name == "另一窗口改名", "a refused bridge edit never reaches the disk")

// Todo continuation regression: a task selected for one Pomodoro set survives the rest
// boundary, so ReminderView's plain `startWork()` still attributes the next round.
let todoChainDir = scratch.appendingPathComponent("todo-chain")
let todoChainStore = FocusStore(url: todoChainDir.appendingPathComponent("sessions.json"))
var todoChainSeed = FocusState()
let chainTodoID = todoChainSeed.addTodo(title: "阅读章节", at: now)!
todoChainSeed.phase = .restFinished
todoChainSeed.name = "阅读章节"
todoChainSeed.rounds = 1
todoChainSeed.seriesTodoID = chainTodoID
try todoChainStore.save(todoChainSeed)
let todoChain = TBTimer(store: todoChainStore)
todoChain.setEventName("阅读章节")
todoChain.startWork()
check(todoChain.state.phase == .work && todoChain.state.activeTodoID == chainTodoID &&
      todoChain.state.seriesTodoID == chainTodoID,
      "bridge next round inherits the persisted todo series")
todoChain.stop()
check(todoChain.state.records.first?.todoID == chainTodoID && todoChain.state.seriesTodoID == nil,
      "bridge records the continued todo and ending the set clears continuation")

// Editing the name after rest is an explicit manual switch and must drop the carried task
// before the next focus starts.
let manualDir = scratch.appendingPathComponent("todo-manual-switch")
let manualStore = FocusStore(url: manualDir.appendingPathComponent("sessions.json"))
var manualSeed = FocusState()
let manualTodoID = manualSeed.addTodo(title: "任务 A", at: now)!
manualSeed.phase = .restFinished
manualSeed.name = "任务 A"
manualSeed.rounds = 1
manualSeed.seriesTodoID = manualTodoID
try manualStore.save(manualSeed)
let manualTimer = TBTimer(store: manualStore)
manualTimer.setEventName("手动任务")
check(manualTimer.state.seriesTodoID == nil, "manual name edit clears carried todo context")
manualTimer.startWork()
check(manualTimer.state.phase == .work && manualTimer.state.activeTodoID == nil,
      "manual next round does not inherit the previous todo")
let manualDisk = try manualStore.load()
// Skip rest via bridge: transitions to restFinished, preserves rounds, writes to disk.
let skipDir = scratch.appendingPathComponent("bridge-skip-rest")
let skipStore = FocusStore(url: skipDir.appendingPathComponent("sessions.json"))
var skipSeed = FocusState()
skipSeed.phase = .rest
skipSeed.rounds = 2
try skipStore.save(skipSeed)
let skipTimer = TBTimer(store: skipStore)
skipTimer.skipRest()
check(skipTimer.state.phase == .restFinished && skipTimer.state.rounds == 2,
      "bridge skipRest transitions to restFinished and keeps round count")
let skipDisk = try skipStore.load()
check(skipDisk.phase == .restFinished && skipDisk.rounds == 2,
      "bridge skipRest persists clean restFinished state without clearing rounds")

// Sticky currentTodo and start tags via bridge:
let currentTodoDir = scratch.appendingPathComponent("bridge-current-todo")
let currentTodoStore = FocusStore(url: currentTodoDir.appendingPathComponent("sessions.json"))
var currentTodoSeed = FocusState()
let todoWithTagsID = currentTodoSeed.addTodo(title: "期末复习", tags: ["学习", "考试"], at: now)!
try currentTodoStore.save(currentTodoSeed)
let currentTimer = TBTimer(store: currentTodoStore)
currentTimer.selectCurrentTodo(todoWithTagsID)
check(currentTimer.eventName == "期末复习" && currentTimer.state.currentTodoID == todoWithTagsID,
      "bridge selectCurrentTodo auto-fills eventName and sets currentTodoID")
currentTimer.startWork()
check(currentTimer.state.activeTags == ["学习", "考试"] && currentTimer.state.activeTodoID == todoWithTagsID,
      "bridge startWork inherits current todo tags and task ID")
currentTimer.stop()
check(currentTimer.state.records.first?.tags == ["学习", "考试"] &&
      currentTimer.state.records.first?.todoID == todoWithTagsID &&
      currentTimer.state.currentTodoID == todoWithTagsID,
      "bridge records inherited tags and keeps sticky current task after set completion")

// Free focus with draft tags via bridge:
currentTimer.selectCurrentTodo(nil)
currentTimer.setEventName("自主研究")
currentTimer.setDraftTags(["研究", "技术"])
currentTimer.startWork()
check(currentTimer.state.activeTags == ["研究", "技术"] && currentTimer.state.activeTodoID == nil,
      "bridge free focus uses draft tags and no task ID")
currentTimer.stop()
check(currentTimer.state.records.first?.tags == ["研究", "技术"] &&
      currentTimer.state.records.first?.category == "研究",
      "bridge free focus records draft tags and correct category")

// Projects via bridge:
let projectBridgeDir = scratch.appendingPathComponent("bridge-project")
let projectBridgeStore = FocusStore(url: projectBridgeDir.appendingPathComponent("sessions.json"))
var projectBridgeSeed = FocusState()
try projectBridgeStore.save(projectBridgeSeed)
let projectTimer = TBTimer(store: projectBridgeStore)
projectTimer.addProject(name: "考研数学", tags: ["考研"])
check(projectTimer.state.projects.count == 1 &&
      projectTimer.state.projects.first?.name == "考研数学" &&
      projectTimer.state.projects.first?.tags == ["考研"],
      "bridge addProject persists project and tags to state")
let projID = projectTimer.state.projects.first!.id
projectTimer.updateProject(id: projID, name: "考研数学一", tags: ["考研", "数一"])
check(projectTimer.state.projects.first?.name == "考研数学一" &&
      projectTimer.state.projects.first?.tags == ["考研", "数一"],
      "bridge updateProject updates project name and tags")
projectTimer.addTodo("高数第一章", tags: ["数学"], projectID: projID)
check(projectTimer.state.todos.count == 1 &&
      projectTimer.state.todos.first?.projectID == projID &&
      projectTimer.state.todos.first?.tags == ["考研", "数一", "数学"],
      "bridge addTodo with projectID inherits and merges parent project tags")
let subID = projectTimer.state.todos.first!.id
projectTimer.selectCurrentTodo(subID)
projectTimer.startWork()
projectTimer.stop()
check(projectTimer.state.records.first?.projectID == projID &&
      projectTimer.state.records.first?.todoID == subID &&
      projectTimer.state.records.first?.tags == ["考研", "数一", "数学"],
      "bridge session on project subtask writes projectID, todoID and inherited tags to record")
projectTimer.deleteProject(id: projID)
check(projectTimer.state.projects.isEmpty && projectTimer.state.todos.first?.projectID == nil,
      "bridge deleteProject safely detaches subtasks into loose todos")

// Garden palette & symbol mapping checks:
check(Garden.palette.contains { $0.symbol == "gearshape" && $0.label == "齿轮" },
      "Garden.palette exposes gearshape with 齿轮 label")
check(Garden.symbol("机械") == "gearshape" && Garden.symbol("工程") == "gearshape",
      "Garden.symbol maps 机械 and 工程 to gearshape")

// Desktop Pet V7 Tomy deterministic animation assertions:
let tomyWork = PetKind.tomy.stripAnimation(for: .work, paused: false)
check(tomyWork != nil && tomyWork?.assetName == "pet_tomy_work_v2" && tomyWork?.frameCount == 10 && tomyWork?.durations.count == 10 && tomyWork?.loopMode == .loop,
      "Tomy work animation has 10 frames, 10 durations, loops")

let tomyIdle = PetKind.tomy.stripAnimation(for: .idle, paused: false)
check(tomyIdle != nil && tomyIdle?.assetName == "pet_tomy_idle_v2" && tomyIdle?.frameCount == 8 && tomyIdle?.durations.count == 8 && tomyIdle?.loopMode == .loop,
      "Tomy idle animation has 8 frames, 8 durations, loops")

let tomyRest = PetKind.tomy.stripAnimation(for: .rest, paused: false)
check(tomyRest != nil && tomyRest?.assetName == "pet_tomy_rest_v2" && tomyRest?.frameCount == 8 && tomyRest?.durations.count == 8 && tomyRest?.loopMode == .loop,
      "Tomy rest animation has 8 frames, 8 durations, loops")

let tomyWorkFinished = PetKind.tomy.stripAnimation(for: .workFinished, paused: false)
check(tomyWorkFinished != nil && tomyWorkFinished?.assetName == "pet_tomy_work_finished_v2" && tomyWorkFinished?.frameCount == 8 && tomyWorkFinished?.durations.count == 8 && tomyWorkFinished?.loopMode == .onceHold,
      "Tomy workFinished animation has 8 frames, 8 durations, onceHold (not loop)")

let tomyRestFinished = PetKind.tomy.stripAnimation(for: .restFinished, paused: false)
check(tomyRestFinished != nil && tomyRestFinished?.assetName == "pet_tomy_rest_finished_v2" && tomyRestFinished?.frameCount == 8 && tomyRestFinished?.durations.count == 8 && tomyRestFinished?.loopMode == .onceHold,
      "Tomy restFinished animation has 8 frames, 8 durations, onceHold (not loop)")

let tomyPausedWork = PetKind.tomy.stripAnimation(for: .work, paused: true)
let tomyPausedRest = PetKind.tomy.stripAnimation(for: .rest, paused: true)
check(tomyPausedWork != nil && tomyPausedWork?.assetName == "pet_tomy_paused_v2" && tomyPausedWork?.frameCount == 4 && tomyPausedWork?.durations.count == 4 && tomyPausedWork?.loopMode == .loop,
      "Tomy paused state has dedicated 4-frame animation strip and loops")
check(tomyPausedRest == tomyPausedWork,
      "Tomy paused animation is consistent across phases")

// Non-Tomy pets should not return strip animations
check(PetKind.chip.stripAnimation(for: .work, paused: false) == nil,
      "Chip uses frame sequence rather than sprite strip")
check(PetKind.sprout.stripAnimation(for: .work, paused: false) == nil,
      "Sprout uses frame sequence rather than sprite strip")
check(PetKind.clay.stripAnimation(for: .work, paused: false) == nil,
      "Clay uses frame sequence rather than sprite strip")

print("PASS: \(checks) actual TBTimer bridge checks; isolated QA13 IO, no UI interaction")
withExtendedLifetime(observation) {}
