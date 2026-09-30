import Foundation

enum FocusPhase: String, Codable { case idle, work, rest, workFinished, restFinished }

struct FocusSegment: Codable, Equatable {
    let start: Date
    let end: Date
    var seconds: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

struct FocusRecord: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let startedAt: Date
    let endedAt: Date
    let plannedSeconds: TimeInterval
    let completed: Bool
    let segments: [FocusSegment]
    var tags: [String]
    /// Optional task link. Older records decode with nil, so existing history stays intact.
    let todoID: UUID?

    init(id: UUID, name: String, startedAt: Date, endedAt: Date, plannedSeconds: TimeInterval,
         completed: Bool, segments: [FocusSegment], tags: [String] = [], todoID: UUID? = nil) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.completed = completed
        self.segments = segments
        self.tags = Self.normalizedTags(tags)
        self.todoID = todoID
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, startedAt, endedAt, plannedSeconds, completed, segments, tags, todoID
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        endedAt = try values.decode(Date.self, forKey: .endedAt)
        plannedSeconds = try values.decode(TimeInterval.self, forKey: .plannedSeconds)
        completed = try values.decode(Bool.self, forKey: .completed)
        segments = try values.decode([FocusSegment].self, forKey: .segments)
        tags = Self.normalizedTags(try values.decodeIfPresent([String].self, forKey: .tags) ?? [])
        todoID = try values.decodeIfPresent(UUID.self, forKey: .todoID)
    }

    static func normalizedTags(_ tags: [String]) -> [String] {
        var result: [String] = []
        for raw in tags {
            let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tag.isEmpty && !result.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                result.append(tag)
            }
        }
        return result
    }

    /// The statistics category *is* the first tag, so changing category means moving the
    /// chosen tag to the front. Every other tag is kept, and the previous first tag stays
    /// on as an ordinary tag the user can remove separately — removing a tag and changing
    /// the category must stay visibly different operations. Dedupe is case-insensitive,
    /// matching normalizedTags.
    ///
    /// An empty category is a no-op, not a way to clear tags: "未分类" is merely what an
    /// empty tag list displays as, so it is never offered as a choice. Clearing every tag
    /// to reach it would destroy the other tags this method exists to preserve.
    static func tags(withPrimaryCategory category: String, in tags: [String]) -> [String] {
        let primary = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedTags(tags)
        guard !primary.isEmpty else { return normalized }
        return [primary] + normalized.filter { $0.caseInsensitiveCompare(primary) != .orderedSame }
    }

    func hasTag(_ tag: String) -> Bool {
        tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }
    var seconds: TimeInterval { segments.reduce(0) { $0 + $1.seconds } }
    func seconds(on day: Date, calendar: Calendar = .current) -> TimeInterval {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return 0 }
        return segments.reduce(0) { sum, segment in
            sum + max(0, min(segment.end, interval.end).timeIntervalSince(max(segment.start, interval.start)))
        }
    }
}

struct FocusTodo: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false,
         createdAt: Date, completedAt: Date? = nil) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// All timing decisions accept a clock value so pause, completion and recovery are testable.
struct FocusState: Codable {
    var phase: FocusPhase = .idle
    var paused = false
    var name = ""
    var startedAt: Date?
    var segmentStart: Date?
    var deadline: Date?
    var remaining: TimeInterval = 0
    var planned: TimeInterval = 0
    var segments: [FocusSegment] = []
    var rounds = 0
    var records: [FocusRecord] = []
    /// Lightweight task list shared by the main window and the menu-bar popover.
    /// Array order is the user's manual order; completion never auto-deletes an item.
    var todos: [FocusTodo] = []
    /// The task associated with the currently running focus, if any.
    var activeTodoID: UUID?
    /// The task context for the current Pomodoro set. Unlike `activeTodoID`, this survives
    /// work completion and rest so 「开始下一轮」 keeps attributing later rounds to the same
    /// task. It is cleared when the set ends, the focus is cancelled, the task is completed
    /// or deleted, or the user explicitly prepares a different/manual target.
    var seriesTodoID: UUID?
    var checkpoint = Date.distantPast
    /// Per-category visual overrides, keyed by lowercased category name. Values keep the
    /// original bare-SF-Symbol format and may also carry a colour palette index, so old
    /// sessions.json files remain compatible while icon and colour can be edited separately.
    var categoryStyles: [String: String] = [:]

    private enum CodingKeys: String, CodingKey {
        case phase, paused, name, startedAt, segmentStart, deadline, remaining, planned,
             segments, rounds, records, todos, activeTodoID, seriesTodoID, checkpoint, categoryStyles
    }

