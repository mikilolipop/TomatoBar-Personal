import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name { static let startStopTimer = Self("startStopTimer") }

struct TBPopoverView: View {
    @ObservedObject var timer: TBTimer
    @State private var tab = 0
    @State private var editingRecord: FocusRecord?
    @State private var selectedTag: String?
    @State private var showCancelConfirm = false
    // Opening the cancel dialog freezes the clock: otherwise the timer could hit zero
    // behind the modal, addRecord fires, and 「放弃这段」 silently no-ops (phase is no
    // longer .work) leaving exactly the record the user just tried to discard.
    @State private var cancelWasPaused = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("番茄钟").font(.headline)
                Spacer()
                Text(timer.phaseLabel).font(.caption).foregroundColor(.secondary)
            }
            if timer.state.phase == .idle || timer.state.phase == .restFinished {
                TextField("这次准备做什么？", text: $timer.eventName)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("事件名称")
            } else {
                Text(timer.state.name).font(.subheadline).lineLimit(2)
            }
            if timer.state.isTiming {
                Text(timer.timeLeft).font(.system(size: 40, weight: .medium, design: .rounded).monospacedDigit())
                    .frame(maxWidth: .infinity)
                // macOS buttons never stretch their capsule for a frame on the Button
                // itself — the label must carry the maxWidth for the background to follow.
                VStack(spacing: 8) {
                    Button { timer.togglePause() } label: {
                        Text(timer.state.paused ? "继续" : "暂停").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    HStack(spacing: 8) {
                        Button { timer.stop() } label: {
                            Text(timer.state.phase == .work ? "结束并记录" : "结束休息").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                        if timer.state.phase == .work {
                            Button {
                                cancelWasPaused = timer.state.paused
                                if !timer.state.paused { timer.pause() }
                                showCancelConfirm = true
                            } label: {
                                Text("取消专注").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered).foregroundColor(Garden.muted)
                                .help("丢弃这段专注，不保存为记录")
                        }
                    }
                }
            } else if timer.state.needsAttention {
                Button("查看到时提醒") { timer.onAttention?() }
                    .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            } else {
                Button { timer.startWork() } label: {
                    Text("开始专注 · \(timer.workIntervalLength) 分钟").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(timer.storageError != nil)
            }
            HStack {
                Label("今日 \(Int(timer.todaySeconds / 60)) 分钟", systemImage: "clock")
                Spacer()
                Text("完成 \(timer.todayCount) 个番茄")
            }.font(.caption).foregroundColor(.secondary)
            if let error = timer.storageError {
                VStack(alignment: .leading, spacing: 5) {
                    Text(error).foregroundColor(.red)
                    HStack(spacing: 10) {
                        Button(timer.storageRetryTitle) { timer.retryStorage() }
                        Button("打开记录文件夹") { timer.openRecordsFolder() }
                    }
                }.font(.caption)
            }
            Picker("内容", selection: $tab) {
                Text("记录").tag(0)
                Text("时长").tag(1)
                Text("设置").tag(2)
            }.pickerStyle(.segmented).labelsHidden()
            Group {
                if tab == 0 { history }
                else if tab == 1 { intervals }
                else { settings }
            }.frame(height: 320)
            Divider()
            HStack {
                Button("打开主窗口") { TBStatusItem.shared?.showMainWindow() }
                    .buttonStyle(.plain).font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }.buttonStyle(.plain)
            }
        }.padding(18).frame(width: 350)
            .alert("取消这段专注？", isPresented: $showCancelConfirm) {
                Button("继续专注", role: .cancel) { if !cancelWasPaused { timer.togglePause() } }.keyboardShortcut(.cancelAction)
                Button("放弃这段", role: .destructive) { timer.cancel() }
            } message: { Text(cancelFocusMessage(timer.state)) }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let record = editingRecord {
                RecordEditor(record: record, availableTags: timer.state.allTags,
                             styles: timer.state.categoryStyles, onCancel: {
                    editingRecord = nil
                }, onSave: { name, tags, styleChanges in
                    let error = timer.editRecord(id: record.id, name: name, tags: tags, styleChanges: styleChanges)
                    if error == nil { clearStaleFilter(); editingRecord = nil }
                    return error
                }, onDelete: {
                    let error = timer.deleteRecord(id: record.id)
                    if error == nil { clearStaleFilter(); editingRecord = nil }
                    return error
                }).id(record.id)
            } else {
                HStack {
                    Menu {
                        Button("全部记录") { selectedTag = nil }
                        ForEach(timer.state.allTags, id: \.self) { tag in
                            Button(tag) { selectedTag = tag }
                        }
                    } label: {
                        Label(selectedTag ?? "全部记录", systemImage: "line.3.horizontal.decrease.circle")
                            .lineLimit(1)
                    }.menuStyle(.borderlessButton)
                    Spacer()
                    Text("\(timer.state.filteredRecords(tag: selectedTag).count) 条")
                        .font(.caption).foregroundColor(.secondary)
                }
                if timer.state.filteredRecords(tag: selectedTag).isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "list.bullet.clipboard").font(.title).foregroundColor(.secondary)
                        Text(selectedTag == nil ? "还没有专注记录" : "这个标签下还没有记录")
                        Text("完成后可编辑名称，并添加标签分类。")
                            .font(.caption).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(timer.state.filteredRecords(tag: selectedTag)) { record in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(alignment: .top) {
                                        Text(record.name).font(.subheadline).lineLimit(2)
                                        Spacer()
                                        Text(duration(record.seconds)).font(.subheadline.monospacedDigit())
                                        Button { editingRecord = record } label: {
                                            Image(systemName: "pencil")
                                        }.buttonStyle(.borderless)
                                            .help("编辑名称和标签")
                                            .accessibilityLabel("编辑记录：\(record.name)")
                                    }
                                    if !record.tags.isEmpty {
                                        Text(record.tags.map { "#\($0)" }.joined(separator: "  "))
                                            .font(.caption).foregroundColor(.accentColor).lineLimit(2)
                                    }
                                    HStack {
                                        Text(record.startedAt, style: .date)
                                        Text(record.startedAt, style: .time)
                                        Spacer()
                                        Text(record.completed ? "已完成" : "提前结束")
                                    }.font(.caption2).foregroundColor(.secondary)
                                }
                                Divider()
                            }
                        }
                    }
                }
                Button("打开记录文件夹") { timer.openRecordsFolder() }.font(.caption)
            }
        }
    }
    /// Drop the active filter when the record just edited or deleted was the last one
    /// carrying it, so the list never rests on a tag that no longer exists.
    private func clearStaleFilter() {
        if let tag = selectedTag, !timer.state.records.contains(where: { $0.hasTag(tag) }) {
            selectedTag = nil
        }
    }
    private func duration(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        return "\(value / 60)分\(value % 60)秒"
    }
    private var intervals: some View {
        VStack(spacing: 14) {
            Stepper("专注：\(timer.workIntervalLength) 分钟", value: $timer.workIntervalLength, in: 1...180)
            Stepper("短休息：\(timer.shortRestIntervalLength) 分钟", value: $timer.shortRestIntervalLength, in: 1...60)
            Stepper("长休息：\(timer.longRestIntervalLength) 分钟", value: $timer.longRestIntervalLength, in: 1...60)
            Stepper("每组：\(timer.workIntervalsInSet) 个番茄", value: $timer.workIntervalsInSet, in: 1...10)
            Text("调整时长从下一段计时生效。暂停与休息不计入专注记录。")
                .font(.caption).foregroundColor(.secondary)
            Spacer(minLength: 0)
        }.padding(.top, 4)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            KeyboardShortcuts.Recorder("开始 / 暂停 / 继续", name: .startStopTimer)
            Toggle("菜单栏显示倒计时", isOn: $timer.showTimerInMenuBar)
                .onChange(of: timer.showTimerInMenuBar) { _ in timer.updateStatus() }
            LaunchAtLogin.Toggle("登录时启动")
            Text("到时会显示无声提醒窗口，确认后再继续。电脑睡眠或退出应用时自动暂停。")
                .font(.caption).foregroundColor(.secondary)
            Spacer(minLength: 0)
        }.padding(.top, 4)
    }
}

