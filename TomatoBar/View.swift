import AppKit
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name { static let startStopTimer = Self("startStopTimer") }

struct GardenPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Garden.paper)
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: Garden.cornerMedium)
                    .fill(Garden.red.opacity(configuration.isPressed ? 0.84 : 1.0))
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct GardenSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Garden.ink)
            .frame(maxWidth: .infinity, minHeight: 36)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: Garden.cornerMedium)
                    .fill(Garden.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Garden.cornerMedium)
                    .stroke(Garden.line.opacity(0.82), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

/// Shared numeric setting row used by both the menu-bar popover and the main settings
/// sheet. Direct typing is much faster than walking a Stepper one minute at a time.
struct GardenNumberInputRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    @State private var draft: String
    // SwiftUI wrapper must stay module-qualified: the domain type `FocusState`
    // (State.swift) shadows it inside this module.
    @SwiftUI.FocusState private var isFocused: Bool

    init(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) {
        self.title = title
        self._value = value
        self.range = range
        self.unit = unit
        _draft = State(initialValue: String(value.wrappedValue))
    }

    private func commitDraft() {
        guard let parsed = Int(draft.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            draft = String(value)
            return
        }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        value = clamped
        draft = String(clamped)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            TextField("", text: $draft)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .focused($isFocused)
                .onSubmit { commitDraft() }
                .onChange(of: isFocused) { focused in
                    if !focused { commitDraft() }
                }
                .onChange(of: value) { newValue in
                    if !isFocused { draft = String(newValue) }
                }
                .accessibilityLabel(title)
                .accessibilityValue("\(value)\(unit)")
            Text(unit)
                .foregroundColor(Garden.muted)
                .frame(width: 48, alignment: .leading)
        }
        .font(.system(size: 13))
    }
}

