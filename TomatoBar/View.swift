import AppKit
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct FocusTaskMenuContent: View {
    @ObservedObject var timer: TBTimer
    var excluding: UUID? = nil
    var showsPrompt = true

    var body: some View {
        if showsPrompt { Text("选择已有待办专注：") }
        let projects = timer.state.projects.filter { !$0.isCompleted }
        let todos = timer.state.pendingTodos.filter { $0.id != excluding }
        ForEach(projects) { project in
            let tasks = todos.filter { $0.projectID == project.id }
            if !tasks.isEmpty {
                Section(project.name) {
                    ForEach(tasks) { todo in
                        Button(todo.title) { timer.selectCurrentTodo(todo.id) }
                    }
                }
            }
        }
        let loose = todos.filter { $0.projectID == nil }
        if !loose.isEmpty {
            if !projects.isEmpty {
                Section("独立待办") {
                    ForEach(loose) { todo in Button(todo.title) { timer.selectCurrentTodo(todo.id) } }
                }
            } else {
                ForEach(loose) { todo in Button(todo.title) { timer.selectCurrentTodo(todo.id) } }
            }
        }
    }
}

struct FocusTagChoices: View {
    let knownTags: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if !knownTags.isEmpty {
            Text("已有标签")
            ForEach(knownTags, id: \.self) { tag in Button(tag) { onSelect(tag) } }
            Divider()
        }
        Text("常用建议")
        ForEach(Garden.suggestedCategories, id: \.self) { tag in Button(tag) { onSelect(tag) } }
    }
}

struct FocusDraftTagMenuContent: View {
    @ObservedObject var timer: TBTimer
    var onCustomTag: (() -> Void)? = nil

