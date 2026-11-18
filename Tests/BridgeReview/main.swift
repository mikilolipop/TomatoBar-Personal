import Foundation
import AppKit
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
let observation = timer.history.objectWillChange.sink { historyEvents += 1 }
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

func drainRunLoop(_ seconds: TimeInterval) {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline { RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.01))) }
}

// Main-window summaries reuse a bounded snapshot, but edits with unchanged record
// count invalidate it. Task/style updates refresh the parent independently of ticks.
let snapshotStore = FocusStore(url: scratch.appendingPathComponent("snapshot/sessions.json"))
var snapshotSeed = FocusState()
let snapshotDate = Date()
let snapshotRecord = FocusRecord(id: UUID(), name: "QA SNAPSHOT", startedAt: snapshotDate,
    endedAt: snapshotDate.addingTimeInterval(60), plannedSeconds: 60, completed: true,
    segments: [FocusSegment(start: snapshotDate, end: snapshotDate.addingTimeInterval(60))], tags: ["Straße"])
snapshotSeed.records = [snapshotRecord]
try snapshotStore.save(snapshotSeed)
let snapshotTimer = TBTimer(store: snapshotStore)
let snapshots = snapshotTimer.history
check(Garden.symbol("Straße") == Garden.symbol("STRASSE"),
      "equivalent Unicode categories share the automatic chart symbol")
check(Garden.color("Straße") == Garden.color("STRASSE"),
      "equivalent Unicode categories share the automatic chart color")
_ = snapshots.summary(period: .day, date: snapshotDate)
_ = snapshots.summary(period: .day, date: snapshotDate)
check(snapshots.summaryBuildCount == 1, "repeated overview reads reuse one summary")
_ = snapshots.summary(period: .day, date: snapshotDate, category: "Straße")
_ = snapshots.summary(period: .day, date: snapshotDate, category: "STRASSE")
check(snapshots.summaryBuildCount == 2, "equivalent category filters reuse the selected summary")
check(snapshotTimer.editRecord(id: snapshotRecord.id, name: snapshotRecord.name, tags: ["数学"]) == nil,
      "snapshot fixture commits a same-count category edit")
check(snapshots.summary(period: .day, date: snapshotDate).categories.first?.name == "数学" && snapshots.summaryBuildCount == 3,
      "same-count edits invalidate cached category totals")
let buildsBeforeStyle = snapshots.summaryBuildCount
check(snapshotTimer.editRecord(id: snapshotRecord.id, name: snapshotRecord.name, tags: ["数学"], styleChanges: ["数学": "star"]) == nil,
      "snapshot fixture commits a style-only edit")
_ = snapshots.summary(period: .day, date: snapshotDate)
check(snapshots.summaryBuildCount == buildsBeforeStyle && snapshotTimer.categorySymbol("数学") == "star",
      "style-only edits keep valid totals while updating display styles")
var workspaceChanges = 0
let workspaceObservation = snapshots.objectWillChange.sink { workspaceChanges += 1 }
snapshotTimer.addProject(name: "QA PROJECT")
let snapshotProject = snapshotTimer.state.projects.last!.id
snapshotTimer.addTodo("QA TASK", projectID: snapshotProject)
let snapshotTask = snapshotTimer.state.todos.last!.id
snapshotTimer.selectCurrentTodo(snapshotTask)
check(workspaceChanges == 3 && snapshotTimer.eventName == "[QA PROJECT] · QA TASK",
      "project, task and selection mutations refresh the slow parent and format its title")
snapshotTimer.renameProject(id: snapshotProject, name: "QA RENAMED")
check(snapshotTimer.eventName == "[QA RENAMED] · QA TASK", "project rename refreshes the selected task title")
snapshotTimer.startWork()
workspaceChanges = 0
var clockChanges = 0
let clockObservation = snapshotTimer.objectWillChange.sink { clockChanges += 1 }
drainRunLoop(2.2)
check(clockChanges >= 2 && workspaceChanges == 0,
      "running seconds publish to the timer without invalidating main-window history/context")
snapshotTimer.cancel()
snapshotTimer.toggleTodo(id: snapshotTask)
check(snapshotTimer.state.currentTodoID == nil, "completing the selected task clears the unified current selection")
snapshotTimer.deleteTodo(id: snapshotTask)
check(snapshotTimer.state.todos.isEmpty, "deleting the task leaves no prepared-selection path")
withExtendedLifetime((workspaceObservation, clockObservation)) {}