struct TBPopoverView: View {
    @ObservedObject var timer: TBTimer
    @State private var tab = 0
    @AppStorage("popoverTabsCollapsed") private var isTabsCollapsed = true
    @State private var editingRecord: FocusRecord?
    @State private var selectedTag: String?
    @State private var showCancelConfirm = false
    @State private var quickTodoTitle = ""
    // Opening the cancel dialog freezes the clock: otherwise the timer could hit zero
    // behind the modal, addRecord fires, and 「放弃这段」 silently no-ops (phase is no
    // longer .work) leaving exactly the record the user just tried to discard.
    @State private var cancelWasPaused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                GardenArt(name: "PixelTomato", activity: timer.windowActivity)
                    .frame(width: 30, height: 30)
                Text("TomatoBar")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Text(timer.phaseLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Garden.muted)
            }

            if timer.state.phase == .idle || timer.state.phase == .restFinished {
                focusTargetSelection
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(timer.state.name)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(2)
                        if !timer.state.activeTags.isEmpty {
                            Text(timer.state.activeTags.map { "#\($0)" }.joined(separator: " "))
                                .font(.caption2)
                                .foregroundColor(Garden.color(timer.state.activeTags.first ?? "", styles: timer.state.categoryStyles))
                        }
                    }
                }
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
                    .buttonStyle(GardenPrimaryButtonStyle())
                    HStack(spacing: 8) {
                        Button {
                            if timer.state.phase == .rest {
                                timer.skipRest()
                            } else {
                                timer.stop()
                            }
                        } label: {
                            Text(timer.state.phase == .work ? "结束并记录" : "跳过休息")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(GardenSecondaryButtonStyle())
                        if timer.state.phase == .rest {
                            Button { timer.stop() } label: {
                                Text("结束本组").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GardenSecondaryButtonStyle())
                            .foregroundColor(Garden.muted)
                            .help("结束当前这一组番茄钟")
                        }
                        if timer.state.phase == .work {
                            Button {
                                cancelWasPaused = timer.state.paused
                                if timer.freezeForCancel() { showCancelConfirm = true }
                            } label: {
                                Text("取消专注").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GardenSecondaryButtonStyle())
                            .foregroundColor(Garden.muted)
                            .help("丢弃这段专注，不保存为记录")
                        }
                    }
                }
            } else if timer.state.needsAttention {
                Button("查看到时提醒") { timer.onAttention?() }
                    .buttonStyle(GardenPrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
            } else {
                Button { timer.startWork() } label: {
                    Text("开始专注 · \(timer.workIntervalLength) 分钟")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GardenPrimaryButtonStyle())
                .disabled(timer.storageError != nil)
            }

            HStack {
                Label("今日 \(Int(timer.todaySeconds / 60)) 分钟", systemImage: "clock")
                Spacer()
                Text("完成 \(timer.todayCount) 个番茄")
            }
            .font(.system(size: 12))
            .foregroundColor(Garden.muted)
            .padding(.horizontal, 2)

            if canPrepareNext && editingRecord == nil {
                nextTodoSection
            }

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
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isTabsCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: (isTabsCollapsed && editingRecord == nil) ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Garden.muted)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help((isTabsCollapsed && editingRecord == nil) ? "展开面板" : "折叠面板")
                .accessibilityLabel((isTabsCollapsed && editingRecord == nil) ? "展开面板" : "折叠面板")
            }
            .padding(3)
            .background(Garden.line.opacity(0.30))
            .cornerRadius(Garden.cornerMedium)

            if !isTabsCollapsed || editingRecord != nil {
                Group {
                    if tab == 0 { history }
                    else if tab == 1 { intervals }
                    else { settings }
                // Editing needs its own space; keeping the next-task list above it squeezed
                // the category controls into a tiny second scroll area.
                }.frame(height: editingRecord != nil ? 380 : canPrepareNext ? 235 : 320)
            }

            Rectangle().fill(Garden.line.opacity(0.7)).frame(height: 1)
            HStack {
                Button { TBStatusItem.shared?.showMainWindow() } label: {
                    Label("打开主窗口", systemImage: "macwindow")
                        .font(.caption)
                }
                    .buttonStyle(.plain)
                    .foregroundColor(Garden.muted)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(Garden.muted)
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

    private var focusTargetSelection: some View {
        Group {
            if let current = timer.state.currentTodo {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .foregroundColor(Garden.red)
                        .font(.system(size: 15, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("当前任务")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Garden.red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Garden.red.opacity(0.12))
                                .cornerRadius(4)
                            if !current.tags.isEmpty {
                                Text(current.tags.map { "#\($0)" }.joined(separator: " "))
                                    .font(.caption2)
                                    .foregroundColor(Garden.color(current.tags.first ?? "", styles: timer.state.categoryStyles))
                            }
                            let secs = timer.state.focusSeconds(forTodo: current.id)
                            if secs > 0 {
                                Text("已专注 \(focusDuration(secs))")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(Garden.muted)
                            }
                        }
                        Text(current.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    Spacer()
                    Menu {
                        Button("切回自由专注") { timer.selectCurrentTodo(nil) }
                        Divider()
                        if timer.state.pendingTodos.count > 1 {
                            Text("切换到其他待办：")
                            ForEach(timer.state.pendingTodos.filter { $0.id != current.id }) { todo in
                                Button(todo.title) { timer.selectCurrentTodo(todo.id) }
                            }
                            Divider()
                        }
                        Menu("设置任务标签") {
                            if !current.tags.isEmpty {
                                Button("清除标签") { timer.setTodoTags(id: current.id, tags: []) }
                                Divider()
                            }
                            if !timer.state.knownTags.isEmpty {
                                Text("已有标签")
                                ForEach(timer.state.knownTags, id: \.self) { tag in
                                    Button(tag) { timer.setTodoTags(id: current.id, tags: [tag]) }
                                }
                                Divider()
                            }
                            Text("常用建议")
                            ForEach(Garden.suggestedCategories, id: \.self) { tag in
                                Button(tag) { timer.setTodoTags(id: current.id, tags: [tag]) }
                            }
                        }
                    } label: {
                        GardenActionIcon(name: "ellipsis.circle", pointSize: 14, color: Garden.muted)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 20, height: 20)

                    Button {
                        timer.selectCurrentTodo(nil)
                    } label: {
                        GardenActionIcon(name: "xmark.circle.fill", pointSize: 14, color: Garden.muted)
                    }
                    .buttonStyle(.plain)
                    .help("切回自由专注")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Garden.cornerMedium)
                        .fill(Garden.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Garden.cornerMedium)
                        .stroke(Garden.red.opacity(0.38), lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TextField("这次准备做什么？（支持 #标签）", text: Binding(
                            get: { timer.eventName },
                            set: { timer.setEventName($0) }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 11)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: Garden.cornerMedium)
                                .fill(Garden.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Garden.cornerMedium)
                                .stroke(Garden.line.opacity(0.85), lineWidth: 1)
                        )
                        .accessibilityLabel("事件名称")

                        if !timer.state.pendingTodos.isEmpty {
                            Menu {
                                Text("选择已有待办专注：")
                                ForEach(timer.state.pendingTodos) { todo in
                                    Button {
                                        timer.selectCurrentTodo(todo.id)
                                    } label: {
                                        Text(todo.title)
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "target")
                                        .font(.system(size: 11))
                                    Text("选任务")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .frame(height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: Garden.cornerMedium)
                                        .fill(Garden.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Garden.cornerMedium)
                                        .stroke(Garden.line.opacity(0.85), lineWidth: 1)
                                )
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .foregroundColor(Garden.ink)
                            .help("从待办列表选择当前任务")
                        }
                    }

                    HStack(spacing: 6) {
                        Menu {
                            if !timer.state.draftTags.isEmpty {
                                Button("清除标签") { timer.setDraftTags([]) }
                                Divider()
                            }
                            if !timer.state.knownTags.isEmpty {
                                Text("已有标签")
                                ForEach(timer.state.knownTags, id: \.self) { tag in
                                    Button(tag) {
                                        if timer.state.draftTags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                                            timer.setDraftTags(timer.state.draftTags.filter { $0.caseInsensitiveCompare(tag) != .orderedSame })
                                        } else {
                                            timer.setDraftTags(timer.state.draftTags + [tag])
                                        }
                                    }
                                }
                                Divider()
                            }
                            Text("常用建议")
                            ForEach(Garden.suggestedCategories, id: \.self) { tag in
                                Button(tag) {
                                    if timer.state.draftTags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                                        timer.setDraftTags(timer.state.draftTags.filter { $0.caseInsensitiveCompare(tag) != .orderedSame })
                                    } else {
                                        timer.setDraftTags(timer.state.draftTags + [tag])
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                    .font(.system(size: 10))
                                if timer.state.draftTags.isEmpty {
                                    Text("选择标签")
                                        .font(.system(size: 11))
                                } else {
                                    Text(timer.state.draftTags.map { "#\($0)" }.joined(separator: " "))
                                        .font(.system(size: 11, weight: .medium))
                                }
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(timer.state.draftTags.isEmpty ? Garden.line.opacity(0.2) : Garden.color(timer.state.draftTags.first ?? "", styles: timer.state.categoryStyles).opacity(0.14))
                            )
                            .foregroundColor(timer.state.draftTags.isEmpty ? Garden.muted : Garden.color(timer.state.draftTags.first ?? "", styles: timer.state.categoryStyles))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)

                        Spacer()
                    }
                }
            }
        }
    }

    private var canPrepareNext: Bool {
        timer.state.phase == .idle || timer.state.phase == .restFinished
    }

    private var nextTodoSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("接下来")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(timer.state.pendingTodos.count) 项")
                    .font(.caption2)
                    .foregroundColor(Garden.muted)
            }

            if timer.state.pendingTodos.isEmpty {
                Text("还没有待办。先记下一件想做的事。")
                    .font(.caption)
                    .foregroundColor(Garden.muted)
                    .padding(.vertical, 2)
            } else {
                ForEach(Array(timer.state.pendingTodos.prefix(3))) { todo in
                    let isCurrent = (timer.state.currentTodoID == todo.id || timer.preparedTodoID == todo.id)
                    HStack(spacing: 7) {
                        Button { timer.toggleTodo(id: todo.id) } label: {
                            GardenActionIcon(name: "circle", pointSize: 14)
                        }
                        .buttonStyle(.plain)
                        .help("标记完成")
                        .accessibilityLabel("标记完成：\(todo.title)")

                        Button { timer.selectCurrentTodo(todo.id) } label: {
                            HStack(spacing: 4) {
                                if isCurrent {
                                    Text("🎯")
                                        .font(.system(size: 10))
                                }
                                Text(todo.title)
                                    .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                                    .foregroundColor(Garden.ink)
                                    .lineLimit(1)
                                if !todo.tags.isEmpty {
                                    Text(todo.tags.map { "#\($0)" }.joined(separator: " "))
                                        .font(.system(size: 10))
                                        .foregroundColor(Garden.color(todo.tags.first ?? "", styles: timer.state.categoryStyles))
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .help("设为当前专注任务")

                        Menu {
                            Button("设为当前任务") { timer.selectCurrentTodo(todo.id) }
                            Menu("设置标签") {
                                if !todo.tags.isEmpty {
                                    Button("清除标签") { timer.setTodoTags(id: todo.id, tags: []) }
                                    Divider()
                                }
                                if !timer.state.knownTags.isEmpty {
                                    Text("已有标签")
                                    ForEach(timer.state.knownTags, id: \.self) { tag in
                                        Button(tag) { timer.setTodoTags(id: todo.id, tags: [tag]) }
                                    }
                                    Divider()
                                }
                                Text("常用建议")
                                ForEach(Garden.suggestedCategories, id: \.self) { tag in
                                    Button(tag) { timer.setTodoTags(id: todo.id, tags: [tag]) }
                                }
                            }
                            Divider()
                            Button("标记完成") { timer.toggleTodo(id: todo.id) }
                            Button("删除待办", role: .destructive) { timer.deleteTodo(id: todo.id) }
                        } label: {
                            Color.clear.frame(width: 16, height: 16).contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 16, height: 16)
                        .overlay(GardenActionIcon(name: "ellipsis", pointSize: 11, color: Garden.muted).allowsHitTesting(false))

                        Button {
                            timer.selectCurrentTodo(todo.id)
                            timer.startWork()
                        } label: {
                            GardenActionIcon(name: "play.fill", pointSize: 11, color: Garden.red)
                        }
                        .buttonStyle(.plain)
                        .help("立即开始")
                        .accessibilityLabel("开始待办：\(todo.title)")
                        .disabled(timer.storageError != nil || timer.state.needsAttention || timer.state.isTiming)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .fill(isCurrent ? Garden.red.opacity(0.10) : Garden.surface.opacity(0.72))
                    )
                }
            }

            HStack(spacing: 6) {
                TextField("快速添加待办（支持 #标签）", text: $quickTodoTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .fill(Garden.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .stroke(Garden.line.opacity(0.72), lineWidth: 1)
                    )
                    .onSubmit { addQuickTodo() }
                Button { addQuickTodo() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Garden.paper)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Garden.red))
                }
                .buttonStyle(.plain)
                .disabled(quickTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("快速添加待办")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Garden.cornerMedium)
                .fill(Garden.line.opacity(0.16))
        )
    }

    private func addQuickTodo() {
        let (title, tags) = FocusTodo.parseInput(quickTodoTitle)
        guard !title.isEmpty else { return }
        timer.addTodo(title, tags: tags)
        quickTodoTitle = ""
    }

    private func popoverTab(_ title: String, value: Int) -> some View {
        let isSelected = (!isTabsCollapsed || editingRecord != nil) && tab == value
        return Button {
            if isTabsCollapsed && editingRecord == nil {
                tab = value
                withAnimation(.easeInOut(duration: 0.18)) {
                    isTabsCollapsed = false
                }
            } else if tab == value {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isTabsCollapsed = true
                }
            } else {
                tab = value
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? Garden.paper : Garden.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(isSelected ? Garden.red : Color.clear)
                .cornerRadius(Garden.cornerSmall)
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
                        GardenArt(name: "PixelSprout", activity: timer.windowActivity)
                            .frame(width: 46, height: 35)
                        Text(selectedTag == nil ? "还没有专注记录" : "这个标签下还没有记录")
                            .font(.system(size: 15, weight: .medium))
                        Text(selectedTag == nil ? "完成一段专注后，这里会留下足迹。" : "换个标签看看，或者继续留下一段专注。")
                            .font(.caption)
                            .foregroundColor(Garden.muted)
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
                                            GardenActionIcon(name: "pencil", pointSize: 12)
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
                Button { timer.openRecordsFolder() } label: {
                    Label("打开记录文件夹", systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(Garden.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: Garden.cornerSmall)
                                .fill(Garden.line.opacity(0.24))
                        )
                }
                .buttonStyle(.plain)
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
        VStack(spacing: 12) {
            GardenNumberInputRow(title: "专注", value: $timer.workIntervalLength, range: 1...180, unit: "分钟")
            GardenNumberInputRow(title: "短休息", value: $timer.shortRestIntervalLength, range: 1...60, unit: "分钟")
            GardenNumberInputRow(title: "长休息", value: $timer.longRestIntervalLength, range: 1...60, unit: "分钟")
            GardenNumberInputRow(title: "每组", value: $timer.workIntervalsInSet, range: 1...10, unit: "个番茄")
            Text("可直接输入数字。专注 1–180 分钟，休息 1–60 分钟；调整从下一段生效。")
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

/// A native menu with an explicit mouse target matching the custom label's full frame.
/// SwiftUI's borderless Menu reduces a label to its native title/image, so framing an
/// empty label or drawing a wider overlay does not enlarge the native button itself.
private struct CategoryMenuButton: NSViewRepresentable {
    let selection: String
    let available: [String]
    let suggestions: [String]
    let onSelect: (String) -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.isBordered = false
        // Transparent NSButtons still track mouse/keyboard events. SwiftUI draws the
        // label, while this native view owns the entire 170 x 34 interaction area.
        button.isTransparent = true
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectCategory(_:))
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.onSelect = onSelect
        button.isEnabled = isEnabled
        button.setAccessibilityLabel("主分类：\(selection)")
        button.toolTip = "每条记录只计入一个主分类"
        let menu = NSMenu()
        menu.autoenablesItems = false
        // A pull-down menu reserves its first item for the button's title.
        menu.addItem(NSMenuItem(title: selection, action: nil, keyEquivalent: ""))
        for (heading, categories) in [("已有主分类", available), ("建议分类", suggestions)] where !categories.isEmpty {
            if menu.items.count > 1 { menu.addItem(.separator()) }
            let header = NSMenuItem(title: heading, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for category in categories {
                let item = NSMenuItem(title: category, action: nil, keyEquivalent: "")
                item.representedObject = category
                item.state = category == selection ? .on : .off
                menu.addItem(item)
            }
        }
        button.menu = menu
    }

    final class Coordinator: NSObject {
        var onSelect: (String) -> Void
        init(onSelect: @escaping (String) -> Void) { self.onSelect = onSelect }
        @objc func selectCategory(_ sender: NSPopUpButton) {
            guard let category = sender.selectedItem?.representedObject as? String else { return }
            onSelect(category)
        }
    }
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

    /// macOS Menu can suppress/tint SF Symbols in menu-item labels. Draw the palette chip
    /// as a non-template NSImage so every Garden colour remains visible in the native menu.
    private func colorSwatchImage(index: Int, selected: Bool) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        guard Garden.colors.indices.contains(index) else {
            image.isTemplate = false
            return image
        }

        let rect = NSRect(x: 1, y: 1, width: 12, height: 12)
        let chip = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        Garden.colorPalette[index].nsColor.setFill()
        chip.fill()
        NSColor.black.withAlphaComponent(0.14).setStroke()
        chip.lineWidth = 0.7
        chip.stroke()

        if selected {
            let check = NSBezierPath()
            check.move(to: NSPoint(x: 3.8, y: 7.0))
            check.line(to: NSPoint(x: 6.1, y: 4.8))
            check.line(to: NSPoint(x: 10.2, y: 9.4))
            check.lineWidth = 1.7
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor.white.withAlphaComponent(0.96).setStroke()
            check.stroke()
        }

        image.isTemplate = false
        return image
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
        .foregroundColor(Garden.ink).accentColor(Garden.red).preferredColorScheme(.light)
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
                                Label {
                                    Text(label)
                                } icon: {
                                    Image(nsImage: colorSwatchImage(index: index, selected: currentColorIndex == index))
                                }
                                .labelStyle(.titleAndIcon)
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
                    // Keep the native Menu hit target, but render the visible preview in an
                    // overlay. Borderless macOS menus can restyle their label content and
                    // strip SwiftUI foreground/background styling; the overlay is outside
                    // that label rendering path, so the category colour always stays visible.
                    Color.clear
                        .frame(width: 34, height: 34)
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 34, height: 34)
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(previewColor.opacity(0.85))
                        Image(systemName: previewSymbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Garden.paper)
                    }
                    .allowsHitTesting(false)
                }
                .help(category == "未分类" ? "先设置主分类，再自定义样式" : "点击彩色图标修改图标和颜色")
                .accessibilityLabel(category == "未分类" ? "未分类，设置主分类后可修改样式" : "分类样式，点击修改图标和颜色")
                .disabled(category == "未分类")

                CategoryMenuButton(selection: category, available: availableCategories,
                                   suggestions: unusedSuggestions, onSelect: setCategory)
                .frame(width: 170, height: 34)
                .overlay {
                    HStack(spacing: 6) {
                        Text(category).font(.system(size: 13)).lineLimit(1)
                        Spacer(minLength: 4)
                        menuChevron
                    }
                    .foregroundColor(Garden.ink)
                    .padding(.horizontal, 9)
                    .frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Garden.line.opacity(0.22)))
                    .allowsHitTesting(false).accessibilityHidden(true)
                }
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
