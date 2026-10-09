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

// Desktop Pet V3 Sprout deterministic animation assertions:
let sproutWork = PetKind.sprout.stripAnimation(for: .work, paused: false)
check(sproutWork != nil && sproutWork?.assetName == "pet_sprout_work_v3" && sproutWork?.frameCount == 10 && sproutWork?.durations.count == 10 && sproutWork?.loopMode == .loop,
      "Sprout work animation has 10 frames, 10 durations, loops")

let sproutIdle = PetKind.sprout.stripAnimation(for: .idle, paused: false)
check(sproutIdle != nil && sproutIdle?.assetName == "pet_sprout_idle_v3" && sproutIdle?.frameCount == 8 && sproutIdle?.durations.count == 8 && sproutIdle?.loopMode == .loop,
      "Sprout idle animation has 8 frames, 8 durations, loops")

let sproutRest = PetKind.sprout.stripAnimation(for: .rest, paused: false)
check(sproutRest != nil && sproutRest?.assetName == "pet_sprout_rest_v3" && sproutRest?.frameCount == 8 && sproutRest?.durations.count == 8 && sproutRest?.loopMode == .loop,
      "Sprout rest animation has 8 frames, 8 durations, loops")

let sproutWorkFinished = PetKind.sprout.stripAnimation(for: .workFinished, paused: false)
check(sproutWorkFinished != nil && sproutWorkFinished?.assetName == "pet_sprout_work_finished_v3" && sproutWorkFinished?.frameCount == 8 && sproutWorkFinished?.durations.count == 8 && sproutWorkFinished?.loopMode == .onceHold,
      "Sprout workFinished animation has 8 frames, 8 durations, onceHold")

let sproutRestFinished = PetKind.sprout.stripAnimation(for: .restFinished, paused: false)
check(sproutRestFinished != nil && sproutRestFinished?.assetName == "pet_sprout_rest_finished_v3" && sproutRestFinished?.frameCount == 8 && sproutRestFinished?.durations.count == 8 && sproutRestFinished?.loopMode == .onceHold,
      "Sprout restFinished animation has 8 frames, 8 durations, onceHold")

// Phase-aware paused states: work and rest must use dedicated silhouettes
let sproutPausedWork = PetKind.sprout.stripAnimation(for: .work, paused: true)
let sproutPausedRest = PetKind.sprout.stripAnimation(for: .rest, paused: true)
check(sproutPausedWork != nil && sproutPausedWork?.assetName == "pet_sprout_work_paused_v3" && sproutPausedWork?.frameCount == 4 && sproutPausedWork?.durations.count == 4 && sproutPausedWork?.loopMode == .loop,
      "Sprout work paused animation uses pet_sprout_work_paused_v3, 4 frames, loops")
check(sproutPausedRest != nil && sproutPausedRest?.assetName == "pet_sprout_rest_paused_v3" && sproutPausedRest?.frameCount == 4 && sproutPausedRest?.durations.count == 4 && sproutPausedRest?.loopMode == .loop,
      "Sprout rest paused animation uses pet_sprout_rest_paused_v3, 4 frames, loops")
check(sproutPausedWork?.assetName != sproutPausedRest?.assetName,
      "Sprout paused animation is phase-aware (work paused != rest paused)")

// Chip and Clay legacy pets continue to return nil for strip animations
check(PetKind.chip.stripAnimation(for: .work, paused: false) == nil,
      "Chip uses frame sequence rather than sprite strip")
check(PetKind.clay.stripAnimation(for: .work, paused: false) == nil,
      "Clay uses frame sequence rather than sprite strip")

