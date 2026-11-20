import KeyboardShortcuts
import SwiftUI

final class FocusHistory: ObservableObject {
    @Published var records: [FocusRecord] = [] {
        didSet { if records != oldValue { summaries.removeAll(keepingCapacity: true) } }
    }
    /// Coarse session state the main window's row controls gate on. The deadline itself
    /// stays out: a per-second tick must not publish to the statistics parent.
    struct Session: Equatable {
        var phase: FocusPhase = .idle
        var paused = false
        var storageError: String?
        var isTiming: Bool { phase == .work || phase == .rest }
        var needsAttention: Bool { phase == .workFinished || phase == .restFinished }
    }
    private struct Context: Equatable {
        var todos: [FocusTodo] = []
        var projects: [FocusProject] = []
        var currentTodoID: UUID?
        var draftTags: [String] = []
        var styles: [String: String] = [:]
        var session = Session()
    }
    @Published private(set) var session = Session()
    @Published private var context = Context()
    private struct CalendarContext: Equatable {
        let day: Date
        let calendar: Calendar
        init(at date: Date, calendar: Calendar) {
            day = calendar.startOfDay(for: date)
            self.calendar = calendar
        }
    }
    @Published private var calendarContext = CalendarContext(at: Date(), calendar: .current)
    private struct SummaryKey: Hashable {
        let period: String
        let interval: DateInterval
        let category: String?
        let calendar: Calendar
    }
    private var summaries: [SummaryKey: FocusSummary] = [:]
    private(set) var summaryBuildCount = 0

    func update(from state: FocusState, storageError: String? = nil) {
        if records != state.records { records = state.records }
        // The main window needs task/style changes, but never the ticking deadline. Phase,
        // pause and storage failure do belong here: row controls gate on them, and they
        // change on transitions, not every tick.
        let live = Session(phase: state.phase, paused: state.paused, storageError: storageError)
        if live != session { session = live }
        let next = Context(todos: state.todos, projects: state.projects,
                           currentTodoID: state.currentTodoID, draftTags: state.draftTags,
                           styles: state.categoryStyles, session: live)
        if context != next { context = next }
    }

    func updateCalendar(at date: Date, calendar: Calendar = .current) {
        let next = CalendarContext(at: date, calendar: calendar)
        if next != calendarContext { calendarContext = next }
    }

    func summary(period: FocusPeriod, date: Date, category: String? = nil,
                 calendar: Calendar = .current) -> FocusSummary {
        let key = SummaryKey(period: period.rawValue, interval: period.interval(containing: date, calendar: calendar),
                             category: category.map(FocusRecord.tagIdentity), calendar: calendar)
        if let cached = summaries[key] { return cached }
        // Bound the cache by evicting old filtered summaries only. The unfiltered summary
        // is read by several panels in one body evaluation (heading, sidebar, record list)
        // while the chart reads the filtered one, so clearing the whole map on every
        // category switch forced a second full aggregation in the same render pass.
        if summaries.count >= 2 {
            summaries = summaries.filter { $0.key.category == nil }
        }
        let result = FocusSummary(records: records, period: period, date: date, category: category, calendar: calendar)
        summaries[key] = result
        summaryBuildCount += 1
        return result
    }
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
    var onWorkCancelled: (() -> Void)?

