import KeyboardShortcuts
import SwiftUI

final class FocusHistory: ObservableObject {
    @Published var records: [FocusRecord] = []
}

final class WindowActivity: ObservableObject {
    @Published var visible = false
    @Published var paused = false
}

final class TBTimer: ObservableObject {
    let history = FocusHistory()
    let windowActivity = WindowActivity()
    @AppStorage("showTimerInMenuBar") var showTimerInMenuBar = true
    @AppStorage("smokeBreakEasterEgg") private var smokeBreakEasterEgg = false
    @AppStorage("workIntervalLength") var workIntervalLength = 25
    @AppStorage("shortRestIntervalLength") var shortRestIntervalLength = 5
    @AppStorage("longRestIntervalLength") var longRestIntervalLength = 15
    @AppStorage("workIntervalsInSet") var workIntervalsInSet = 4
    @AppStorage("eventName") var eventName = ""
    @Published private(set) var state = FocusState()
    @Published private(set) var now = Date()
    @Published private(set) var storageError: String?
    /// A task chosen as the next focus target. It is copied into FocusState.activeTodoID
    /// when a work session begins, then cleared so later manual entries never inherit it.
    @Published private(set) var preparedTodoID: UUID?
    private let store: FocusStore
    private var ticker: Foundation.Timer?
    private var lastSave = Date.distantPast
    // After a failed write the 0.25s tick would otherwise re-attempt persist() four times
    // a second forever (lastSave never advances, so the 5s condition stays true). The
    // auto path backs off 30s between failures; the user's 「重试保存」 button bypasses this.
    // Every successful write — here or in editRecord/deleteRecord — must clear the backoff,
    // or recovery silently costs up to 30s of checkpoints anyway (P24). Getter is internal
    // so the bridge suite can assert the reset without waiting out the 30s window.
    private(set) var lastFailedSave = Date.distantPast
    private var loadFailed = false
    var onAttention: (() -> Void)?