// Renaming the carried task must not overwrite the event field once another task is the
// explicit current selection: the next round would otherwise record the selected task
// under the old task's new name.
let renameDir = scratch.appendingPathComponent("bridge-rename")
let renameStore = FocusStore(url: renameDir.appendingPathComponent("sessions.json"))
var renameSeed = FocusState()
let renameA = renameSeed.addTodo(title: "旧任务", at: now)!
let renameB = renameSeed.addTodo(title: "历史作业", at: now)!
renameSeed.currentTodoID = renameB
renameSeed.seriesTodoID = renameA
try renameStore.save(renameSeed)
let renameTimer = TBTimer(store: renameStore)
check(renameTimer.eventName == "历史作业", "init mirrors the selected task into the event field")
renameTimer.renameTodo(id: renameA, title: "旧任务改名")
check(renameTimer.state.currentTodoID == renameB && renameTimer.eventName == "历史作业",
      "renaming the carried task leaves the selected task's event field alone")
renameTimer.renameTodo(id: renameB, title: "历史作业改名")
check(renameTimer.eventName == "历史作业改名", "renaming the current task follows into the event field")

// The event field mirrors the display name (with project prefix), so echoing that value
// back must not be mistaken for a manual edit that drops the task selection.
let prefixDir = scratch.appendingPathComponent("bridge-prefix")
let prefixStore = FocusStore(url: prefixDir.appendingPathComponent("sessions.json"))
var prefixSeed = FocusState()
let prefixProject = prefixSeed.addProject(name: "QA PROJECT", at: now)!
let prefixTodo = prefixSeed.addTodo(title: "复习", projectID: prefixProject, at: now)!
try prefixStore.save(prefixSeed)
let prefixTimer = TBTimer(store: prefixStore)
prefixTimer.selectCurrentTodo(prefixTodo)
check(prefixTimer.eventName == "[QA PROJECT] · 复习", "selection fills the prefixed display name")
prefixTimer.setEventName("[QA PROJECT] · 复习")
check(prefixTimer.state.currentTodoID == prefixTodo, "echoing the prefixed name keeps the selection")
prefixTimer.updateProject(id: prefixProject, name: "QA RENAMED")
prefixTimer.setEventName("[QA RENAMED] · 复习")
check(prefixTimer.state.currentTodoID == prefixTodo, "a renamed project's prefixed name keeps the selection")
prefixTimer.setEventName("临时改名")
check(prefixTimer.state.currentTodoID == nil, "a genuinely manual name clears the selection")

// A successful reload must re-mirror the recovered selection: the field could otherwise
// still hold the name typed while the file was unreadable.
let reloadDir = scratch.appendingPathComponent("bridge-reload")
let reloadURL = reloadDir.appendingPathComponent("sessions.json")
let reloadStore = FocusStore(url: reloadURL)
var reloadSeed = FocusState()
let reloadTodo = reloadSeed.addTodo(title: "恢复任务", at: now)!
reloadSeed.currentTodoID = reloadTodo
try FileManager.default.createDirectory(at: reloadDir, withIntermediateDirectories: true)
try Data("broken".utf8).write(to: reloadURL)
let reloadTimer = TBTimer(store: reloadStore)
check(reloadTimer.storageError != nil, "reload probe starts from an unreadable file")
reloadTimer.setEventName("临时名字")
try reloadStore.save(reloadSeed)
reloadTimer.retryStorage()
check(reloadTimer.storageError == nil && reloadTimer.state.currentTodoID == reloadTodo,
      "retryStorage recovers the selection")
check(reloadTimer.eventName == "恢复任务", "a successful reload re-mirrors the recovered selection")

// Bounded summary cache: eviction must drop only filtered summaries, so the unfiltered
// one every panel reads stays cached across a category switch.
let evictStore = FocusStore(url: scratch.appendingPathComponent("evict/sessions.json"))
var evictSeed = FocusState()
let evictRecord = FocusRecord(id: UUID(), name: "QA EVICT", startedAt: now,
    endedAt: now.addingTimeInterval(60), plannedSeconds: 60, completed: true,
    segments: [FocusSegment(start: now, end: now.addingTimeInterval(60))], tags: ["Straße"])