/// Shared by the popover and the expanded timer so cancelling always warns identically.
/// Deliberately shows no elapsed time: the live focused-so-far figure would drift with
/// pauses, and the point of the dialog is "nothing will be saved", not a measurement.
func cancelFocusMessage(_ state: FocusState) -> String {
    let started = state.startedAt.map { "开始于 \($0.formatted(date: .abbreviated, time: .shortened))" } ?? ""
    return "「\(state.name)」\(started.isEmpty ? "" : "\n\(started)")\n\n取消后，这段专注将被丢弃，不会保存为记录。"
}

struct RecordEditor: View {
    let availableTags: [String]
    let onCancel: () -> Void
    let onSave: (String, [String], [String: String?]) -> String?
    /// Returns an error message, or nil once the deletion has been committed to disk.
    /// The caller dismisses the editor, because it also owns the filter selection that may
    /// need clearing when the deleted record was the last one carrying that tag.
    let onDelete: () -> String?
    private let record: FocusRecord
    @State private var name: String
    @State private var tags: [String]
    @State private var newTag = ""
    @State private var newCategory = ""
    /// Icon overrides edited in this session; committed only when 保存 succeeds, so
    /// cancelling discards them like every other field here.
    /// Snapshot at open, used only to compute the delta on save. Submitting the whole map
    /// would let a second open editor overwrite overrides saved after this one opened.
    private let initialStyles: [String: String]
    @State private var localStyles: [String: String]
    @State private var error: String?
    @State private var confirmDelete = false