    init(store: FocusStore = FocusStore()) {
        self.store = store
        do {
            state = try store.load()
            state.recover()
        } catch {
            loadFailed = true
            storageError = "无法读取专注记录，已保留原文件未覆盖。可打开记录文件夹检查，修复后点「重新读取」。"
        }
        history.update(from: state, storageError: storageError)
        // Keep the event field in step with the loaded selection. A leftover name from an
        // earlier session would otherwise be recorded for a task whose UI hides the field.
        if let current = state.currentTodo { eventName = state.displayName(for: current) }
        sanitizeSettings()
        KeyboardShortcuts.onKeyUp(for: .startStopTimer) { [weak self] in
            DispatchQueue.main.async { self?.primaryAction() }
        }
        ticker = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    deinit { ticker?.invalidate() }

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

    /// The event field mirrors the selected task's *display* name, which carries the
    /// project prefix. Comparing it against the raw title would treat the field's own
    /// auto-filled value as a manual edit and drop the task selection.
    private func eventNameMatches(_ todo: FocusTodo) -> Bool {
        FocusRecord.sameTag(eventName, state.displayName(for: todo))
    }

    func setEventName(_ value: String) {
        eventName = value
        if let id = state.currentTodoID,
           let todo = state.todos.first(where: { $0.id == id }),
           !eventNameMatches(todo) {
            change { state, _ in
                state.selectCurrentTodo(nil)
            }
        }
        // During the gap after a rest, editing away from the current task is an explicit
        // switch to manual work. Clear the persisted series context immediately so the
        // next round cannot be attributed to the previous Todo by accident.
        if state.phase == .restFinished,
           let id = state.seriesTodoID,
           let todo = state.todos.first(where: { $0.id == id }),
           !eventNameMatches(todo) {
            change { state, _ in
                if state.seriesTodoID == id { state.seriesTodoID = nil }
            }
        }
    }

    private func clearEventNameIfMatching(_ previousDisplay: String?) {
        guard let previousDisplay, FocusRecord.sameTag(eventName, previousDisplay) else { return }
        eventName = ""
    }

    func selectCurrentTodo(_ id: UUID?) {
        guard storageError == nil else { return }
        let previousDisplay = state.currentTodo.map { state.displayName(for: $0) }
        change { state, _ in
            state.selectCurrentTodo(id)
            if let id = id, let todo = state.currentTodo, todo.id == id {
                self.eventName = state.displayName(for: todo)
            } else if id == nil {
                self.clearEventNameIfMatching(previousDisplay)
            }
        }
    }

    func addTodo(_ title: String, tags: [String] = [], projectID: UUID? = nil) {
        guard storageError == nil else { return }
        change { state, date in _ = state.addTodo(title: title, tags: tags, projectID: projectID, at: date) }
    }

    func addProject(name: String, tags: [String] = [], color: String? = nil) {
        guard storageError == nil else { return }
        change { state, date in _ = state.addProject(name: name, tags: tags, color: color, at: date) }
    }

    func updateProject(id: UUID, name: String, tags: [String]? = nil, color: String? = nil) {
        guard storageError == nil else { return }
        change { state, _ in
            state.updateProject(id: id, name: name, tags: tags, color: color)
            if let todo = state.currentTodo, todo.projectID == id {
                self.eventName = state.displayName(for: todo)
            }
        }
    }

    func renameProject(id: UUID, name: String) {
        updateProject(id: id, name: name)
    }

    func deleteProject(id: UUID) {
        guard storageError == nil else { return }
        change { state, _ in
            state.deleteProject(id: id)
            if let todo = state.currentTodo {
                self.eventName = state.displayName(for: todo)
            }
        }
    }

    func toggleProjectCompleted(id: UUID) {
        guard storageError == nil else { return }
        let previousDisplay = (state.currentTodo?.projectID == id)
            ? state.currentTodo.map { state.displayName(for: $0) }
            : nil
        change { state, date in
            state.toggleProjectCompleted(id: id, at: date)
            if state.currentTodoID == nil {
                self.clearEventNameIfMatching(previousDisplay)
            }
        }
    }

    func toggleProjectArchived(id: UUID) {
        toggleProjectCompleted(id: id)
    }

    func setTodoProject(todoID: UUID, projectID: UUID?) {
        guard storageError == nil else { return }
        change { state, _ in
            state.setTodoProject(todoID: todoID, projectID: projectID)
            if let todo = state.currentTodo, todo.id == todoID {
                self.eventName = state.displayName(for: todo)
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

    func toggleDraftTag(_ tag: String) {
        setDraftTags(FocusRecord.togglingTag(tag, in: state.draftTags))
    }

    func renameTodo(id: UUID, title: String) {
        guard storageError == nil else { return }
        change { state, _ in state.renameTodo(id: id, title: title) }
        guard let todo = state.todos.first(where: { $0.id == id }) else { return }
        // The current selection owns the event field: selectCurrentTodo/setEventName only
        // ever leave it holding the current task's display name, so a rename must follow.
        // The series task is NOT the field's owner — after an explicit switch to another
        // current task it can differ, and rewriting the field there recorded the freshly
        // chosen task under the old task's name.
        if state.currentTodoID == id {
            eventName = state.displayName(for: todo)
        }
    }

    func toggleTodo(id: UUID) {
        guard storageError == nil else { return }
        let previousDisplay = (state.currentTodoID == id)
            ? state.currentTodo.map { state.displayName(for: $0) }
            : nil
        change { state, date in
            state.toggleTodo(id: id, at: date)
            if state.currentTodoID == nil {
                self.clearEventNameIfMatching(previousDisplay)
            }
        }
    }

    func deleteTodo(id: UUID) {
        guard storageError == nil else { return }
        let previousDisplay = (state.currentTodoID == id)
            ? state.currentTodo.map { state.displayName(for: $0) }
            : nil
        change { state, _ in
            state.deleteTodo(id: id)
            if state.currentTodoID == nil {
                self.clearEventNameIfMatching(previousDisplay)
            }
        }
    }

    func moveTodo(id: UUID, before targetID: UUID?) {
        guard storageError == nil else { return }
        change { state, _ in state.moveTodo(id: id, before: targetID) }
    }

    func relocateTodo(id: UUID, toProject projectID: UUID?, before targetID: UUID? = nil) {
        guard storageError == nil else { return }
        let previousDisplay = (state.currentTodoID == id)
            ? state.currentTodo.map { state.displayName(for: $0) }
            : nil
        change { state, _ in
            state.relocateTodo(id: id, toProject: projectID, before: targetID)
            if let todo = state.currentTodo, todo.id == id {
                self.eventName = state.displayName(for: todo)
            } else if state.currentTodo == nil {
                self.clearEventNameIfMatching(previousDisplay)
            }
        }
    }

    func clearCompletedLooseTodos() {
        guard storageError == nil else { return }
        change { state, _ in state.clearCompletedLooseTodos() }
    }

    func primaryAction() {
        if state.isTiming { togglePause() }
        else if state.needsAttention { onAttention?() }
        else { startWork() }
    }
    func startWork() {
        guard storageError == nil else { return }
        let todoID = state.currentTodoID
        let minutes = Self.clamped(workIntervalLength, to: 1...180)
        if todoID != nil {
            change { $0.startWork(name: eventName, seconds: Double(minutes * 60),
                                  todoID: todoID, tags: nil, at: $1) }
        } else {
            let (parsedName, inlineTags) = FocusTodo.parseInput(eventName)
            let effectiveTags = FocusRecord.normalizedTags(state.draftTags + inlineTags)
            change { $0.startWork(name: parsedName, seconds: Double(minutes * 60),
                                  todoID: nil, tags: effectiveTags, at: $1) }
        }
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
    func cancel() {
        let wasWork = (state.phase == .work)
        change { $0.cancel(at: $1) }
        if wasWork && state.phase == .idle {
            onWorkCancelled?()
        }
    }
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
            history.update(from: updated, storageError: storageError)
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
            history.update(from: updated, storageError: storageError)
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
            // Same rule as init: a recovered selection owns the event field, so a name
            // left from the failed-load period cannot be recorded for that task.
            if let current = state.currentTodo { eventName = state.displayName(for: current) }
            loadFailed = false
            storageError = nil
            lastSave = Date()
            history.update(from: state, storageError: storageError)
            updateStatus()
        } catch {
            storageError = "仍然无法读取专注记录，原文件已保留。请修复文件后重试，或重启应用。"
            history.update(from: state, storageError: storageError)
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
        history.updateCalendar(at: freshNow)
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
        guard !loadFailed else {
            // The session's storage-error gate lives in the history context too, so a
            // failed load must reach the main window's row controls. Only an actual
            // change publishes; the per-tick persist below stays silent.
            if history.session.storageError != storageError { history.update(from: state, storageError: storageError) }
            return
        }
        state.checkpoint = now
        do { try store.save(state); storageError = nil; lastSave = now; lastFailedSave = .distantPast }
        catch { storageError = "记录保存失败，请检查磁盘空间。当前记录仍保留在内存中。"; lastFailedSave = now }
        // Publish a failure (and its recovery) even when every other context field is
        // unchanged, so the row controls disable and re-enable with the save state.
        history.update(from: state, storageError: storageError)
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

    var statusTitle: String? {
        if state.needsAttention { return "请确认" }
        if state.isTiming && showTimerInMenuBar { return timeLeft }
        return nil
    }

    var isStatusPaused: Bool {
        state.isTiming && state.paused
    }

    func updateStatus() {
        if windowActivity.paused != state.paused { windowActivity.paused = state.paused }
        let icon: TBStatusItem.StatusIcon = (state.phase == .rest && smokeBreakEasterEgg)
            ? .emoji("🚬")
            : .asset(state.phase == .work ? .work : (state.phase == .rest ? .shortRest : .idle))
        TBStatusItem.shared?.setStatus(
            icon: icon,
            title: statusTitle,
            paused: isStatusPaused,
            phaseLabel: phaseLabel
        )
    }
}