evictSeed.records = [evictRecord]
try evictStore.save(evictSeed)
let evictTimer = TBTimer(store: evictStore)
let evictHistory = evictTimer.history
_ = evictHistory.summary(period: .day, date: now)
_ = evictHistory.summary(period: .day, date: now, category: "Straße")
let buildsBeforeSwitch = evictHistory.summaryBuildCount
_ = evictHistory.summary(period: .day, date: now, category: "STRASSE")
check(evictHistory.summaryBuildCount == buildsBeforeSwitch, "equivalent filters still reuse one summary")
_ = evictHistory.summary(period: .day, date: now, category: "数学")
check(evictHistory.summaryBuildCount == buildsBeforeSwitch + 1, "a new filter builds exactly one summary")
_ = evictHistory.summary(period: .day, date: now)
check(evictHistory.summaryBuildCount == buildsBeforeSwitch + 1,
      "switching filtered categories never evicts the unfiltered summary")

// Row controls read the coarse session state from history (P5 layering: the parent stays
// on history only), so phase transitions must publish there while plain ticks must not.
let sessionStore = FocusStore(url: scratch.appendingPathComponent("session/sessions.json"))
try sessionStore.save(FocusState())
let sessionTimer = TBTimer(store: sessionStore)
check(!sessionTimer.history.session.isTiming && !sessionTimer.history.session.needsAttention,
      "history session starts idle")
sessionTimer.startWork()
check(sessionTimer.history.session.isTiming && sessionTimer.history.session.storageError == nil,
      "starting work publishes the running session to history")
let sessionHistory = sessionTimer.history
let changesWhileStarting = sessionHistory.summaryBuildCount
sessionTimer.stop()
check(!sessionHistory.session.isTiming && sessionHistory.summaryBuildCount == changesWhileStarting,
      "stopping work publishes the idle session without touching summaries")

let calendarHistory = FocusHistory()
var calendarChanges = 0
let calendarObservation = calendarHistory.objectWillChange.sink { calendarChanges += 1 }
var reviewCalendar = Calendar(identifier: .gregorian)
reviewCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
calendarHistory.updateCalendar(at: now, calendar: reviewCalendar)
calendarChanges = 0
calendarHistory.updateCalendar(at: now.addingTimeInterval(1), calendar: reviewCalendar)
check(calendarChanges == 0, "same-day seconds do not refresh the statistics parent")
calendarHistory.updateCalendar(at: now.addingTimeInterval(86_400), calendar: reviewCalendar)
check(calendarChanges == 1, "day rollover refreshes date headings even with unchanged records")
reviewCalendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
calendarHistory.updateCalendar(at: now.addingTimeInterval(86_400), calendar: reviewCalendar)
check(calendarChanges == 2, "calendar/time-zone changes refresh the parent independently of records")
withExtendedLifetime(calendarObservation) {}

// Status bar title stability & trailing-anchor geometry checks:
let savedShowTimer = UserDefaults.standard.object(forKey: "showTimerInMenuBar")
let savedWorkLen = UserDefaults.standard.object(forKey: "workIntervalLength")
defer {
    if let v = savedShowTimer { UserDefaults.standard.set(v, forKey: "showTimerInMenuBar") }
    else { UserDefaults.standard.removeObject(forKey: "showTimerInMenuBar") }
    if let v = savedWorkLen { UserDefaults.standard.set(v, forKey: "workIntervalLength") }
    else { UserDefaults.standard.removeObject(forKey: "workIntervalLength") }
}
let statusDir = scratch.appendingPathComponent("status-title")
let statusStore = FocusStore(url: statusDir.appendingPathComponent("sessions.json"))
try statusStore.save(FocusState())
let statusTimer = TBTimer(store: statusStore)
statusTimer.showTimerInMenuBar = true
statusTimer.workIntervalLength = 25
check(statusTimer.statusTitle == nil && !statusTimer.isStatusPaused, "idle status item has no title and is not paused")
statusTimer.startWork()
let runningTitle = statusTimer.statusTitle
check(runningTitle == statusTimer.timeLeft && !(runningTitle?.contains("Ⅱ") ?? true) && !statusTimer.isStatusPaused,
      "running status title omits pause prefix")
