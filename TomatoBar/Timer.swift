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
        KeyboardShortcuts.onKeyUp(for: .startStopTimer) { [weak self] in
            DispatchQueue.main.async { self?.primaryAction() }
        }
        ticker = Foundation.Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
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
    var restMinutes: Int { state.rounds % max(1, workIntervalsInSet) == 0 ? longRestIntervalLength : shortRestIntervalLength }

    func primaryAction() {
        if state.isTiming { togglePause() }
        else if state.needsAttention { onAttention?() }
        else { startWork() }
    }
    func startWork() {
        guard storageError == nil else { return }
        change { $0.startWork(name: eventName, seconds: Double(max(1, workIntervalLength) * 60), at: $1) }
    }
    func startRest() {
        let seconds = Double(max(1, restMinutes) * 60)
        change { $0.startRest(seconds: seconds, at: $1) }
    }
    func togglePause() {
        change { state, date in
            if state.paused { state.resume(at: date) } else { state.pause(at: date) }
        }
    }
    func pause() { change { $0.pause(at: $1) } }
    func stop() { change { $0.stop(at: $1) } }
    /// Commit edits only after the atomic disk write succeeds; a failed edit stays in the editor.
    func editRecord(id: UUID, name: String, tags: [String], styles: [String: String]? = nil) -> String? {
        guard !loadFailed else { return "记录未能读取，暂时无法编辑。" }
        var updated = state
        do {
            try updated.editRecord(id: id, name: name, tags: tags, categoryStyles: styles)
            updated.checkpoint = Date()
            try store.save(updated)
            state = updated
            history.records = updated.records
            lastSave = updated.checkpoint
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
        state.categoryStyles[category.lowercased()] ?? Garden.symbol(category)
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
        let previous = state.phase
        now = Date()
        state.tick(at: now)
        if previous != state.phase || (state.isTiming && now.timeIntervalSince(lastSave) >= 5) { persist() }
        updateStatus()
        if state.needsAttention && previous != state.phase { onAttention?() }
    }
    private func persist() {
        guard !loadFailed else { return }
        if history.records != state.records { history.records = state.records }
        state.checkpoint = now
        do { try store.save(state); storageError = nil; lastSave = now }
        catch { storageError = "记录保存失败，请检查磁盘空间。当前记录仍保留在内存中。" }
    }
    func updateStatus() {
        if windowActivity.paused != state.paused { windowActivity.paused = state.paused }
        let icon: NSImage.Name = state.phase == .work ? .work : (state.phase == .rest ? .shortRest : .idle)
        TBStatusItem.shared?.setIcon(name: icon)
        let title = state.needsAttention ? "请确认" : (state.isTiming && showTimerInMenuBar ? "\(state.paused ? "Ⅱ " : "")\(timeLeft)" : nil)
        TBStatusItem.shared?.setTitle(title: title)
    }
}