    var body: some View {
        if !timer.state.draftTags.isEmpty {
            Button("清除标签") { timer.setDraftTags([]) }
            Divider()
        }
        if let onCustomTag = onCustomTag {
            Button("+ 自定义新标签...", action: onCustomTag)
            Divider()
        }
        FocusTagChoices(knownTags: timer.state.knownTags, onSelect: timer.toggleDraftTag)
    }
}

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
    private enum PopoverRoute: Equatable {
        case focus, records, intervals, settings
    }

    @ObservedObject var timer: TBTimer
    @State private var route: PopoverRoute = .focus
    @AppStorage(TomyPetController.showKey) private var showDesktopPet = true
    @AppStorage(TomyPetController.sizeKey) private var tomyPetSize = TomyPetSize.medium.rawValue
    @AppStorage(TomyPetController.lockedKey) private var tomyPetLocked = false
    @State private var editingRecord: FocusRecord?
    @State private var selectedTag: String?
    @State private var showCancelConfirm = false
    @State private var isAddingQuickTodo = false
    @State private var quickTodoTitle = ""
    @SwiftUI.FocusState private var isQuickTodoFocused: Bool
    @State private var showingCustomTagAlert = false
    @State private var customTagTargetTodoID: UUID?
    @State private var isCustomTagForDraft = false
    @State private var customTagInput = ""
    // Opening the cancel dialog freezes the clock: otherwise the timer could hit zero
    // behind the modal, addRecord fires, and 「放弃这段」 silently no-ops (phase is no
    // longer .work) leaving exactly the record the user just tried to discard.
    @State private var cancelWasPaused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch route {
            case .focus:
                focusRouteView
            case .records:
                recordsRouteView
            case .intervals:
                intervalsRouteView
            case .settings:
                settingsRouteView
            }
        }
        .padding(16)
        .frame(width: 340)
        .background(Garden.paper)
        .foregroundColor(Garden.ink)
        .accentColor(Garden.red)
        .preferredColorScheme(.light)
        .onDisappear {
            if editingRecord == nil && !showCancelConfirm && !showingCustomTagAlert {
                route = .focus
                isAddingQuickTodo = false
            }
        }
        .alert("取消这段专注？", isPresented: $showCancelConfirm) {
            Button("继续专注", role: .cancel) { if !cancelWasPaused { timer.togglePause() } }
                .keyboardShortcut(.cancelAction)
            Button("放弃这段", role: .destructive) { timer.cancel() }
        } message: { Text(cancelFocusMessage(timer.state)) }
        .alert("自定义新标签", isPresented: $showingCustomTagAlert) {
            TextField("输入新标签名称", text: $customTagInput)
            Button("确定") {
                let tag = customTagInput.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                if !tag.isEmpty {
                    if isCustomTagForDraft {
                        let current = timer.state.draftTags
                        if !current.contains(where: { FocusRecord.sameTag($0, tag) }) {
                            timer.setDraftTags(current + [tag])
                        }
                    } else if let id = customTagTargetTodoID {
                        timer.setTodoTags(id: id, tags: [tag])
                    }
                }
                customTagInput = ""
                customTagTargetTodoID = nil
                isCustomTagForDraft = false
            }
            Button("取消", role: .cancel) {
                customTagInput = ""
                customTagTargetTodoID = nil
                isCustomTagForDraft = false
            }
        }
        // P16: the other window's edit or delete can empty out the tag this filter
        // points at. Re-check it whenever the shared record list changes, not only
        // after this view's own save.
        .onChange(of: timer.state.records) { _ in clearStaleFilter() }
    }

    private var focusRouteView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                GardenArt(name: "PixelTomato", activity: timer.windowActivity)
                    .frame(width: 26, height: 26)
                Text("TomatoBar")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Text(timer.phaseLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Garden.muted)
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { route = .settings }
                } label: {
                    GardenActionIcon(name: "gearshape", pointSize: 13, color: Garden.muted, targetSize: 24)
                }
                .buttonStyle(.plain)
                .help("设置")
                .accessibilityLabel("设置")
            }

            if canPrepareNext {
                focusTargetSelection
            } else {
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
                HStack(spacing: 8) {
                    Button { timer.startWork() } label: {
                        Text("开始专注")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GardenPrimaryButtonStyle())
                    .disabled(timer.storageError != nil)

                    Menu {
                        ForEach([15, 25, 35, 45, 60], id: \.self) { minutes in
                            Button {
                                timer.workIntervalLength = minutes
                            } label: {
                                if timer.workIntervalLength == minutes {
                                    Label("\(minutes) 分钟", systemImage: "checkmark")
                                } else {
                                    Text("\(minutes) 分钟")
                                }
                            }
                        }
                        Divider()
                        Button("自定义时长…") {
                            withAnimation(.easeInOut(duration: 0.16)) { route = .intervals }
                        }
                    } label: {
                        Color.clear
                            .frame(width: 86, height: 42)
                            .contentShape(RoundedRectangle(cornerRadius: Garden.cornerMedium))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 86, height: 42)
                    .overlay {
                        HStack(spacing: 3) {
                            Text("\(timer.workIntervalLength)分钟")
                                .font(.system(size: 13, weight: .medium).monospacedDigit())
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Garden.muted)
                        }
                        .foregroundColor(Garden.ink)
                        .frame(width: 86, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: Garden.cornerMedium)
                                .fill(Garden.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Garden.cornerMedium)
                                .stroke(Garden.line.opacity(0.85), lineWidth: 1)
                        )
                        .allowsHitTesting(false)
                    }
                    .help("切换专注时长")
                    .accessibilityLabel("专注时长：\(timer.workIntervalLength)分钟")
                }
            }

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("今日 \(Int(timer.todaySeconds / 60)) 分钟 · 完成 \(timer.todayCount) 个")
                }
                .foregroundColor(Garden.muted)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { route = .records }
                } label: {
                    HStack(spacing: 3) {
                        Text("最近记录")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Garden.muted)
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 2)

            if let error = timer.storageError {
                VStack(alignment: .leading, spacing: 5) {
                    Text(error).foregroundColor(Garden.red)
                    HStack(spacing: 10) {
                        Button(timer.storageRetryTitle) { timer.retryStorage() }
                        Button("打开记录文件夹") { timer.openRecordsFolder() }
                    }
                }.font(.caption)
            }

            if canPrepareNext {
                nextTodoSection
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
    }

    private func secondaryHeader(_ title: String) -> some View {
        secondaryHeader(title) { EmptyView() }
    }

    private func secondaryHeader<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        editingRecord = nil
                        route = .focus
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Garden.red)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                trailing()
            }
            Rectangle().fill(Garden.line.opacity(0.65)).frame(height: 1)
        }
    }

    private var focusTargetSelection: some View {
        Group {
            if let current = timer.state.currentTodo {
                HStack(spacing: 8) {
                    Button { timer.toggleTodo(id: current.id) } label: {
                        GardenActionIcon(name: "circle", pointSize: 15, color: Garden.muted, targetSize: 22)
                    }
                    .buttonStyle(.plain)
                    .help("标记完成")
                    .accessibilityLabel("标记完成：\(current.title)")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        let project = current.projectID.flatMap { timer.state.project(for: $0) }
                        let secs = timer.state.focusSeconds(forTodo: current.id)
                        if project != nil || !current.tags.isEmpty || secs > 0 {
                            HStack(spacing: 5) {
                                if let proj = project {
                                    Text(proj.name)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Garden.ink)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Garden.line.opacity(0.28))
                                        .cornerRadius(3)
                                }
                                if !current.tags.isEmpty {
                                    Text(current.tags.map { "#\($0)" }.joined(separator: " "))
                                        .font(.caption2)
                                        .foregroundColor(Garden.color(current.tags.first ?? "", styles: timer.state.categoryStyles))
                                        .lineLimit(1)
                                }
                                if secs > 0 {
                                    Text(focusDuration(secs))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundColor(Garden.muted)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    Menu {
                        Button("切回自由专注") { timer.selectCurrentTodo(nil) }
                        if timer.state.pendingTodos.count > 1 {
                            Divider()
                            FocusTaskMenuContent(timer: timer, excluding: current.id, showsPrompt: false)
                        }
                        Divider()
                        Menu("设置任务标签") {
                            if !current.tags.isEmpty {
                                Button("清除标签") { timer.setTodoTags(id: current.id, tags: []) }
                                Divider()
                            }
                            Button("+ 自定义新标签...") {
                                isCustomTagForDraft = false
                                customTagTargetTodoID = current.id
                                customTagInput = ""
                                showingCustomTagAlert = true
                            }
                            Divider()
                            FocusTagChoices(knownTags: timer.state.knownTags) { tag in
                                timer.setTodoTags(id: current.id, tags: [tag])
                            }
                        }
                    } label: {
                        GardenActionIcon(name: "ellipsis.circle", pointSize: 14, color: Garden.muted, targetSize: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 20, height: 20)

                    Button {
                        timer.selectCurrentTodo(nil)
                    } label: {
                        GardenActionIcon(name: "xmark.circle.fill", pointSize: 14, color: Garden.muted, targetSize: 20)
                    }
                    .buttonStyle(.plain)
                    .help("切回自由专注")
                }
                .padding(.horizontal, 10)
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
                HStack(spacing: 6) {
                    TextField("准备专注什么？", text: Binding(
                        get: { timer.eventName },
                        set: { timer.setEventName($0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .accessibilityLabel("事件名称")

                    Menu {
                        FocusDraftTagMenuContent(timer: timer, onCustomTag: {
                            isCustomTagForDraft = true
                            customTagTargetTodoID = nil
                            customTagInput = ""
                            showingCustomTagAlert = true
                        })
                    } label: {
                        if timer.state.draftTags.isEmpty {
                            Image(systemName: "tag")
                                .font(.system(size: 12))
                                .foregroundColor(Garden.muted)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                        } else {
                            Text(timer.state.draftTags.map { "#\($0)" }.joined(separator: " "))
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Garden.color(timer.state.draftTags.first ?? "", styles: timer.state.categoryStyles).opacity(0.14))
                                )
                                .foregroundColor(Garden.color(timer.state.draftTags.first ?? "", styles: timer.state.categoryStyles))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(timer.state.draftTags.isEmpty ? "选择标签" : "修改标签")
                    .accessibilityLabel(timer.state.draftTags.isEmpty ? "选择标签" : "已选标签：\(timer.state.draftTags.joined(separator: " "))")
                }
                .padding(.horizontal, 10)
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
        }
    }

    private var canPrepareNext: Bool {
        timer.state.phase == .idle || timer.state.phase == .restFinished
    }

    private var nextTodoSection: some View {
        let upNext = timer.state.pendingTodos.filter { $0.id != timer.state.currentTodoID }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("接下来")
                    .font(.system(size: 12.5, weight: .semibold))
                if !upNext.isEmpty {
                    Text("\(upNext.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(Garden.muted)
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        isAddingQuickTodo.toggle()
                    }
                    if isAddingQuickTodo {
                        DispatchQueue.main.async { isQuickTodoFocused = true }
                    }
                } label: {
                    if upNext.isEmpty && timer.state.currentTodo != nil && !isAddingQuickTodo {
                        Label("添加待办", systemImage: "plus")
                            .font(.caption)
                            .foregroundColor(Garden.muted)
                    } else {
                        GardenActionIcon(name: isAddingQuickTodo ? "minus" : "plus", pointSize: 11, color: Garden.muted, targetSize: 22)
                    }
                }
                .buttonStyle(.plain)
                .help(isAddingQuickTodo ? "收起输入框" : "添加待办")
                .accessibilityLabel(isAddingQuickTodo ? "收起待办输入框" : "添加待办")
            }

            if upNext.isEmpty && !isAddingQuickTodo {
                if timer.state.currentTodo == nil {
                    Text("点击 + 记下待办")
                        .font(.caption)
                        .foregroundColor(Garden.muted)
                        .padding(.vertical, 1)
                }
            } else {
                ForEach(Array(upNext.prefix(4))) { todo in
                    HStack(spacing: 7) {
                        Button { timer.toggleTodo(id: todo.id) } label: {
                            GardenActionIcon(name: "circle", pointSize: 13.5, targetSize: 20)
                        }
                        .buttonStyle(.plain)
                        .help("标记完成")
                        .accessibilityLabel("标记完成：\(todo.title)")

                        Button { timer.selectCurrentTodo(todo.id) } label: {
                            HStack(spacing: 4) {
                                if let proj = todo.projectID.flatMap({ timer.state.project(for: $0) }) {
                                    Text(proj.name)
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundColor(Garden.muted)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Garden.surface.opacity(0.85))
                                        .cornerRadius(3)
                                }
                                Text(todo.title)
                                    .font(.system(size: 12))
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
                                Button("+ 自定义新标签...") {
                                    isCustomTagForDraft = false
                                    customTagTargetTodoID = todo.id
                                    customTagInput = ""
                                    showingCustomTagAlert = true
                                }
                                Divider()
                                FocusTagChoices(knownTags: timer.state.knownTags) { tag in
                                    timer.setTodoTags(id: todo.id, tags: [tag])
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
                        .overlay(GardenActionIcon(name: "ellipsis", pointSize: 11, color: Garden.muted, targetSize: 16).allowsHitTesting(false))

                        Button {
                            timer.selectCurrentTodo(todo.id)
                            timer.startWork()
                        } label: {
                            GardenActionIcon(name: "play.fill", pointSize: 11, color: Garden.red, targetSize: 20)
                        }
                        .buttonStyle(.plain)
                        .help("立即开始")
                        .accessibilityLabel("开始待办：\(todo.title)")
                        .disabled(timer.storageError != nil || timer.state.needsAttention || timer.state.isTiming)
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .fill(Garden.surface.opacity(0.72))
                    )
                }

                if upNext.count > 4 {
                    Menu {
                        FocusTaskMenuContent(timer: timer, excluding: timer.state.currentTodoID, showsPrompt: false)
                    } label: {
                        HStack(spacing: 4) {
                            Text("还有 \(upNext.count - 4) 项待办")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                        }
                        .font(.caption)
                        .foregroundColor(Garden.muted)
                        .padding(.top, 1)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                }
            }

            if isAddingQuickTodo {
                HStack(spacing: 6) {
                    TextField("添加待办...", text: $quickTodoTitle)
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
                        .focused($isQuickTodoFocused)
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
                    .accessibilityLabel("添加待办")
                }
            }
        }
        .padding(9)
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

    private var recordsRouteView: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    .frame(height: 390)
            } else {
                let records = timer.state.filteredRecords(tag: selectedTag)
                secondaryHeader("最近记录") {
                    HStack(spacing: 8) {
                        Menu {
                            Button("全部") { selectedTag = nil }
                            ForEach(timer.state.allTags, id: \.self) { tag in
                                Button(tag) { selectedTag = tag }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text(selectedTag ?? "全部")
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .font(.caption)
                            .foregroundColor(Garden.ink)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)

                        Text("\(records.count) 条")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Garden.muted)
                    }
                }

                if records.isEmpty {
                    VStack(spacing: 8) {
                        GardenArt(name: "PixelSprout", activity: timer.windowActivity)
                            .frame(width: 42, height: 32)
                        Text(selectedTag == nil ? "还没有专注记录" : "这个标签下还没有记录")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(records) { record in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 7) {
                                        Circle()
                                            .fill(Garden.color(record.category, styles: timer.state.categoryStyles))
                                            .frame(width: 7, height: 7)
                                        Text(record.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                        Spacer(minLength: 6)
                                        Text(focusDuration(record.seconds))
                                            .font(.system(size: 12).monospacedDigit())
                                            .foregroundColor(Garden.muted)
                                        Button { editingRecord = record } label: {
                                            GardenActionIcon(name: "pencil", pointSize: 11, color: Garden.muted, targetSize: 20)
                                        }
                                        .buttonStyle(.plain)
                                        .help("编辑记录")
                                        .accessibilityLabel("编辑记录：\(record.name)")
                                    }
                                    HStack(spacing: 6) {
                                        Text(record.startedAt, format: .dateTime.month().day().hour().minute())
                                        if !record.tags.isEmpty {
                                            Text(record.tags.map { "#\($0)" }.joined(separator: " "))
                                                .foregroundColor(Garden.color(record.category, styles: timer.state.categoryStyles))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if !record.completed {
                                            Text("提前结束")
                                        }
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(Garden.muted)
                                    .padding(.leading, 14)
                                }
                                .padding(.vertical, 7)
                                Rectangle().fill(Garden.line.opacity(0.55)).frame(height: 1)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .frame(height: 300)
                }
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

    private var intervalsRouteView: some View {
        VStack(alignment: .leading, spacing: 12) {
            secondaryHeader("计时时长")
            GardenNumberInputRow(title: "专注", value: $timer.workIntervalLength, range: 1...180, unit: "分钟")
            GardenNumberInputRow(title: "短休息", value: $timer.shortRestIntervalLength, range: 1...60, unit: "分钟")
            GardenNumberInputRow(title: "长休息", value: $timer.longRestIntervalLength, range: 1...60, unit: "分钟")
            GardenNumberInputRow(title: "每组", value: $timer.workIntervalsInSet, range: 1...10, unit: "个番茄")
        }
    }

    private var settingsRouteView: some View {
        VStack(alignment: .leading, spacing: 13) {
            secondaryHeader("设置")
            KeyboardShortcuts.Recorder("开始 / 暂停 / 继续", name: .startStopTimer)
            Toggle("菜单栏显示倒计时", isOn: $timer.showTimerInMenuBar)
                .onChange(of: timer.showTimerInMenuBar) { _ in timer.updateStatus() }
            Toggle("桌面伴侣 · 番茄仔 Tomy", isOn: $showDesktopPet)
            if showDesktopPet {
                HStack(spacing: 8) {
                    Picker("尺寸", selection: $tomyPetSize) {
                        ForEach(TomyPetSize.allCases, id: \.rawValue) { preset in
                            Text(preset.shortTitle).tag(preset.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 138)
                    Toggle("锁定穿透", isOn: $tomyPetLocked)
                        .font(.system(size: 12))
                    Spacer(minLength: 0)
                    Button("复位") { TomyPetController.shared?.resetToDefaultCorner() }
                        .font(.system(size: 11.5))
                        .buttonStyle(.borderless)
                        .foregroundColor(Garden.muted)
                        .help("将番茄仔贴回屏幕右下角")
                }
            }
            LaunchAtLogin.Toggle("登录时启动")
            Rectangle().fill(Garden.line.opacity(0.55)).frame(height: 1)
            Button { timer.openRecordsFolder() } label: {
                Label("打开记录文件夹", systemImage: "folder")
                    .font(.system(size: 12.5))
                    .foregroundColor(Garden.ink)
            }
            .buttonStyle(.plain)
        }
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
                item.state = FocusRecord.sameTag(category, selection) ? .on : .off
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
        let key = FocusRecord.styleStorageKey(for: category)
        // Drop any alias spelling first. Leaving an old "straße" entry beside a new
        // "strasse" one made 恢复全部自动 a no-op: resolution still found the old key.
        for existing in Array(localStyles.keys) where FocusRecord.sameTag(existing, key) {
            localStyles.removeValue(forKey: existing)
        }
        if let value = FocusState.composedStyle(symbol: symbol, colorIndex: colorIndex) {
            localStyles[key] = value
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
            !availableCategories.contains { FocusRecord.sameTag($0, suggested) }
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
            if otherTags.isEmpty { Text("暂无其他标签").font(.caption).foregroundColor(Garden.muted) }
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