statusTimer.pause()
let pausedTitle = statusTimer.statusTitle
check(pausedTitle == runningTitle && !(pausedTitle?.contains("Ⅱ") ?? true) && statusTimer.isStatusPaused,
      "paused status title keeps identical text without Ⅱ prefix while marking paused")
statusTimer.showTimerInMenuBar = false
check(statusTimer.statusTitle == nil && statusTimer.isStatusPaused,
      "hiding menu bar timer clears title while preserving paused state for icon feedback")
statusTimer.togglePause()
check(statusTimer.statusTitle == nil && !statusTimer.isStatusPaused, "resuming clears paused state even when timer text is hidden")
statusTimer.stop()

var attentionSeed = FocusState()
attentionSeed.phase = .workFinished
try statusStore.save(attentionSeed)
let attentionTimer = TBTimer(store: statusStore)
attentionTimer.showTimerInMenuBar = false
check(attentionTimer.statusTitle == "请确认" && !attentionTimer.isStatusPaused,
      "attention state always shows 请确认 even when timer text is hidden")

check(TBStatusItem.trailingAnchorRect(for: NSRect(x: 0, y: 0, width: 32, height: 22)) == NSRect(x: 0, y: 0, width: 32, height: 22),
      "idle bounds anchor to full 32pt width")
check(TBStatusItem.trailingAnchorRect(for: NSRect(x: 0, y: 0, width: 78, height: 22)) == NSRect(x: 46, y: 0, width: 32, height: 22),
      "running bounds anchor to trailing 32pt region")
check(TBStatusItem.trailingAnchorRect(for: NSRect(x: 0, y: 0, width: 86, height: 22)) == NSRect(x: 54, y: 0, width: 32, height: 22),
      "three-digit timer bounds anchor to trailing 32pt region")
check(TBStatusItem.trailingAnchorRect(for: NSRect(x: 0, y: 0, width: 18, height: 22)) == NSRect(x: 0, y: 0, width: 18, height: 22),
      "narrow bounds clamp trailing anchor width cleanly")

let emptyAttr = TBStatusItem.titleAttributedString(title: nil)
check(emptyAttr.string.isEmpty, "nil status title produces empty attributed string")
let activeAttr = TBStatusItem.titleAttributedString(title: "25:00")
let zeroAttr = TBStatusItem.titleAttributedString(title: "00:00")
let maxTwoDigitAttr = TBStatusItem.titleAttributedString(title: "99:59")
let maxThreeDigitAttr = TBStatusItem.titleAttributedString(title: "180:00")
let attentionAttr = TBStatusItem.titleAttributedString(title: "请确认")
check(activeAttr.string == " 25:00" && zeroAttr.string == " 00:00" && maxThreeDigitAttr.string == " 180:00",
      "attributed title keeps expected leading space and digits")
check(abs(activeAttr.size().width - zeroAttr.size().width) < 0.001 &&
      abs(activeAttr.size().width - maxTwoDigitAttr.size().width) < 0.001,
      "monospaced digit title width stays constant across running, paused, and digit ticks")
check(maxThreeDigitAttr.size().width > activeAttr.size().width && attentionAttr.size().width > 0,
      "three-digit timer and attention titles measure cleanly")
let titleColor = activeAttr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
check(titleColor == NSColor.labelColor,
      "status title preserves dynamic NSColor.labelColor for menu-bar vibrancy")
var darkLuma: CGFloat = 0
var lightLuma: CGFloat = 1
NSAppearance(named: .vibrantDark)?.performAsCurrentDrawingAppearance {
    darkLuma = titleColor?.usingColorSpace(.sRGB)?.redComponent ?? 0
}
NSAppearance(named: .vibrantLight)?.performAsCurrentDrawingAppearance {
    lightLuma = titleColor?.usingColorSpace(.sRGB)?.redComponent ?? 1
}
check(darkLuma > 0.8 && lightLuma < 0.2,
      "status title color adapts dynamically between VibrantDark and VibrantLight")
check(abs(TBStatusItem.pausedButtonAlpha - 0.45) < 0.001,
      "paused state uses 0.45 button alpha without breaking template vibrancy")

statusTimer.workIntervalLength = 180
statusTimer.showTimerInMenuBar = true
statusTimer.startWork()
check(statusTimer.statusTitle == "180:00" && !statusTimer.isStatusPaused,
      "180-minute work interval formats cleanly in menu bar title")