    /// Declaring any init suppresses the implicit memberwise one, and every property has
    /// a default, so this restores the `FocusState()` callers rely on.
    init() {}

    /// Hand-written so `categoryStyles` can be optional on decode. A synthesized decoder
    /// would require the key and fail on every pre-existing sessions.json, which would
    /// surface as a corrupt file and block all timing.
    init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        phase = try v.decode(FocusPhase.self, forKey: .phase)
        paused = try v.decode(Bool.self, forKey: .paused)
        name = try v.decode(String.self, forKey: .name)
        startedAt = try v.decodeIfPresent(Date.self, forKey: .startedAt)
        segmentStart = try v.decodeIfPresent(Date.self, forKey: .segmentStart)
        deadline = try v.decodeIfPresent(Date.self, forKey: .deadline)
        remaining = try v.decode(TimeInterval.self, forKey: .remaining)
        planned = try v.decode(TimeInterval.self, forKey: .planned)
        segments = try v.decode([FocusSegment].self, forKey: .segments)
        rounds = try v.decode(Int.self, forKey: .rounds)
        records = try v.decode([FocusRecord].self, forKey: .records)
        todos = try v.decodeIfPresent([FocusTodo].self, forKey: .todos) ?? []
        activeTodoID = try v.decodeIfPresent(UUID.self, forKey: .activeTodoID)
        seriesTodoID = try v.decodeIfPresent(UUID.self, forKey: .seriesTodoID)
        // Compatibility for states written before seriesTodoID existed. A live work can
        // reuse its active link; finished/rest states can reuse the newest record's link.
        if seriesTodoID == nil {
            if phase == .work {
                seriesTodoID = activeTodoID
            } else if phase == .workFinished || phase == .rest || phase == .restFinished {
                seriesTodoID = records.first?.todoID
            }
        }
        checkpoint = try v.decode(Date.self, forKey: .checkpoint)
        categoryStyles = try v.decodeIfPresent([String: String].self, forKey: .categoryStyles) ?? [:]
    }

    var allTags: [String] {
        FocusRecord.normalizedTags(records.flatMap(\.tags)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Categories that ACTUALLY serve as some record's primary tag — the "已有主分类"
    /// menu. Distinct from `allTags` by design: an ordinary secondary tag must not show
    /// up as a category choice unless a record really counts towards it (the editor's
    /// two menus keep the two meanings apart). Records with no tags contribute nothing:
    /// "未分类" is the display form of an empty tag list, never a selectable category
    /// (rejected design, see HANDOFF). Dedupe and spelling reuse `normalizedTags`; the
    /// sort matches `allTags`. Derived, not stored — no Codable or migration change.
    /// (Contract completed locally 2026-09-30: the external AI's Drive-side State.swift
    /// never arrived; View/MainWindow referenced this, so the derivation is reconstructed
    /// from their described intent and call sites. If their file syncs in later, diff it.)
    var allCategories: [String] {
        FocusRecord.normalizedTags(records.compactMap { $0.tags.first })
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func filteredRecords(tag: String?) -> [FocusRecord] {
        guard let tag = tag else { return records }
        return records.filter { $0.hasTag(tag) }
    }

    var pendingTodos: [FocusTodo] { todos.filter { !$0.isCompleted } }

    func focusSeconds(forTodo id: UUID) -> TimeInterval {
        records.filter { $0.todoID == id }.reduce(0) { $0 + $1.seconds }
    }

    @discardableResult
    mutating func addTodo(title: String, at now: Date) -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let todo = FocusTodo(title: trimmed, createdAt: now)
        todos.append(todo)
        return todo.id
    }

    mutating func renameTodo(id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].title = trimmed
    }

    mutating func toggleTodo(id: UUID, at now: Date) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isCompleted.toggle()
        todos[index].completedAt = todos[index].isCompleted ? now : nil
        // Completing a task means the NEXT round should not keep inheriting it. Preserve
        // activeTodoID so a currently running focus still records the task it started from.
        if todos[index].isCompleted, seriesTodoID == id { seriesTodoID = nil }
    }

    mutating func deleteTodo(id: UUID) {
        todos.removeAll { $0.id == id }
        if activeTodoID == id { activeTodoID = nil }
        if seriesTodoID == id { seriesTodoID = nil }
    }

    /// Reorder by identity so drag/drop remains stable even when completion state changes.
    mutating func moveTodo(id: UUID, before targetID: UUID?) {
        guard id != targetID, let source = todos.firstIndex(where: { $0.id == id }) else { return }
        let item = todos.remove(at: source)
        guard let targetID = targetID,
              let target = todos.firstIndex(where: { $0.id == targetID }) else {
            todos.append(item)
            return
        }
        todos.insert(item, at: target)
    }

    /// `categoryStyles` defaults to nil so callers that only rename or retag leave the
    /// icon overrides untouched.
    ///
    /// `expected` is the record snapshot the editor loaded when it opened. When present,
    /// a mismatch in name or tags against the stored record means another surface saved
    /// this record in the meantime, and this draft would silently revert it (a lost
    /// update) — refuse the write instead. Style-only edits never trip it: overrides live
    /// in `categoryStyles`, and P13's key-level delta merge already makes them concurrent
    /// safe without touching these two fields.
    mutating func editRecord(id: UUID, name: String, tags: [String],
                             styleChanges: [String: String?]? = nil,
                             expected: FocusRecord? = nil) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RecordEditError.emptyName }
        guard let index = records.firstIndex(where: { $0.id == id }) else { throw RecordEditError.missingRecord }
        if let expected = expected {
            let current = records[index]
            guard current.name == expected.name, current.tags == expected.tags else {
                throw RecordEditError.concurrentEdit
            }
        }
        let known = allTags
        let canonicalTags = FocusRecord.normalizedTags(tags).map { tag in
            known.first { $0.caseInsensitiveCompare(tag) == .orderedSame } ?? tag
        }
        records[index].name = trimmed
        records[index].tags = canonicalTags
        // Merge only the keys this edit touched, so two editors holding separate drafts
        // cannot wipe each other's saved overrides (P13). Keys are re-spelled to the
        // canonical tag before storage, because caseInsensitiveCompare and lowercased()
        // disagree on Unicode pairs such as Straße/STRASSE (P12).
        if let styleChanges = styleChanges {
            for (key, value) in styleChanges {
                let canonical = canonicalTags.first { $0.caseInsensitiveCompare(key) == .orderedSame } ?? key
                let storageKey = canonical.lowercased()
                if let value = value { categoryStyles[storageKey] = value }
                else { categoryStyles.removeValue(forKey: storageKey) }
            }
        }
    }

    /// Whether an active category filter still matches anything. The overview filters by
    /// the primary tag (the statistics category) while history and the popover filter by
    /// any tag, so the test differs per surface. It lives here, not inside the SwiftUI
    /// view, so both semantics are testable — a stale-filter bug there is invisible to
    /// the whole domain suite otherwise.
    func categoryFilterStillMatches(_ category: String, primaryOnly: Bool) -> Bool {
        if primaryOnly {
            return records.contains { $0.category.caseInsensitiveCompare(category) == .orderedSame }
        }
        return records.contains { $0.hasTag(category) }
    }

    /// Resolve the raw style payload for a category: exact lowercased key first, then a
    /// case-insensitive scan. The scan is the alias fallback that keeps an override
    /// written from a draft spelling reachable after the tag is canonicalized on save.
    private static func styleValue(in styles: [String: String], forCategory category: String) -> String? {
        let key = category.lowercased()
        if let exact = styles[key] { return exact }
        return styles.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }

    /// `categoryStyles` originally stored a bare SF Symbol name (for example `star`).
    /// Newer values may also carry a colour palette index as `symbol|index`; `@auto`
    /// means keep the automatic symbol while overriding only the colour. Keeping the
    /// legacy bare-symbol form avoids a migration and preserves existing sessions.json.
    static func styleSymbol(in styles: [String: String], forCategory category: String) -> String? {
        guard let raw = styleValue(in: styles, forCategory: category) else { return nil }
        let parts = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return raw }
        return parts[0] == "@auto" ? nil : String(parts[0])
    }

    static func styleColorIndex(in styles: [String: String], forCategory category: String) -> Int? {
        guard let raw = styleValue(in: styles, forCategory: category) else { return nil }
        let parts = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let index = Int(parts[1]), index >= 0 else { return nil }
        return index
    }

    /// Compose the compact, backwards-compatible payload used by `categoryStyles`.
    /// Symbol-only overrides keep the old exact representation so existing tests and
    /// saved data remain stable; a colour-only override uses the `@auto` sentinel.
    static func composedStyle(symbol: String?, colorIndex: Int?) -> String? {
        if let symbol = symbol, let colorIndex = colorIndex { return "\(symbol)|\(colorIndex)" }
        if let symbol = symbol { return symbol }
        if let colorIndex = colorIndex { return "@auto|\(colorIndex)" }
        return nil
    }

    static func hasStyleOverride(in styles: [String: String], forCategory category: String) -> Bool {
        styleValue(in: styles, forCategory: category) != nil
    }

    /// Deletes by UUID only — never by index or name, both of which shift as the list
    /// changes. Touches `records` and nothing else, so the running timer, pause state,
    /// round count and rest schedule are untouched by construction rather than by
    /// remembering to restore them.
    mutating func deleteRecord(id: UUID) throws {
        guard let index = records.firstIndex(where: { $0.id == id }) else { throw RecordEditError.missingRecord }
        records.remove(at: index)
    }

    var isTiming: Bool { phase == .work || phase == .rest }
    var needsAttention: Bool { phase == .workFinished || phase == .restFinished }
    func timeLeft(at now: Date) -> TimeInterval {
        max(0, deadline?.timeIntervalSince(now) ?? remaining)
    }

    mutating func startWork(name: String, seconds: TimeInterval, todoID: UUID? = nil, at now: Date) {
        guard phase == .idle || phase == .restFinished else { return }
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if self.name.isEmpty { self.name = "未命名专注" }
        // An explicit task selection wins. Otherwise only a rest-finished round inherits
        // the existing series; a fresh idle start never accidentally revives stale context.
        let resolvedTodoID = todoID ?? (phase == .restFinished ? seriesTodoID : nil)
        activeTodoID = resolvedTodoID
        seriesTodoID = resolvedTodoID
        phase = .work
        startedAt = now
        segments = []
        begin(seconds: seconds, at: now)
    }

    mutating func startRest(seconds: TimeInterval, at now: Date) {
        guard phase == .workFinished else { return }
        phase = .rest
        begin(seconds: seconds, at: now)
    }

    private mutating func begin(seconds: TimeInterval, at now: Date) {
        planned = max(1, seconds)
        remaining = planned
        deadline = now.addingTimeInterval(planned)
        segmentStart = phase == .work ? now : nil
        paused = false
        checkpoint = now
    }

    mutating func tick(at now: Date) {
        guard isTiming, !paused, let end = deadline, now >= end else { return }
        if phase == .work {
            closeSegment(at: end)
            addRecord(completed: true, at: end)
            rounds += 1
            phase = .workFinished
        } else {
            phase = .restFinished
        }
        remaining = 0
        deadline = nil
        paused = false
    }

    mutating func pause(at now: Date) {
        tick(at: now)
        guard isTiming, !paused else { return }
        remaining = timeLeft(at: now)
        closeSegment(at: now)
        deadline = nil
        paused = true
    }

    mutating func resume(at now: Date) {
        guard isTiming, paused else { return }
        deadline = now.addingTimeInterval(remaining)
        if phase == .work { segmentStart = now }
        paused = false
    }

    mutating func stop(at now: Date) {
        tick(at: now)
        if phase == .work {
            closeSegment(at: now)
            addRecord(completed: false, at: now)
        }
        phase = .idle
        deadline = nil
        segmentStart = nil
        remaining = 0
        paused = false
        activeTodoID = nil
        seriesTodoID = nil
        rounds = 0
    }

    /// Aborts the running focus without keeping anything. Unlike stop, no record is
    /// written and `rounds` survives: an abandoned session was never a completed round,
    /// so the rest schedule stays untouched. Paused work is included — `paused` is only
    /// a flag, `phase` stays `.work`.
    mutating func cancel(at now: Date) {
        guard phase == .work else { return }
        phase = .idle
        startedAt = nil
        segments = []
        activeTodoID = nil
        seriesTodoID = nil
        deadline = nil
        segmentStart = nil
        remaining = 0
        paused = false
        checkpoint = now
    }

    /// Never count time while the application was not running as focused work.
    mutating func recover() {
        if isTiming && !paused { pause(at: checkpoint) }
    }

    private mutating func closeSegment(at now: Date) {
        guard let start = segmentStart else { return }
        let end = max(start, min(now, deadline ?? now))
        if end > start { segments.append(FocusSegment(start: start, end: end)) }
        segmentStart = nil
    }

    private mutating func addRecord(completed: Bool, at now: Date) {
        guard let start = startedAt else { return }
        records.insert(FocusRecord(id: UUID(), name: name, startedAt: start, endedAt: now,
                                   plannedSeconds: planned, completed: completed, segments: segments,
                                   todoID: activeTodoID), at: 0)
        startedAt = nil
        segments = []
        activeTodoID = nil
    }
}

enum RecordEditError: LocalizedError {
    case emptyName, missingRecord, concurrentEdit
    var errorDescription: String? {
        switch self {
        case .emptyName: return "事件名称不能为空。"
        case .missingRecord: return "这条记录已不存在，请重新打开记录列表。"
        case .concurrentEdit: return "这条记录刚在另一个窗口被修改。请关闭编辑器并重新打开，以免覆盖对方的修改。"
        }
    }
}