// Compact Tomy uses the approved neutral body and authored eye patches, not the legacy strip.
let atlasURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("TomatoBar/Assets.xcassets/pet_tomy_compact_v1.imageset/pet_tomy_compact_v1.png")
let propsURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("TomatoBar/Assets.xcassets/pet_tomy_scenes_v1.imageset/pet_tomy_scenes_v1.png")
let compactAtlas = CompactTomyAtlas(image: NSImage(contentsOf: atlasURL), propsImage: NSImage(contentsOf: propsURL))
check(compactAtlas.body?.width == 724 && compactAtlas.body?.height == 724, "compact neutral cell loads from real asset")
check(compactAtlas.eyePatches.count == 3 && compactAtlas.eyePatches.allSatisfy { $0.count == 2 }, "all authored eye poses load")
check(compactAtlas.contains(CGPoint(x: 48, y: 48), size: CGSize(width: 96, height: 96), pose: PetPose()), "opaque torso accepts pointer")
check(!compactAtlas.contains(CGPoint(x: 2, y: 2), size: CGSize(width: 96, height: 96), pose: PetPose()) &&
      !compactAtlas.contains(CGPoint(x: 10, y: 88), size: CGSize(width: 96, height: 96), pose: PetPose()), "transparent corners do not capture pointer")
check(CompactTomyAtlas(image: nil).body == nil && !CompactTomyAtlas(image: nil).contains(.zero, size: CGSize(width: 96, height: 96), pose: PetPose()), "missing asset never creates an invisible click blocker")
// Raster rendering and the inverse mouse mask must agree for rotated/stretched poses.
// Render outside the 96-point slot to detect clipping rather than hiding it.
var maskMatches = true, staysInsideSlot = true, coveredSamples = 0
var sceneSamples: [PetPose] = []
for state in PetMotionState.allCases {
    for time in [0.9, 1.35, 3.9] {
        sceneSamples.append(PetMotionDriver(state: state, now: 0).pose(at: time))
    }
    for next in PetMotionState.allCases where next != state {
        var driver = PetMotionDriver(state: state, now: 0)
        driver.configure(state: next, hovered: false, dragging: false, enabled: true, reduced: false, now: 4)
        for t in [0.0, 0.08, 0.17, 0.26, 0.4] { sceneSamples.append(driver.pose(at: 4 + t)) }
    }
}
for pose in sceneSamples {
        let canvas = 144, inset = 24
        var pixels = [UInt8](repeating: 0, count: canvas * canvas * 4)
        pixels.withUnsafeMutableBytes { bytes in
            let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            let context = CGContext(data: bytes.baseAddress, width: canvas, height: canvas,
                bitsPerComponent: 8, bytesPerRow: canvas * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
            context.translateBy(x: 0, y: CGFloat(canvas)); context.scaleBy(x: 1, y: -1)
            context.translateBy(x: CGFloat(inset), y: CGFloat(inset))
            compactAtlas.draw(in: context, size: CGSize(width: 96, height: 96), pose: pose)
        }
        for y in 0..<canvas {
            for x in 0..<canvas where pixels[(y * canvas + x) * 4 + 3] > 96 {
                staysInsideSlot = staysInsideSlot && (inset..<(inset + 96)).contains(x) && (inset..<(inset + 96)).contains(y)
            }
        }
        for y in stride(from: 2, to: 94, by: 4) {
            for x in stride(from: 2, to: 94, by: 4) {
                let alpha = pixels[((y + inset) * canvas + x + inset) * 4 + 3]
                if alpha < 24 || alpha > 200 {
                    let hit = compactAtlas.contains(CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5),
                                                    size: CGSize(width: 96, height: 96), pose: pose)
                    maskMatches = maskMatches && hit == (alpha > 200)
                    if hit { coveredSamples += 1 }
                }
            }
        }
}
check(staysInsideSlot, "all authored states fit in the real 96-point slot without clipping")
check(maskMatches && coveredSamples > 100, "mouse mask matches character and props in every state and transition")
let sleeping = PetMotionDriver(state: .rest, now: 0).pose(at: 3)
check(compactAtlas.contains(CGPoint(x: 88, y: 84), size: CGSize(width: 96, height: 96), pose: sleeping),
      "pillow outside the leaning character is part of the clickable scene")
