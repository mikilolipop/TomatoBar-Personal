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
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 9) {
                GardenArt(name: "PixelTomato", activity: timer.windowActivity)
                    .frame(width: 28, height: 28)
                Text("TomatoBar")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Text(timer.phaseLabel)
                    .font(.caption)
                    .foregroundColor(Garden.muted)
            }

            if timer.state.phase == .idle || timer.state.phase == .restFinished {
                TextField("这次准备做什么？", text: $timer.eventName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.58)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Garden.line, lineWidth: 1))
                    .accessibilityLabel("事件名称")
            } else {
                Text(timer.state.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(2)
            }

            if timer.state.isTiming {
                Text(timer.timeLeft)
                    .font(.system(size: 40, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(Garden.red)
                    .frame(maxWidth: .infinity)
                VStack(spacing: 8) {
                    Button { timer.togglePause() } label: {
                        Text(timer.state.paused ? "继续" : "暂停").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Garden.red)
                    HStack(spacing: 8) {
                        Button { timer.stop() } label: {
                            Text(timer.state.phase == .work ? "结束并记录" : "结束休息")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                        if timer.state.phase == .work {
                            Button {
                                cancelWasPaused = timer.state.paused
                                if timer.freezeForCancel() { showCancelConfirm = true }
                            } label: {
                                Text("取消专注").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(Garden.muted)
                            .help("丢弃这段专注，不保存为记录")
                        }
                    }
                }
            } else if timer.state.needsAttention {
                Button("查看到时提醒") { timer.onAttention?() }
                    .buttonStyle(.borderedProminent)
                    .tint(Garden.red)
                    .frame(maxWidth: .infinity)
            } else {
                Button { timer.startWork() } label: {
                    Text("开始专注 · \(timer.workIntervalLength) 分钟")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Garden.red)
                .disabled(timer.storageError != nil)
            }

            HStack {
                Label("今日 \(Int(timer.todaySeconds / 60)) 分钟", systemImage: "clock")
                Spacer()
                Text("完成 \(timer.todayCount) 个番茄")
            }
            .font(.caption)
            .foregroundColor(Garden.muted)

            if let error = timer.storageError {
                VStack(alignment: .leading, spacing: 5) {
                    Text(error).foregroundColor(Garden.red)
                    HStack(spacing: 10) {
                        Button(timer.storageRetryTitle) { timer.retryStorage() }
                        Button("打开记录文件夹") { timer.openRecordsFolder() }
                    }
                }.font(.caption)
            }

            HStack(spacing: 3) {
                popoverTab("记录", value: 0)
                popoverTab("时长", value: 1)
                popoverTab("设置", value: 2)
            }
            .padding(3)
            .background(Garden.line.opacity(0.30))
            .cornerRadius(9)

            Group {
                if tab == 0 { history }
                else if tab == 1 { intervals }
                else { settings }
            }.frame(height: 320)

            Rectangle().fill(Garden.line.opacity(0.7)).frame(height: 1)
            HStack {
                Button("打开主窗口") { TBStatusItem.shared?.showMainWindow() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(Garden.muted)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundColor(Garden.ink)
            }
        }
        .padding(18)
        .frame(width: 350)
        .background(Garden.paper)
        .foregroundColor(Garden.ink)
        .accentColor(Garden.red)
        .preferredColorScheme(.light)
        .alert("取消这段专注？", isPresented: $showCancelConfirm) {
            Button("继续专注", role: .cancel) { if !cancelWasPaused { timer.togglePause() } }
                .keyboardShortcut(.cancelAction)
            Button("放弃这段", role: .destructive) { timer.cancel() }
        } message: { Text(cancelFocusMessage(timer.state)) }
        // P16: the other window's edit or delete can empty out the tag this filter
        // points at. Re-check it whenever the shared record list changes, not only
        // after this view's own save.
        .onChange(of: timer.state.records) { _ in clearStaleFilter() }
    }

    private func popoverTab(_ title: String, value: Int) -> some View {
        Button { tab = value } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(tab == value ? Garden.paper : Garden.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(tab == value ? Garden.red : Color.clear)
                .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let record = editingRecord {
                RecordEditor(record: record, availableCategories: timer.state.allCategories,
                             styles: timer.state.categoryStyles, onCancel: {
                    editingRecord = nil
                }, onSave: { name, tags, styleChanges in
                    // `record` is the snapshot this editor opened with; passing it as
                    // `expected` makes a stale draft refuse instead of silently reverting
                    // the other window's saved change (P26 lost-update guard).
                    let error = timer.editRecord(id: record.id, name: name, tags: tags, styleChanges: styleChanges, expected: record)
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
                            .foregroundColor(Garden.ink)
                    }.menuStyle(.borderlessButton)
                    Spacer()
                    Text("\(timer.state.filteredRecords(tag: selectedTag).count) 条")
                        .font(.caption).foregroundColor(Garden.muted)
                }
                if timer.state.filteredRecords(tag: selectedTag).isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.title).foregroundColor(Garden.muted)
                        Text(selectedTag == nil ? "还没有专注记录" : "这个标签下还没有记录")
                        Text("完成后可编辑名称，并添加分类或标签。")
                            .font(.caption).foregroundColor(Garden.muted)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(timer.state.filteredRecords(tag: selectedTag)) { record in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(alignment: .top) {
                                        Text(record.name).font(.subheadline).lineLimit(2)
                                        Spacer()
                                        Text(duration(record.seconds)).font(.subheadline.monospacedDigit())
                                        Button { editingRecord = record } label: {
                                            Image(systemName: "pencil")
                                        }.buttonStyle(.borderless)
                                            .foregroundColor(Garden.muted)
                                            .help("编辑名称和标签")
                                            .accessibilityLabel("编辑记录：\(record.name)")
                                    }
                                    if !record.tags.isEmpty {
                                        Text(record.tags.map { "#\($0)" }.joined(separator: "  "))
                                            .font(.caption).foregroundColor(Garden.red).lineLimit(2)
                                    }
                                    HStack {
                                        Text(record.startedAt, style: .date)
                                        Text(record.startedAt, style: .time)
                                        Spacer()
                                        Text(record.completed ? "已完成" : "提前结束")
                                    }.font(.caption2).foregroundColor(Garden.muted)
                                }
                                .padding(.vertical, 10)
                                Rectangle().fill(Garden.line.opacity(0.65)).frame(height: 1)
                            }
                        }
                    }
                }
                Button("打开记录文件夹 →") { timer.openRecordsFolder() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(Garden.muted)
            }
        }
    }

    /// Drop the active filter when the record just edited or deleted was the last one
    /// carrying it, so the list never rests on a tag that no longer exists. The popover
    /// filters by ANY tag, so this asks the shared predicate for the primaryOnly=false
    /// semantics (same one the main window uses for its overview, P14/P16).
    private func clearStaleFilter() {
        if let tag = selectedTag, !timer.state.categoryFilterStillMatches(tag, primaryOnly: false) {
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
                .font(.caption).foregroundColor(Garden.muted)
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
                .font(.caption).foregroundColor(Garden.muted)
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
    let availableCategories: [String]
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

    init(record: FocusRecord, availableCategories: [String], styles: [String: String],
         onCancel: @escaping () -> Void,
         onSave: @escaping (String, [String], [String: String?]) -> String?,
         onDelete: @escaping () -> String?) {
        self.record = record
        self.availableCategories = availableCategories
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
    private var previewColor: Color {
        Garden.color(category, styles: localStyles)
    }
    private var hasStyleOverride: Bool {
        FocusState.hasStyleOverride(in: localStyles, forCategory: category)
    }
    private var currentSymbolOverride: String? {
        FocusState.styleSymbol(in: localStyles, forCategory: category)
    }
    private var currentColorIndex: Int? {
        FocusState.styleColorIndex(in: localStyles, forCategory: category)
    }
    private var menuChevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 12, height: 12)
    }
    private func setStyle(symbol: String?, colorIndex: Int?) {
        let key = category.lowercased()
        if let value = FocusState.composedStyle(symbol: symbol, colorIndex: colorIndex) {
            localStyles[key] = value
        } else {
            localStyles.removeValue(forKey: key)
        }
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
    /// Suggestions not already used as a primary category. Ordinary secondary tags stay
    /// out of this menu so "主分类" and "其他标签" keep distinct meanings.
    private var unusedSuggestions: [String] {
        Garden.suggestedCategories.filter { suggested in
            !availableCategories.contains { $0.caseInsensitiveCompare(suggested) == .orderedSame }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("主分类").font(.subheadline).fontWeight(.medium)
                Spacer()
                Text(category == "未分类" ? "设置后可自定义图标" : (hasStyleOverride ? "已自定义样式" : "自动样式"))
                    .font(.caption2)
                    .foregroundColor(Garden.muted)
            }

            HStack(spacing: 10) {
                // The icon itself is the one and only icon-editing affordance. The old
                // separate paint-palette button made the preview and the action look like
                // two unrelated controls even though they represented the same setting.
                Menu {
                    Menu("图标") {
                        Button("使用自动图标") {
                            setStyle(symbol: nil, colorIndex: currentColorIndex)
                        }.disabled(currentSymbolOverride == nil)
                        Divider()
                        ForEach(Garden.palette) { choice in
                            Button {
                                setStyle(symbol: choice.symbol, colorIndex: currentColorIndex)
                            } label: {
                                Label(choice.label, systemImage: choice.symbol)
                            }
                        }
                    }
                    Menu("颜色") {
                        Button("使用自动颜色") {
                            setStyle(symbol: currentSymbolOverride, colorIndex: nil)
                        }.disabled(currentColorIndex == nil)
                        Divider()
                        ForEach(Array(Garden.colorNames.enumerated()), id: \.offset) { index, label in
                            Button {
                                setStyle(symbol: currentSymbolOverride, colorIndex: index)
                            } label: {
                                Label(label, systemImage: currentColorIndex == index ? "checkmark.circle.fill" : "circle.fill")
                            }
                        }
                    }
                    if hasStyleOverride {
                        Divider()
                        Button("恢复全部自动") {
                            setStyle(symbol: nil, colorIndex: nil)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: previewSymbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Garden.paper)
                            .frame(width: 34, height: 34)
                            .background(previewColor.opacity(0.85))
                            .cornerRadius(7)
                        menuChevron
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(category == "未分类" ? "先设置主分类，再自定义样式" : "点击修改这个分类的图标和颜色")
                .accessibilityLabel(category == "未分类" ? "未分类，设置主分类后可修改样式" : "修改主分类图标和颜色")
                .disabled(category == "未分类")

                Menu {
                    if !availableCategories.isEmpty {
                        Text("已有主分类").font(.caption)
                        ForEach(availableCategories, id: \.self) { item in
                            Button(item) { setCategory(item) }
                        }
                    }
                    if !availableCategories.isEmpty && !unusedSuggestions.isEmpty { Divider() }
                    if !unusedSuggestions.isEmpty {
                        Text("建议分类").font(.caption)
                        ForEach(unusedSuggestions, id: \.self) { item in
                            Button(item) { setCategory(item) }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(category).lineLimit(1)
                        menuChevron
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Garden.line.opacity(0.22)))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(maxWidth: 190, alignment: .leading)
                .help("每条记录只计入一个主分类")
                .accessibilityLabel("主分类：\(category)")
                Spacer(minLength: 0)
            }

            Text("自定义分类").font(.caption).foregroundColor(Garden.muted)
            HStack(spacing: 6) {
                TextField("例如：科研", text: $newCategory).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("自定义主分类")
                    .onSubmit { applyCustomCategory() }
                Button("设为主分类", action: applyCustomCategory)
                    .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("主分类决定图表归属与显示图标；其他标签仅用于搜索和筛选。")
                .font(.caption).foregroundColor(Garden.muted)
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
            // Secondary tags stay deliberately free-form. They do not appear in the
            // primary-category menu unless some record actually uses them as its first tag.
            // The domain layer still canonicalizes spelling against existing tags on save.
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
            if otherTags.isEmpty { Text("没有其他标签 · 仅用于搜索和筛选").font(.caption).foregroundColor(Garden.muted) }
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