statusTimer.cancel()

let headlessStatusItem = TBStatusItem()
headlessStatusItem.setStatus(icon: .asset(.idle), title: nil, paused: false, phaseLabel: "准备开始")
headlessStatusItem.setStatus(icon: .emoji("🚬"), title: "05:00", paused: true, phaseLabel: "休息已暂停")
headlessStatusItem.setStatus(icon: .emoji("🚬"), title: "05:00", paused: true, phaseLabel: "休息已暂停")
headlessStatusItem.showPopover(nil)
headlessStatusItem.closePopover(nil)
check(TBStatusItem.StatusIcon.asset(.work) != TBStatusItem.StatusIcon.emoji("🚬"),
      "TBStatusItem.StatusIcon distinguishes asset and emoji representations")
let headlessButton = NSStatusBarButton()
check(TBStatusItem.trailingAnchorScreenRect(for: headlessButton) == nil,
      "trailingAnchorScreenRect returns nil before the status button has a window")

// Tomy Desktop Pet native Retina atlas, O(1) hit-mask orientation, drawing & cancel-hook bridge checks
do {
    let atlas = TomySpriteAtlas.shared
    check(atlas.isLoaded && atlas.cellPixelWidth == 192 && atlas.cellPixelHeight == 208,
          "TomySpriteAtlas loads native @2x 192x208 Retina cells")
    for row in TomyAtlasRow.allCases {
        for col in 0..<row.frameCount {
            check(atlas.cellImage(row: row, col: col) != nil,
                  "TomySpriteAtlas crops non-nil CGImage for \(row) frame \(col)")
        }
    }

    let box = CGSize(width: 80, height: 87)
    let idlePose = TomyPose(row: .idle, col: 0)
    check(atlas.contains(point: CGPoint(x: 40, y: 50), in: box, pose: idlePose),
          "opaque torso center hits Tomy hit-mask")
    check(!atlas.contains(point: CGPoint(x: 3, y: 3), in: box, pose: idlePose) &&
          !atlas.contains(point: CGPoint(x: 77, y: 3), in: box, pose: idlePose) &&
          !atlas.contains(point: CGPoint(x: 3, y: 84), in: box, pose: idlePose),
          "transparent corners inside 80x87 panel pass mouse events through")
    // Orientation proof: grounded idle hits near feet (y=74), whereas apex celebrate col=4 clears y=74!
    let jumpPose = TomyPose(row: .celebrate, col: 4)
    check(atlas.contains(point: CGPoint(x: 34, y: 74), in: box, pose: idlePose) &&
          !atlas.contains(point: CGPoint(x: 40, y: 74), in: box, pose: jumpPose),
          "hit-mask Y axis is upright: grounded feet hit at y=74 while airborne jump apex clears y=74")

    // Verify actual CoreGraphics drawing via TomyCanvasView hosted in TomyPetPanel across all 9 rows
    _ = NSApplication.shared
    let testPanel = TomyPetPanel(contentRect: NSRect(x: 100, y: 100, width: 96, height: 104))
    let canvas = TomyCanvasView(frame: NSRect(x: 0, y: 0, width: 96, height: 104))
    testPanel.contentView = canvas
    for row in TomyAtlasRow.allCases {
        canvas.pose = TomyPose(row: row, col: row.staticFrame)
        guard let rep = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else {
            check(false, "allocates bitmap rep for TomyCanvasView \(row)")
            continue
        }
        canvas.cacheDisplay(in: canvas.bounds, to: rep)
        let cx = rep.pixelsWide / 2
        let cy = (rep.pixelsHigh * 56) / 104
        let centerAlpha = rep.colorAt(x: cx, y: cy)?.alphaComponent ?? 0
        let cornerAlpha = rep.colorAt(x: 1, y: 1)?.alphaComponent ?? 1
        check(centerAlpha > 0.9 && cornerAlpha == 0,
              "TomyCanvasView renders opaque sprite center and transparent background for \(row)")
    }

    // Verify stem-pivot drag tilt agrees between rendered bitmap and hit-mask inverse transform
    let tiltedPose = TomyPose(row: .drag, col: 0, tiltDegrees: 10.0)
    canvas.pose = tiltedPose
    if let tiltedRep = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) {
        canvas.cacheDisplay(in: canvas.bounds, to: tiltedRep)
        let probePt = CGPoint(x: 38, y: 73)
        let px = (tiltedRep.pixelsWide * Int(probePt.x)) / 96
        let py = (tiltedRep.pixelsHigh * Int(probePt.y)) / 104
        let probeAlpha = tiltedRep.colorAt(x: px, y: py)?.alphaComponent ?? 0
        let cornerAlpha = tiltedRep.colorAt(x: 1, y: 1)?.alphaComponent ?? 1
        check(probeAlpha > 0.85 && cornerAlpha == 0 &&
              atlas.contains(point: probePt, in: CGSize(width: 96, height: 104), pose: tiltedPose),
              "tilted pendulum draw (+10 deg swings body left) matches hit-mask inverse rotation without edge clipping")
    } else {
        check(false, "allocates bitmap rep for tilted TomyCanvasView")
    }
    testPanel.contentView = nil

    // Verify TBTimer.onWorkCancelled fires strictly on active work cancellation
    var cancelFiredCount = 0
    statusTimer.onWorkCancelled = { cancelFiredCount += 1 }
    statusTimer.cancel()
    check(cancelFiredCount == 0, "cancelling while idle does not fire onWorkCancelled")
    statusTimer.startWork()
    _ = statusTimer.freezeForCancel()
    statusTimer.cancel()
    check(cancelFiredCount == 1 && statusTimer.state.phase == .idle,
          "cancelling frozen work fires onWorkCancelled exactly once")
    statusTimer.onWorkCancelled = nil

    // Verify TomyPetController.applyCancelWorkDecision preserves pre-modal running/paused state
    let petCancelController = TomyPetController(timer: statusTimer)
    statusTimer.startWork()
    let wasPausedRunning = statusTimer.state.paused
    check(!wasPausedRunning && statusTimer.freezeForCancel() && statusTimer.state.paused,
          "freezeForCancel pauses active work before cancel alert opens")
    petCancelController.applyCancelWorkDecision(confirmedCancel: false, wasPaused: wasPausedRunning)
    check(statusTimer.state.phase == .work && !statusTimer.state.paused,
          "choosing continue on cancel prompt resumes work when timer was previously running")

    statusTimer.pause()
    let wasPausedBeforeModal = statusTimer.state.paused
    check(wasPausedBeforeModal && statusTimer.freezeForCancel() && statusTimer.state.paused,
          "freezeForCancel preserves paused state when work was already paused")
    petCancelController.applyCancelWorkDecision(confirmedCancel: false, wasPaused: wasPausedBeforeModal)
    check(statusTimer.state.phase == .work && statusTimer.state.paused,
          "choosing continue on cancel prompt keeps work paused if it was already paused")

    var menuCancelFired = 0
    statusTimer.onWorkCancelled = { menuCancelFired += 1 }
    petCancelController.applyCancelWorkDecision(confirmedCancel: true, wasPaused: wasPausedBeforeModal)
    check(menuCancelFired == 1 && statusTimer.state.phase == .idle,
          "confirming cancel via applyCancelWorkDecision discards work and fires onWorkCancelled")
    statusTimer.onWorkCancelled = nil
    petCancelController.shutdown()

    // Verify TBReminder auto-dismisses when needsAttention is confirmed externally via Tomy
    let reminderStore = FocusStore(url: scratch.appendingPathComponent("tomy-reminder/sessions.json"))
    var reminderSeed = FocusState()
    reminderSeed.phase = .workFinished
    try reminderStore.save(reminderSeed)
    let reminderTimer = TBTimer(store: reminderStore)
    let reminderController = TomyPetController(timer: reminderTimer)
    let reminder = TBReminder()
    reminder.show(timer: reminderTimer)
    check(reminder.isVisible && reminderTimer.state.needsAttention,
          "TBReminder opens visibly when focus completion awaits attention")
    reminderController.confirmAttentionFromClick()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    check(!reminder.isVisible && reminderTimer.state.phase == .rest && !reminderTimer.state.needsAttention,
          "confirming attention from Tomy automatically dismisses TBReminder and starts rest")
    reminder.dismiss()
    reminderController.shutdown()
}

print("PASS: \(checks) actual TBTimer bridge checks; isolated QA13 IO, no UI interaction")
withExtendedLifetime(observation) {}