check(CompactPetLayout.scale(.nan) == 1 && CompactPetLayout.scale(-1) == 1 &&
      CompactPetLayout.scale(0.8) == 0.8 && CompactPetLayout.scale(9) == 1.2, "compact scale is finite and bounded")
let screenArea = NSRect(x: -1920, y: 40, width: 1920, height: 1040)
let edge = DesktopPetController.clamped(NSRect(x: -20, y: 1060, width: 115.2, height: 115.2), to: screenArea)
check(screenArea.contains(edge) && edge.maxX <= -4 && edge.maxY <= 1076, "resize and negative display coordinates stay on screen")
let farOff = DesktopPetController.clamped(NSRect(x: -4000, y: -3000, width: 96, height: 96), to: NSRect(x: 0, y: 0, width: 1512, height: 950))
check(farOff.origin == CGPoint(x: 4, y: 4), "removed-screen position clamps to a reachable corner")
func drainPetEvents(_ seconds: TimeInterval) {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline { RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.01))) }
}
func petMouse(_ type: NSEvent.EventType, count: Int = 1) -> NSEvent {
    NSEvent.mouseEvent(with: type, location: CGPoint(x: 48, y: 48), modifierFlags: [], timestamp: 0,
                       windowNumber: 0, context: nil, eventNumber: 0, clickCount: count, pressure: 1)!
}
let petEvents = DesktopPetEventView(frame: NSRect(x: 0, y: 0, width: 96, height: 96))
var singles = 0, doubles = 0, dragStarts = 0, dragEnds = 0
petEvents.onSingleClick = { singles += 1 }; petEvents.onDoubleClick = { doubles += 1 }
petEvents.onDragBegan = { dragStarts += 1 }; petEvents.onDragEnded = { dragEnds += 1 }
petEvents.mouseDown(with: petMouse(.leftMouseDown))
petEvents.mouseUp(with: petMouse(.leftMouseUp))
petEvents.mouseDown(with: petMouse(.leftMouseDown, count: 2))
petEvents.mouseUp(with: petMouse(.leftMouseUp, count: 2))
drainPetEvents(NSEvent.doubleClickInterval + 0.05)
check(singles == 0 && doubles == 1, "double click never starts or pauses a timer first")
petEvents.mouseDown(with: petMouse(.leftMouseDown)); petEvents.mouseUp(with: petMouse(.leftMouseUp))
drainPetEvents(NSEvent.doubleClickInterval + 0.05)
check(singles == 1, "single click fires once after the double-click interval")
petEvents.mouseDown(with: petMouse(.leftMouseDown)); petEvents.mouseDragged(with: petMouse(.leftMouseDragged))
petEvents.mouseUp(with: petMouse(.leftMouseUp))
drainPetEvents(NSEvent.doubleClickInterval + 0.05)
check(singles == 1 && dragStarts == 1 && dragEnds == 1, "drag cannot also trigger a click")
petEvents.mouseDown(with: petMouse(.leftMouseDown)); petEvents.mouseUp(with: petMouse(.leftMouseUp))
petEvents.cancelPendingClick(); drainPetEvents(NSEvent.doubleClickInterval + 0.05)
check(singles == 1, "hiding or dismantling cancels queued timer actions")
let petAnimator = DesktopPetAnimator()
petAnimator.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: false)
petAnimator.setPresented(true)
check(petAnimator.isTicking, "visible animation starts a real frame timer")
petAnimator.setPresented(false)
check(!petAnimator.isTicking, "hidden animation releases its frame timer")
petAnimator.setPresented(true)
petAnimator.configure(state: .work, hovered: false, dragging: false, enabled: true, reduced: true)
check(!petAnimator.isTicking, "reduced motion releases the real frame timer")
petAnimator.configure(state: .workFinished, hovered: false, dragging: false, enabled: true, reduced: false)
drainPetEvents(2.3)
check(!petAnimator.isTicking, "completed celebration releases the real frame timer")
petAnimator.stop()

print("PASS: \(checks) actual TBTimer bridge checks; isolated QA13 IO, no UI interaction")
withExtendedLifetime(observation) {}