    init(record: FocusRecord, availableTags: [String], styles: [String: String],
         onCancel: @escaping () -> Void,
         onSave: @escaping (String, [String], [String: String?]) -> String?,
         onDelete: @escaping () -> String?) {
        self.record = record
        self.availableTags = availableTags
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        self.initialStyles = styles
        _name = State(initialValue: record.name)
        _tags = State(initialValue: record.tags)
        _localStyles = State(initialValue: styles)
    }

    /// Shared with the record-row menu in MainWindowView so deleting from either place
    /// warns identically.
    static func confirmationMessage(for record: FocusRecord) -> String {
        "「\(record.name)」\n\(record.startedAt.formatted(date: .abbreviated, time: .shortened))"
            + " · 专注 \(focusDuration(record.seconds))\n\n删除后，这段专注时长将从统计中移除。"
    }

    private var category: String { tags.first ?? "未分类" }
    private var previewSymbol: String {
        FocusState.styleSymbol(in: localStyles, forCategory: category) ?? Garden.symbol(category)
    }
    private var hasStyleOverride: Bool {
        FocusState.styleSymbol(in: localStyles, forCategory: category) != nil
    }
    /// Only the keys this draft changed, so saving never replays a stale whole-map
    /// snapshot over overrides another editor saved in the meantime.
    private var styleChanges: [String: String?] { RecordEditor.styleDelta(initial: initialStyles, current: localStyles) }