    init(store: FocusStore = FocusStore()) {
        self.store = store
        do {
            state = try store.load()
            state.recover()
        } catch {
            loadFailed = true
            storageError = "无法读取专注记录，已保留原文件未覆盖。可打开记录文件夹检查，修复后点「重新读取」。"
        }
        history.records = state.records
        if let current = state.currentTodo, eventName.isEmpty {
            eventName = current.title
        }
        sanitizeSettings()
        KeyboardShortcuts.onKeyUp(for: .startStopTimer) { [weak self] in
            DispatchQueue.main.async { self?.primaryAction() }
        }
        ticker = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private static func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func sanitizeSettings() {
        workIntervalLength = Self.clamped(workIntervalLength, to: 1...180)
        shortRestIntervalLength = Self.clamped(shortRestIntervalLength, to: 1...60)
        longRestIntervalLength = Self.clamped(longRestIntervalLength, to: 1...60)
        workIntervalsInSet = Self.clamped(workIntervalsInSet, to: 1...10)
    }

    var timeLeft: String {
        let seconds = Int(ceil(state.timeLeft(at: now)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    var phaseLabel: String {
        switch state.phase {
        case .idle: return "准备开始"
        case .work: return state.paused ? "专注已暂停" : "正在专注"
        case .rest: return state.paused ? "休息已暂停" : "正在休息"
        case .workFinished: return "专注完成"
        case .restFinished: return "休息结束"
        }
    }
    var todaySeconds: TimeInterval { state.records.reduce(0) { $0 + $1.seconds(on: now) } }
    var todayCount: Int {
        state.records.filter { $0.completed && Calendar.current.isDate($0.endedAt, inSameDayAs: now) }.count
    }
    var restMinutes: Int {
        let groupSize = Self.clamped(workIntervalsInSet, to: 1...10)
        let short = Self.clamped(shortRestIntervalLength, to: 1...60)
        let long = Self.clamped(longRestIntervalLength, to: 1...60)
        return state.rounds % groupSize == 0 ? long : short
    }

    func setEventName(_ value: String) {
        eventName = value
        if let id = preparedTodoID,
           state.todos.first(where: { $0.id == id })?.title != value {
            preparedTodoID = nil
        }
        if let id = state.currentTodoID,
           state.todos.first(where: { $0.id == id })?.title != value {
            change { state, _ in
                state.selectCurrentTodo(nil)
            }
        }
        // During the gap after a rest, editing away from the current task is an explicit
        // switch to manual work. Clear the persisted series context immediately so the
        // next round cannot be attributed to the previous Todo by accident.
        if state.phase == .restFinished,
           let id = state.seriesTodoID,
           state.todos.first(where: { $0.id == id })?.title != value {
            change { state, _ in
                if state.seriesTodoID == id { state.seriesTodoID = nil }
            }
        }
    }

    func selectCurrentTodo(_ id: UUID?) {
        guard storageError == nil else { return }
        change { state, _ in
            state.selectCurrentTodo(id)
            if let id = id, let todo = state.todos.first(where: { $0.id == id }) {
                if let pid = todo.projectID, let proj = state.project(for: pid) {
                    self.eventName = "[\(proj.name)] · \(todo.title)"
                } else {
                    self.eventName = todo.title
                }
            }
        }
    }

    func prepareTodo(_ todo: FocusTodo) {
        preparedTodoID = todo.id
        selectCurrentTodo(todo.id)
    }

    func addTodo(_ title: String, tags: [String] = [], projectID: UUID? = nil) {
        guard storageError == nil else { return }
        change { state, date in _ = state.addTodo(title: title, tags: tags, projectID: projectID, at: date) }
    }

    func addProject(name: String, color: String? = nil) {
        guard storageError == nil else { return }
        change { state, date in _ = state.addProject(name: name, color: color, at: date) }
    }

    func renameProject(id: UUID, name: String) {
        guard storageError == nil else { return }
        change { state, _ in
            state.renameProject(id: id, name: name)
            let activeID = self.preparedTodoID ?? state.currentTodoID
            if let tid = activeID, let todo = state.todos.first(where: { $0.id == tid }), todo.projectID == id {
                self.eventName = "[\(name.trimmingCharacters(in: .whitespacesAndNewlines))] · \(todo.title)"
            }
        }
    }

    func deleteProject(id: UUID) {
        guard storageError == nil else { return }
        change { state, _ in
            state.deleteProject(id: id)
            let activeID = self.preparedTodoID ?? state.currentTodoID
            if let tid = activeID, let todo = state.todos.first(where: { $0.id == tid }), todo.projectID == nil {
                self.eventName = todo.title
            }
        }
    }

    func toggleProjectArchived(id: UUID) {
        guard storageError == nil else { return }
        change { state, _ in state.toggleProjectArchived(id: id) }
    }

    func setTodoProject(todoID: UUID, projectID: UUID?) {
        guard storageError == nil else { return }
        change { state, _ in
            state.setTodoProject(todoID: todoID, projectID: projectID)
            let activeID = self.preparedTodoID ?? state.currentTodoID
            if activeID == todoID, let todo = state.todos.first(where: { $0.id == todoID }) {
                if let pid = todo.projectID, let proj = state.project(for: pid) {
                    self.eventName = "[\(proj.name)] · \(todo.title)"
                } else {
                    self.eventName = todo.title
                }
            }
        }
    }

    func setTodoTags(id: UUID, tags: [String]) {
        guard storageError == nil else { return }
        change { state, _ in state.setTodoTags(id: id, tags: tags) }
    }

    func setDraftTags(_ tags: [String]) {
        guard storageError == nil else { return }
        change { state, _ in state.setDraftTags(tags) }
    }

    func renameTodo(id: UUID, title: String) {
        guard storageError == nil else { return }
        change { state, _ in state.renameTodo(id: id, title: title) }
        if (preparedTodoID == id || state.seriesTodoID == id || state.currentTodoID == id),
           let todo = state.todos.first(where: { $0.id == id }) {
            if let pid = todo.projectID, let proj = state.project(for: pid) {
                eventName = "[\(proj.name)] · \(todo.title)"
            } else {
                eventName = todo.title
            }
        }
    }

    func toggleTodo(id: UUID) {
        guard storageError == nil else { return }
        change { state, date in state.toggleTodo(id: id, at: date) }
        if preparedTodoID == id,
           state.todos.first(where: { $0.id == id })?.isCompleted == true {
            preparedTodoID = nil
        }
    }

    func deleteTodo(id: UUID) {
        guard storageError == nil else { return }
        change { state, _ in state.deleteTodo(id: id) }
        if preparedTodoID == id { preparedTodoID = nil }
    }

    func moveTodo(id: UUID, before targetID: UUID?) {
        guard storageError == nil else { return }
        change { state, _ in state.moveTodo(id: id, before: targetID) }
    }

    func primaryAction() {
        if state.isTiming { togglePause() }
        else if state.needsAttention { onAttention?() }
        else { startWork() }
    }
    func startWork() {
        guard storageError == nil else { return }
        let todoID = preparedTodoID ?? state.currentTodoID
        let previousPhase = state.phase
        let minutes = Self.clamped(workIntervalLength, to: 1...180)
        let tags: [String]? = (todoID != nil) ? nil : state.draftTags
        change { $0.startWork(name: eventName, seconds: Double(minutes * 60),
                              todoID: todoID, tags: tags, at: $1) }
        if state.phase == .work && previousPhase != .work { preparedTodoID = nil }
    }
    func startRest() {
        // Same storageError gate as startWork: if the just-completed focus is still only
        // in memory, advancing into rest would let a crash bury it under a stale disk
        // checkpoint. The user must clear the error via 「重试保存」 before the cycle may
        // move on. 「结束本组」→stop is NOT a way around this: stop() does not discard the
        // completed record — it keeps it in memory and retries the write, and
        // hasUnsavedChanges still guards quitting until the record lands on disk.
        guard storageError == nil else { return }
        let seconds = Double(max(1, restMinutes) * 60)
        change { $0.startRest(seconds: seconds, at: $1) }
    }
    func skipRest() {
        guard storageError == nil else { return }
        change { $0.skipRest(at: $1) }
    }
    func togglePause() {
        change { state, date in
            if state.paused { state.resume(at: date) } else { state.pause(at: date) }
        }
    }
    func pause() { change { $0.pause(at: $1) } }
    func stop() { change { $0.stop(at: $1) } }
    // Not gated on storageError like startWork: cancelling only leaves the running state,
    // so it must work even when the disk is unwritable (persist() handles the failure).
    func cancel() { change { $0.cancel(at: $1) } }
    /// Freezes the clock while the user decides in the 「取消专注」 dialog, and reports
    /// whether the session is still cancellable. `FocusState.pause()` ticks first, so
    /// clicking exactly at the deadline completes the focus instead of pausing it; the
    /// dialog must not open over a phase where 「放弃这段」 would be a silent no-op that
    /// keeps the record anyway (P22's residual boundary, closed by P25). When this
    /// returns false the caller shows nothing — the completion already raises the
    /// reminder through change().
    @discardableResult
    func freezeForCancel() -> Bool {
        guard state.phase == .work else { return false }
        if !state.paused { pause() }
        return state.phase == .work
    }
    /// Commit edits only after the atomic disk write succeeds; a failed edit stays in the editor.
    /// `expected` is the record the editor loaded when it opened — see FocusState.editRecord (P26).
    func editRecord(id: UUID, name: String, tags: [String], styleChanges: [String: String?]? = nil,
                    expected: FocusRecord? = nil) -> String? {
        guard !loadFailed else { return "记录未能读取，暂时无法编辑。" }
        var updated = state
        do {
            try updated.editRecord(id: id, name: name, tags: tags, styleChanges: styleChanges, expected: expected)
            updated.checkpoint = Date()
            try store.save(updated)
            state = updated
            history.records = updated.records
            lastSave = updated.checkpoint
            lastFailedSave = .distantPast
            storageError = nil
            return nil
        } catch let error as RecordEditError {
            return error.localizedDescription
        } catch {
            return "保存失败，修改尚未写入。请检查磁盘空间后重试。"
        }
    }

    /// Commit the deletion only after the atomic disk write succeeds, so a failed delete
    /// never leaves the UI treating the record as gone. Mirrors editRecord.
    ///
    /// A failed save deliberately does not set storageError: `state` is assigned only
    /// after the write succeeds, so memory and disk still agree and nothing is unsaved.
    /// Setting it would make hasUnsavedChanges true and block quitting over a delete that
    /// simply did not happen. The caller surfaces the returned message instead.
    func deleteRecord(id: UUID) -> String? {
        guard !loadFailed else { return "记录未能读取，暂时无法删除。" }
        var updated = state
        do {
            try updated.deleteRecord(id: id)
            updated.checkpoint = Date()
            try store.save(updated)
            state = updated
            history.records = updated.records
            lastSave = updated.checkpoint
            lastFailedSave = .distantPast
            storageError = nil
            return nil
        } catch let error as RecordEditError {
            return error.localizedDescription
        } catch {
            return "保存失败，记录尚未删除。请检查磁盘空间后重试。"
        }
    }

    /// A category's icon: the user's override when they set one, otherwise the automatic
    /// glyph. Resolution lives here rather than in State.swift because Garden imports
    /// SwiftUI while State.swift must stay in the Foundation-only test compile set.
    func categorySymbol(_ category: String) -> String {
        FocusState.styleSymbol(in: state.categoryStyles, forCategory: category) ?? Garden.symbol(category)
    }

    /// A failed read and a failed write recover differently, so both the action and its
    /// label depend on which happened. Offering "retry save" after a failed load used to
    /// render a button that could never do anything, because persist() guards on loadFailed.
    func retryStorage() { if loadFailed { reload() } else { persist() } }
    var storageRetryTitle: String { loadFailed ? "重新读取" : "重试保存" }
    var hasUnsavedChanges: Bool { storageError != nil && !loadFailed }

    /// Adopting freshly loaded state cannot discard user data: while loadFailed is set,
    /// startWork is blocked by storageError and editRecord and persist are blocked by
    /// loadFailed, so phase stays .idle and every remaining mutation is a no-op.
    /// This deliberately does not weaken the guard that stops persist() overwriting a
    /// corrupt file — reloading only reads.
    private func reload() {
        do {
            var loaded = try store.load()
            loaded.recover()
            state = loaded
            history.records = loaded.records
            if let id = preparedTodoID, !loaded.todos.contains(where: { $0.id == id }) {
                preparedTodoID = nil
            }
            loadFailed = false
            storageError = nil
            lastSave = Date()
            updateStatus()
        } catch {
            storageError = "仍然无法读取专注记录，原文件已保留。请修复文件后重试，或重启应用。"
        }
    }
    func openRecordsFolder() {
        let folder = store.url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        } catch {
            // Never overwrite an existing storage error: it is the user's only signal that
            // their records are at risk, and this button now sits right beside that message.
            if storageError == nil { storageError = "无法打开记录文件夹，请检查磁盘空间和权限。" }
        }
    }

    private func change(_ mutation: (inout FocusState, Date) -> Void) {
        let previous = state.phase
        now = Date()
        mutation(&state, now)
        persist()
        updateStatus()
        if state.needsAttention && previous != state.phase { onAttention?() }
    }
    private func tick() {
        let freshNow = Date()
        // Keep the timer object cheap while idle/paused. We still wake once per second,
        // but publish no SwiftUI change unless the calendar day rolls over.
        guard state.isTiming && !state.paused else {
            if !Calendar.current.isDate(now, inSameDayAs: freshNow) {
                now = freshNow
            }
            return
        }
        let previous = state.phase
        now = freshNow
        state.tick(at: now)
        if previous != state.phase || (now.timeIntervalSince(lastSave) >= 5 && now.timeIntervalSince(lastFailedSave) >= 30) {
            persist()
        }
        updateStatus()
        if state.needsAttention && previous != state.phase { onAttention?() }
    }

    private func persist() {
        guard !loadFailed else { return }
        if history.records != state.records { history.records = state.records }
        state.checkpoint = now
        do { try store.save(state); storageError = nil; lastSave = now; lastFailedSave = .distantPast }
        catch { storageError = "记录保存失败，请检查磁盘空间。当前记录仍保留在内存中。"; lastFailedSave = now }
    }
    /// Hidden visual easter egg. Kept outside FocusState because this is a UI preference,
    /// not persisted focus-domain data. Returns the new state so the settings surface can
    /// give a one-shot acknowledgement without exposing a permanent toggle.
    @discardableResult
    func toggleSmokeBreakEasterEgg() -> Bool {
        smokeBreakEasterEgg.toggle()
        updateStatus()
        return smokeBreakEasterEgg
    }

    func updateStatus() {
        if windowActivity.paused != state.paused { windowActivity.paused = state.paused }
        if state.phase == .rest && smokeBreakEasterEgg {
            TBStatusItem.shared?.setEmojiIcon("🚬")
        } else {
            let icon: NSImage.Name = state.phase == .work ? .work : (state.phase == .rest ? .shortRest : .idle)
            TBStatusItem.shared?.setIcon(name: icon)
        }
        let title = state.needsAttention ? "请确认" : (state.isTiming && showTimerInMenuBar ? "\(state.paused ? "Ⅱ " : "")\(timeLeft)" : nil)
        TBStatusItem.shared?.setTitle(title: title)
    }
}