    /// `dict[key] = nil` on a `[Key: Value?]` REMOVES the key instead of storing a nil
    /// value, which silently dropped every "恢复自动图标" removal (the domain layer only
    /// deletes an override when the delta carries the key with a nil value). Removals
    /// must be written as `.some(nil)`. Exposed as a static for bridge-level regression.
    static func styleDelta(initial: [String: String], current: [String: String]) -> [String: String?] {
        var delta: [String: String?] = [:]
        for (key, value) in current where initial[key] != value { delta[key] = value }
        for key in initial.keys where current[key] == nil { delta[key] = .some(nil) }
        return delta
    }
    /// Tags other than the statistics category. The primary is deliberately absent: the
    /// remove button must never be able to change what a record counts towards.
    private var otherTags: [String] { Array(tags.dropFirst()) }
    /// Suggestions the user has not already used, so the menu never lists one twice.
    private var unusedSuggestions: [String] {
        Garden.suggestedCategories.filter { suggested in
            !availableTags.contains { $0.caseInsensitiveCompare(suggested) == .orderedSame }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    Text("编辑记录").font(.headline)
                    TextField("事件名称", text: $name).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("修改事件名称")
                    categorySection
                    otherTagsSection
                }.padding(.bottom, 2)
            }
            if let error = error { Text(error).font(.caption).foregroundColor(.red) }
            HStack(spacing: 8) {
                Button("删除记录", role: .destructive) { confirmDelete = true }
                    .foregroundColor(.red).accessibilityLabel("删除记录：\(record.name)")
                Spacer()
                Button("取消", action: onCancel).keyboardShortcut(.cancelAction)
                Button("保存") {
                    addTag()
                    error = onSave(name, tags, styleChanges)
                }.buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("时长和完成状态保持不变").font(.caption2).foregroundColor(.secondary)
        }
        // role: .destructive keeps macOS from making the delete the default button, and
        // .cancelAction binds Escape to cancelling, so the safe action is the default one.
        .alert("删除这段专注记录？", isPresented: $confirmDelete) {
            // role: .cancel keeps Escape bound to cancelling; defaultAction makes Return
            // cancel too, so the destructive button can never be the keyboard default.
            Button("取消", role: .cancel) {}.keyboardShortcut(.cancelAction)
            Button("删除记录", role: .destructive) { error = onDelete() }
        } message: {
            Text(Self.confirmationMessage(for: record))
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("统计分类").font(.subheadline).fontWeight(.medium)
            HStack(spacing: 8) {
                // Live preview of the day-chart block, so the effect is visible before saving.
                Image(systemName: previewSymbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Garden.paper)
                    .frame(width: 26, height: 26)
                    .background(Garden.color(category).opacity(0.85))
                    .cornerRadius(5).accessibilityHidden(true)
                Menu {
                    if !availableTags.isEmpty {
                        Text("已使用的分类和标签").font(.caption)
                        ForEach(availableTags, id: \.self) { tag in
                            Button(tag) { setCategory(tag) }
                        }
                        Divider()
                    }
                    if !unusedSuggestions.isEmpty {
                        Text("建议分类").font(.caption)
                        ForEach(unusedSuggestions, id: \.self) { tag in
                            Button(tag) { setCategory(tag) }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(category).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                }.menuStyle(.borderlessButton).frame(maxWidth: 150)
                    .help("每条记录只计入一个分类")
                    .accessibilityLabel("统计分类：\(category)")
                Menu {
                    ForEach(Garden.palette) { choice in
                        Button {
                            localStyles[category.lowercased()] = choice.symbol
                        } label: {
                            Label(choice.label, systemImage: choice.symbol)
                        }
                    }
                    Divider()
                    Button("恢复自动图标") { localStyles.removeValue(forKey: category.lowercased()) }
                        .disabled(!hasStyleOverride)
                } label: {
                    Image(systemName: "paintpalette").foregroundColor(Garden.muted)
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .help("为这个分类选一个图标；不选则按分类名自动取")
                    .accessibilityLabel("选择分类图标")
                    .disabled(category == "未分类")
            }
            HStack(spacing: 6) {
                TextField("自定义分类", text: $newCategory).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("自定义分类")
                    .onSubmit { applyCustomCategory() }
                Button("设为分类", action: applyCustomCategory)
                    .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("统计分类决定图表归属和图标；其他标签用于搜索和筛选。")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var otherTagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("其他标签").font(.subheadline).fontWeight(.medium)
            HStack {
                TextField("新标签，例如：学习", text: $newTag).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("新标签").onSubmit { addTag() }
                Button("添加") { addTag() }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            // No "pick an existing tag" menu here: the category picker above already lists
            // every tag in use, and this section's job is the *other* tags. Two menus with
            // identical contents read as a bug. Typing an existing name still reuses it,
            // because normalizedTags dedupes case-insensitively to the known spelling.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 6) {
                ForEach(otherTags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag).lineLimit(1).help(tag)
                        Spacer(minLength: 0)
                        Button { removeOtherTag(tag) } label: {
                            Image(systemName: "xmark.circle.fill")
                        }.buttonStyle(.plain).accessibilityLabel("移除标签：\(tag)")
                    }.font(.caption).padding(5)
                        .background(Color.accentColor.opacity(0.12)).cornerRadius(5)
                }
            }
            if otherTags.isEmpty { Text("没有其他标签").font(.caption).foregroundColor(.secondary) }
        }
    }

    private func setCategory(_ category: String) {
        tags = FocusRecord.tags(withPrimaryCategory: category, in: tags)
    }
    private func applyCustomCategory() {
        setCategory(newCategory)
        newCategory = ""
    }
    /// Only ever touches the tail, so removing a tag cannot silently reassign the record
    /// to a different statistics category.
    private func removeOtherTag(_ tag: String) {
        guard tags.count > 1 else { return }
        tags = [tags[0]] + tags.dropFirst().filter { $0 != tag }
    }
    private func addTag() {
        tags = FocusRecord.normalizedTags(tags + [newTag])
        newTag = ""
    }
}
