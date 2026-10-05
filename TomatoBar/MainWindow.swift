import SwiftUI
import LaunchAtLogin
import KeyboardShortcuts
import UniformTypeIdentifiers

struct MainWindowView: View {
    @ObservedObject var timer: TBTimer
    @ObservedObject var history: FocusHistory
    @State private var period = FocusPeriod.day
    @State private var date = Date()
    @State private var selectedCategory: String?
    @State private var showAllCategories = false
    @State private var historyTab = false
    @State private var search = ""
    @State private var editing: FocusRecord?
    @State private var pendingDelete: FocusRecord?
    @State private var hoverDelete: UUID?
    @State private var deleteError: String?
    @State private var settings = false
    @State private var expandedTimer = false
    @State private var newTodoTitle = ""
    @State private var editingTodoID: UUID?
    @State private var editingTodoTitle = ""
    @State private var showingCustomTagAlert = false
    @State private var customTagTargetTodoID: UUID?
    @State private var customTagInput = ""
    @State private var showingNewProjectSheet = false
    @State private var editingProject: FocusProject?
    @State private var collapsedProjectIDs: Set<UUID> = []
    @State private var inlineSubtaskTitles: [UUID: String] = [:]
    @State private var isLooseTodosCollapsed = false
    @State private var isArchivedCollapsed = true
    private var summary: FocusSummary { FocusSummary(records: history.records, period: period, date: date) }
    private var filtered: FocusSummary { FocusSummary(records: history.records, period: period, date: date, category: selectedCategory) }
    private var visibleRecords: [FocusRecord] {
        let records = historyTab ? history.records.sorted { $0.startedAt < $1.startedAt } : filtered.records
        return records.filter { record in
            (search.isEmpty || record.name.localizedCaseInsensitiveContains(search) || record.tags.contains { $0.localizedCaseInsensitiveContains(search) })
                && (!historyTab || selectedCategory == nil || record.hasTag(selectedCategory!))
        }
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                Rectangle().fill(Garden.line).frame(height: 1)
                VStack(alignment: .leading, spacing: 12) {
                    if !historyTab {
                        heading
                        HStack(alignment: .top, spacing: 14) {
                            summaryPanel
                                .padding(16)
                                .frame(width: sidebarWidth(for: geometry.size.width))
                                .frame(maxHeight: .infinity, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: Garden.cornerLarge)
                                        .fill(Garden.surface.opacity(0.36))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Garden.cornerLarge)
                                        .stroke(Garden.line.opacity(0.34), lineWidth: 1)
                                )
                            FocusChart(summary: filtered, styles: timer.state.categoryStyles, activity: timer.windowActivity, period: period, onDay: { date = $0; period = .day }, onRecord: { editing = $0 })
                                .padding(16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: Garden.cornerLarge)
                                        .fill(Garden.surface.opacity(0.36))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Garden.cornerLarge)
                                        .stroke(Garden.line.opacity(0.34), lineWidth: 1)
                                )
                        }
                        .frame(height: overviewPanelHeight(for: geometry.size.height))
                    }
                    if let message = deleteError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Garden.red)
                            Text(message).font(.caption).foregroundColor(Garden.red)
                            Spacer()
                            Button("知道了") { deleteError = nil }.font(.caption)
                        }.padding(.vertical, 6).padding(.horizontal, 10)
                            .background(Garden.red.opacity(0.08)).cornerRadius(6)
                    }
                    if historyTab {
                        VStack(alignment: .leading, spacing: 10) {
                            recordHeader
                            recordList
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(
                            RoundedRectangle(cornerRadius: Garden.cornerLarge)
                                .fill(Garden.surface.opacity(0.30))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Garden.cornerLarge)
                                .stroke(Garden.line.opacity(0.34), lineWidth: 1)
                        )
                    } else {
                        overviewLowerSection(sidebarWidth: sidebarWidth(for: geometry.size.width))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)
                TimerCard(timer: timer, expanded: $expandedTimer)
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
            }
        }.background(Garden.paper).foregroundColor(Garden.ink).accentColor(Garden.red)
            .preferredColorScheme(.light)
            .sheet(item: $editing) { record in
                RecordEditor(record: record, availableCategories: timer.state.allCategories,
                    styles: timer.state.categoryStyles, onCancel: { editing = nil },
                    onSave: { name, tags, styleChanges in
                        // `record` is the sheet's snapshot at open; the expected check
                        // turns a stale draft into a refusal instead of a lost update (P26).
                        let error = timer.editRecord(id: record.id, name: name, tags: tags, styleChanges: styleChanges, expected: record)
                        if error == nil { clearStaleFilter(); editing = nil }
                        return error
                    }, onDelete: {
                        let error = timer.deleteRecord(id: record.id)
                        if error == nil { clearStaleFilter(); editing = nil }
                        return error
                    }).padding(24).frame(width: 440, height: 430).background(Garden.paper)
            }
            .sheet(isPresented: $settings) { MainSettings(timer: timer) { settings = false } }
            .sheet(isPresented: $expandedTimer) { ExpandedTimer(timer: timer) { expandedTimer = false } }
            .sheet(isPresented: $showingNewProjectSheet) {
                NewProjectSheet(suggestedTags: timer.state.knownTags.isEmpty ? Garden.suggestedCategories : timer.state.knownTags,
                                onSave: { name, tags in
                    timer.addProject(name: name, tags: tags)
                    showingNewProjectSheet = false
                }, onCancel: {
                    showingNewProjectSheet = false
                })
            }
            .sheet(item: $editingProject) { project in
                EditProjectSheet(project: project,
                                 suggestedTags: timer.state.knownTags.isEmpty ? Garden.suggestedCategories : timer.state.knownTags,
                                 onSave: { name, tags in
                    timer.updateProject(id: project.id, name: name, tags: tags)
                    editingProject = nil
                }, onCancel: {
                    editingProject = nil
                })
            }
            .alert("自定义新标签", isPresented: $showingCustomTagAlert) {
                TextField("输入新标签名称", text: $customTagInput)
                Button("确定") {
                    let tag = customTagInput.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                    if !tag.isEmpty, let id = customTagTargetTodoID {
                        timer.setTodoTags(id: id, tags: [tag])
                    }
                    customTagInput = ""
                    customTagTargetTodoID = nil
                }
                Button("取消", role: .cancel) {
                    customTagInput = ""
                    customTagTargetTodoID = nil
                }
            } message: {
                Text("输入新标签后将赋给当前待办，并在已有标签列表中保存。")
            }
            // Row-level delete needs its own confirmation because the editor sheet is not
            // open on that path. The wording comes from RecordEditor.confirmationMessage so
            // both routes warn identically.
            .alert("删除这段专注记录？", isPresented: deleteConfirmationShown, presenting: pendingDelete) { record in
                Button("取消", role: .cancel) { pendingDelete = nil }.keyboardShortcut(.cancelAction)
                Button("删除记录", role: .destructive) { commitDelete(record) }
            } message: { record in
                Text(RecordEditor.confirmationMessage(for: record))
            }
            // P16: the popover is the other half of this pair — its edits and deletes can
            // empty out the category this window's filter points at. Re-check against the
            // shared list whenever it changes, not only after this view's own save.
            .onChange(of: history.records) { _ in clearStaleFilter() }
    }
    private func sidebarWidth(for width: CGFloat) -> CGFloat {
        min(540, max(380, width * 0.46))
    }
    private func overviewPanelHeight(for height: CGFloat) -> CGFloat {
        period == .month ? min(300, max(246, height * 0.36)) : min(272, max(236, height * 0.34))
    }
    /// `.alert(presenting:)` wants a Bool binding plus the item. Deriving the Bool from
    /// pendingDelete means dismissing the alert can never leave a stale record behind.
    private var deleteConfirmationShown: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
    /// Drop the active category filter when the record just edited or deleted was the last
    /// one carrying it, so the view never rests on a category that no longer exists.
    private func clearStaleFilter() {
        // Overview filters by primary category, history by any tag; the predicate lives in
        // FocusState so both semantics are covered by the domain suite.
        if let category = selectedCategory,
           !timer.state.categoryFilterStillMatches(category, primaryOnly: !historyTab) {
            selectedCategory = nil
        }
    }
    private func commitDelete(_ record: FocusRecord) {
        pendingDelete = nil
        deleteError = timer.deleteRecord(id: record.id)
        if deleteError == nil { clearStaleFilter() }
    }
    private var header: some View {
        HStack(spacing: 12) {
            GardenArt(name: "PixelTomato", activity: timer.windowActivity).frame(width: 34, height: 34)
            Text("TomatoBar").font(.system(size: 20, weight: .bold, design: .rounded))
            Spacer().frame(width: 28)
            Button("概览") { historyTab = false; search = ""; selectedCategory = nil }.font(.system(size: 15, weight: .medium))
                .foregroundColor(historyTab ? Garden.muted : Garden.red)
            Button("历史") { historyTab = true; selectedCategory = nil }.font(.system(size: 15, weight: .medium)).padding(.leading, 16)
                .foregroundColor(historyTab ? Garden.red : Garden.muted)
            Spacer()
            Text("让专注，慢慢生长").font(.caption).foregroundColor(Garden.muted)
            Button { settings = true } label: { GardenActionIcon(name: "gearshape", pointSize: 18, color: Garden.ink, targetSize: 28) }
                .padding(.leading, 16).help("设置").accessibilityLabel("设置")
        }.buttonStyle(.plain).padding(.horizontal, 28).frame(height: 58)
    }
    private var heading: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(period == .day ? (Calendar.current.isDateInToday(date) ? "今天，把时间留给了什么？" : "这一天，把时间留给了什么？") : period == .week ? "这一周的专注时光" : "这个月，留下的点点滴滴")
                    .font(.system(size: 32, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 10) {
                    Button { step(-1) } label: { GardenActionIcon(name: "chevron.left", pointSize: 12) }
                        .help("上一\(period.rawValue)").accessibilityLabel("上一\(period.rawValue)")
                    Text(dateTitle).font(.system(size: 13))
                    Button { step(1) } label: { GardenActionIcon(name: "chevron.right", pointSize: 12) }
                        .disabled(summary.interval.end > Date()).help("下一\(period.rawValue)").accessibilityLabel("下一\(period.rawValue)")
                    if !summary.interval.contains(Date()) { Button("回到今天") { date = Date() } }
                }.buttonStyle(.plain).foregroundColor(Garden.muted)
            }
            Spacer()
            HStack(spacing: 3) {
                ForEach(FocusPeriod.allCases) { option in
                    Button { period = option } label: {
                        Text(option.rawValue).font(.system(size: 15, weight: .medium))
                            .frame(width: 46, height: 30)
                            .foregroundColor(period == option ? Garden.paper : Garden.ink)
                            .background(period == option ? Garden.red : .clear).cornerRadius(7)
                    }.buttonStyle(.plain).accessibilityLabel("\(option.rawValue)视图")
                }
            }.padding(3).background(Garden.line.opacity(0.3)).cornerRadius(9)
        }
    }
    private var dateTitle: String {
        let format = DateFormatter(); format.locale = Locale(identifier: "zh_CN")
        format.dateFormat = period == .month ? "yyyy年 M月" : "M月d日"
        if period == .week { return "\(format.string(from: summary.interval.start)) — \(format.string(from: summary.interval.end.addingTimeInterval(-1)))" }
        if period == .day { format.dateFormat = "yyyy年 M月d日 EEEE" }
        return format.string(from: date)
    }
    private func step(_ value: Int) {
        if let next = Calendar.current.date(byAdding: period == .week ? .day : period.component, value: period == .week ? value * 7 : value, to: date) { date = next }
    }
    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(period == .day ? "当日" : period == .week ? "本周" : "本月")累计专注（不含进行中）")
                .font(.system(size: 12))
                .foregroundColor(Garden.muted)
            Text(focusDuration(summary.seconds))
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundColor(Garden.red)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
            ScrollView {
                VStack(spacing: 7) {
                    ForEach(showAllCategories ? summary.categories : Array(summary.categories.prefix(5))) { category in
                        Button { selectedCategory = selectedCategory == category.name ? nil : category.name } label: {
                            HStack {
                                Rectangle().fill(Garden.color(category.name, styles: timer.state.categoryStyles)).frame(width: 10, height: 10)
                                Text(category.name).lineLimit(1)
                                Spacer()
                                Text(focusDuration(category.seconds)).foregroundColor(Garden.muted)
                            }.font(.system(size: 13)).padding(.vertical, 2)
                                .background(selectedCategory == category.name ? Garden.line.opacity(0.4) : .clear)
                        }.buttonStyle(.plain)
                            .accessibilityLabel("筛选主分类：\(category.name)，\(focusDuration(category.seconds))")
                            .accessibilityValue(selectedCategory == category.name ? "已选中" : "未选中")
                    }
                    if summary.categories.count > 5 {
                        Button(showAllCategories ? "收起标签" : "展开其余 \(summary.categories.count - 5) 个标签") { showAllCategories.toggle() }
                            .buttonStyle(.plain).font(.caption).foregroundColor(Garden.muted).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if summary.categories.isEmpty { Text("专注之后，再来看看时间的去向。").font(.caption).foregroundColor(Garden.muted) }
                }.padding(.trailing, 8)
            }
            HStack {
                GardenArt(name: "PixelSprout", activity: timer.windowActivity).frame(width: 30, height: 24)
                Text("每一段投入，都有迹可循").font(.caption2).foregroundColor(Garden.muted)
                Spacer()
            }
        }
    }
    private func overviewLowerSection(sidebarWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 14) {
            todoPanel
                .padding(14)
                .frame(width: sidebarWidth)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: Garden.cornerLarge)
                        .fill(Garden.surface.opacity(0.30))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Garden.cornerLarge)
                        .stroke(Garden.line.opacity(0.34), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 10) {
                recordHeader
                recordList
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: Garden.cornerLarge)
                    .fill(Garden.surface.opacity(0.30))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Garden.cornerLarge)
                    .stroke(Garden.line.opacity(0.34), lineWidth: 1)
            )
        }
        .frame(maxHeight: .infinity)
    }

    private var todoPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("待办").font(.system(size: 17, weight: .semibold))
                Text("\(timer.state.pendingTodos.count) 项未完成")
                    .font(.caption).foregroundColor(Garden.muted)
                Spacer()
                Button {
                    showingNewProjectSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 11))
                        Text("新建大任务")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Garden.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .fill(Garden.red.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .help("创建长周期大任务/项目，并在其下拆解子任务")
            }

            HStack(spacing: 8) {
                TextField("添加待办，例如：阅读章节 #学习", text: $newTodoTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .fill(Garden.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .stroke(Garden.line.opacity(0.82), lineWidth: 1)
                    )
                    .onSubmit { addTodo() }
                Button { addTodo() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .foregroundColor(Garden.paper)
                        .background(Circle().fill(Garden.red))
                }
                .buttonStyle(.plain)
                .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("添加待办")
            }

            if timer.state.todos.isEmpty && timer.state.projects.isEmpty {
                VStack(spacing: 8) {
                    GardenArt(name: "PixelSprout", activity: timer.windowActivity)
                        .frame(width: 46, height: 35)
                    Text("把下一件想做的事写在这里")
                        .font(.system(size: 14, weight: .medium))
                    Text("支持拆解大任务与子任务，点一下就会带到下一段专注。")
                        .font(.caption).foregroundColor(Garden.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        let activeProjects = timer.state.projects.filter { !$0.isArchived }
                        let looseTodos = timer.state.todos.filter { $0.projectID == nil }
                        let archivedProjects = timer.state.projects.filter { $0.isArchived }

                        ForEach(activeProjects) { project in
                            projectCard(project)
                        }

                        if !looseTodos.isEmpty || !activeProjects.isEmpty {
                            looseTodosSection(looseTodos: looseTodos, hasProjects: !activeProjects.isEmpty)
                        }

                        if !archivedProjects.isEmpty {
                            archivedProjectsSection(archivedProjects: archivedProjects)
                        }
                    }
                    .padding(.trailing, 6)
                }
            }
        }
    }

    @ViewBuilder
    private func projectCard(_ project: FocusProject) -> some View {
        let isCollapsed = collapsedProjectIDs.contains(project.id)
        let subtasks = timer.state.todos.filter { $0.projectID == project.id }
        let completedCount = subtasks.filter(\.isCompleted).count
        let totalCount = subtasks.count
        let projSecs = timer.state.focusSeconds(forProject: project.id)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isCollapsed {
                            collapsedProjectIDs.remove(project.id)
                        } else {
                            collapsedProjectIDs.insert(project.id)
                        }
                    }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Garden.muted)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)

                Image(systemName: "folder.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Garden.red.opacity(0.85))

                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Garden.ink)
                    .lineLimit(1)

                if let mainTag = project.tags.first {
                    Text("#\(mainTag)")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Garden.color(mainTag, styles: timer.state.categoryStyles))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Garden.color(mainTag, styles: timer.state.categoryStyles).opacity(0.12))
                        .cornerRadius(3)
                }

                if totalCount > 0 {
                    Text("\(completedCount)/\(totalCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(Garden.muted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Garden.line.opacity(0.4))
                        .cornerRadius(3)
                }

                if projSecs > 0 {
                    Text("🎯 \(focusDuration(projSecs))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(Garden.red)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Garden.red.opacity(0.08))
                        .cornerRadius(3)
                }

                Spacer()

                Menu {
                    Button("为此大任务添加子任务...") {
                        collapsedProjectIDs.remove(project.id)
                        inlineSubtaskTitles[project.id] = ""
                    }
                    Divider()
                    Button("编辑大任务 (名称与标签)") {
                        editingProject = project
                    }
                    Button(project.isArchived ? "取消归档" : "归档大任务") {
                        timer.toggleProjectArchived(id: project.id)
                    }
                    Divider()
                    Button("删除大任务 (子任务保留为独立待办)", role: .destructive) {
                        timer.deleteProject(id: project.id)
                    }
                } label: {
                    GardenActionIcon(name: "ellipsis", pointSize: 12, color: Garden.muted)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Garden.surface.opacity(0.55))
            .cornerRadius(Garden.cornerSmall)

            if !isCollapsed {
                VStack(alignment: .leading, spacing: 3) {
                    if subtasks.isEmpty {
                        Text("暂无子任务，在下方添加拆解步骤")
                            .font(.caption)
                            .foregroundColor(Garden.muted)
                            .padding(.leading, 28)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(subtasks) { subtask in
                            todoRow(subtask, isSubtask: true)
                                .onDrag {
                                    NSItemProvider(object: subtask.id.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                                    guard let provider = providers.first else { return false }
                                    provider.loadObject(ofClass: NSString.self) { object, _ in
                                        guard let raw = object as? NSString,
                                              let sourceID = UUID(uuidString: raw as String),
                                              sourceID != subtask.id else { return }
                                        DispatchQueue.main.async {
                                            timer.moveTodo(id: sourceID, before: subtask.id)
                                        }
                                    }
                                    return true
                                }
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Garden.muted)
                            .frame(width: 14)
                        let placeholder = project.tags.first.map { "为此大任务添加子任务 (继承 #\($0))..." } ?? "为此大任务添加子任务..."
                        TextField(placeholder, text: Binding(
                            get: { inlineSubtaskTitles[project.id] ?? "" },
                            set: { inlineSubtaskTitles[project.id] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit {
                            commitInlineSubtask(for: project.id)
                        }
                        if !(inlineSubtaskTitles[project.id] ?? "").isEmpty {
                            Button {
                                commitInlineSubtask(for: project.id)
                            } label: {
                                GardenActionIcon(name: "return", pointSize: 10, color: Garden.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 26)
                    .padding(.trailing, 8)
                    .padding(.vertical, 4)
                }
                .padding(.top, 3)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Garden.cornerMedium)
                .fill(Garden.surface.opacity(0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Garden.cornerMedium)
                .stroke(Garden.line.opacity(0.40), lineWidth: 1)
        )
    }

    private func commitInlineSubtask(for projectID: UUID) {
        guard let text = inlineSubtaskTitles[projectID], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let (title, tags) = FocusTodo.parseInput(text)
        guard !title.isEmpty else { return }
        timer.addTodo(title, tags: tags, projectID: projectID)
        inlineSubtaskTitles[projectID] = ""
    }

    @ViewBuilder
    private func looseTodosSection(looseTodos: [FocusTodo], hasProjects: Bool) -> some View {
        if hasProjects {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isLooseTodosCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: isLooseTodosCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Garden.muted)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "tray.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Garden.muted)

                    Text("独立待办 / 收集箱")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Garden.ink)

                    Text("\(looseTodos.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(Garden.muted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Garden.line.opacity(0.4))
                        .cornerRadius(3)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                if !isLooseTodosCollapsed {
                    if looseTodos.isEmpty {
                        Text("无独立待办")
                            .font(.caption)
                            .foregroundColor(Garden.muted)
                            .padding(.leading, 28)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(looseTodos) { todo in
                            todoRow(todo, isSubtask: false)
                                .onDrag {
                                    NSItemProvider(object: todo.id.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                                    guard let provider = providers.first else { return false }
                                    provider.loadObject(ofClass: NSString.self) { object, _ in
                                        guard let raw = object as? NSString,
                                              let sourceID = UUID(uuidString: raw as String),
                                              sourceID != todo.id else { return }
                                        DispatchQueue.main.async {
                                            timer.moveTodo(id: sourceID, before: todo.id)
                                        }
                                    }
                                    return true
                                }
                        }
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: Garden.cornerMedium)
                    .fill(Garden.surface.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Garden.cornerMedium)
                    .stroke(Garden.line.opacity(0.30), lineWidth: 1)
            )
        } else {
            ForEach(looseTodos) { todo in
                todoRow(todo, isSubtask: false)
                    .onDrag {
                        NSItemProvider(object: todo.id.uuidString as NSString)
                    }
                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        provider.loadObject(ofClass: NSString.self) { object, _ in
                            guard let raw = object as? NSString,
                                  let sourceID = UUID(uuidString: raw as String),
                                  sourceID != todo.id else { return }
                            DispatchQueue.main.async {
                                timer.moveTodo(id: sourceID, before: todo.id)
                            }
                        }
                        return true
                    }
            }
        }
    }

    @ViewBuilder
    private func archivedProjectsSection(archivedProjects: [FocusProject]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isArchivedCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isArchivedCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text("已归档大任务 (\(archivedProjects.count))")
                        .font(.caption.weight(.medium))
                    Spacer()
                }
                .foregroundColor(Garden.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if !isArchivedCollapsed {
                ForEach(archivedProjects) { project in
                    HStack {
                        Image(systemName: "archivebox")
                            .font(.system(size: 11))
                        Text(project.name)
                            .font(.caption)
                            .strikethrough()
                        Spacer()
                        Button("取消归档") {
                            timer.toggleProjectArchived(id: project.id)
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundColor(Garden.red)

                        Button("删除", role: .destructive) {
                            timer.deleteProject(id: project.id)
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundColor(Garden.muted)
                    }
                    .foregroundColor(Garden.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func todoRow(_ todo: FocusTodo, isSubtask: Bool = false) -> some View {
        let isCurrent = (timer.state.currentTodoID == todo.id || timer.preparedTodoID == todo.id)
        TodoRowView(
            todo: todo,
            isSubtask: isSubtask,
            isCurrent: isCurrent,
            timer: timer,
            editingTodoID: $editingTodoID,
            editingTodoTitle: $editingTodoTitle,
            onStartCustomTag: { id in
                customTagTargetTodoID = id
                customTagInput = ""
                showingCustomTagAlert = true
            },
            onNewProject: {
                showingNewProjectSheet = true
            }
        )
    }

    private func addTodo() {
        let (title, tags) = FocusTodo.parseInput(newTodoTitle)
        guard !title.isEmpty else { return }
        timer.addTodo(title, tags: tags, projectID: nil)
        newTodoTitle = ""
    }

    private var recordHeader: some View {
        HStack {
            Text(historyTab ? "所有专注记录" : "专注记录").font(.system(size: 17, weight: .semibold))
            if let category = selectedCategory {
                Button { selectedCategory = nil } label: { Label(category, systemImage: "xmark.circle.fill") }.buttonStyle(.plain).font(.caption).foregroundColor(Garden.red)
            }
            Text("\(visibleRecords.count) 段").font(.caption).foregroundColor(Garden.muted)
            Spacer()
            if historyTab {
                Menu(selectedCategory ?? "所有标签") {
                    Button("所有标签") { selectedCategory = nil }
                    ForEach(timer.state.allTags, id: \.self) { tag in Button(tag) { selectedCategory = tag } }
                }.frame(width: 140)
                TextField("搜索名称或标签", text: $search).textFieldStyle(.roundedBorder).frame(width: 190)
            } else {
                Text("按时间顺序").font(.caption).foregroundColor(Garden.muted)
            }
        }
    }
    private var recordList: some View {
        ZStack(alignment: .bottomTrailing) {
            if visibleRecords.isEmpty {
                VStack(spacing: 10) {
                    Text(historyTab ? "没有匹配的记录" : "这里会记下你做过的事情").font(.headline)
                    Text(historyTab && (selectedCategory != nil || !search.isEmpty)
                         ? "试试其他关键词，或清除标签筛选。"
                         : "从下方开始一段专注，结束后再为它添加标签。")
                        .font(.caption).foregroundColor(Garden.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleRecords) { record in
                            HStack(spacing: 10) {
                                Circle().fill(Garden.color(record.category, styles: timer.state.categoryStyles)).frame(width: 8, height: 8)
                                recordInformation(record).frame(maxWidth: .infinity, alignment: .leading)
                                Text(focusDuration(historyTab ? record.seconds : record.seconds(in: summary.interval)))
                                    .font(.system(size: 13).monospacedDigit()).frame(width: 72, alignment: .trailing)
                                Button { pendingDelete = record } label: {
                                    GardenActionIcon(name: "trash", color: Garden.red)
                                }.buttonStyle(.plain)
                                    .opacity(hoverDelete == record.id ? 1 : 0)
                                    .allowsHitTesting(hoverDelete == record.id)
                                    .help("删除记录").accessibilityLabel("删除记录：\(record.name)")
                                Menu {
                                    Button("编辑记录") { editing = record }
                                    Button("删除记录", role: .destructive) { pendingDelete = record }
                                } label: {
                                    Color.clear.frame(width: 24, height: 24).contentShape(Rectangle())
                                }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 24, height: 24)
                                    .overlay(GardenActionIcon(name: "ellipsis.circle").allowsHitTesting(false))
                                    .help("编辑或删除").accessibilityLabel("更多操作：\(record.name)")
                            }.padding(.vertical, 10)
                            .onHover { inside in
                                if inside { hoverDelete = record.id }
                                else if hoverDelete == record.id { hoverDelete = nil }
                            }
                            Rectangle().fill(Garden.line.opacity(0.55)).frame(height: 1)
                        }
                    }.padding(.trailing, 12)
                }
            }
        }.frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func recordInformation(_ record: FocusRecord) -> some View {
        if historyTab {
            HStack(spacing: 12) {
                recordTimestamp(record).frame(width: 115, alignment: .leading)
                Text(record.name).font(.system(size: 15)).lineLimit(1).help(record.name)
                Spacer(minLength: 8)
                recordTags(record).frame(maxWidth: 140, alignment: .trailing)
                if !record.completed { Text("提前结束").font(.caption2).foregroundColor(Garden.muted) }
            }
        } else {
            // Give the name the full flexible column; metadata no longer competes with
            // it in one line at the minimum window width.
            VStack(alignment: .leading, spacing: 5) {
                Text(record.name).font(.system(size: 14, weight: .medium)).lineLimit(1).help(record.name)
                HStack(spacing: 8) {
                    recordTimestamp(record).fixedSize()
                    recordTags(record)
                    if !record.completed {
                        Text("提前结束").font(.caption2).foregroundColor(Garden.muted).fixedSize()
                    }
                }
            }
        }
    }
    private func recordTags(_ record: FocusRecord) -> some View {
        Text(record.tags.isEmpty ? "未分类" : record.tags.joined(separator: " · "))
            .font(.caption).foregroundColor(Garden.color(record.category, styles: timer.state.categoryStyles))
            .lineLimit(1).help(record.tags.isEmpty ? "未分类" : record.tags.joined(separator: " · "))
    }
    private func recordTimestamp(_ record: FocusRecord) -> some View {
        Group {
            if historyTab || period != .day {
                Text(record.startedAt, format: .dateTime.month().day().hour().minute())
            } else {
                Text("\(record.startedAt.formatted(date: .omitted, time: .shortened)) – \(record.endedAt.formatted(date: .omitted, time: .shortened))")
            }
        }.font(.system(size: historyTab ? 12 : 11).monospacedDigit()).foregroundColor(Garden.muted)
            .help("\(record.startedAt.formatted()) — \(record.endedAt.formatted())；暂停不计入专注时长")
    }
}

struct TimerCard: View {
    @ObservedObject var timer: TBTimer
    @Binding var expanded: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 14) {
                GardenArt(name: "PixelTomato", activity: timer.windowActivity).frame(width: 38, height: 38)
                if timer.state.phase == .idle || timer.state.phase == .restFinished {
                    if let current = timer.state.currentTodo {
                        HStack(spacing: 8) {
                            Text("🎯")
                                .font(.system(size: 13))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    if let proj = current.projectID.flatMap({ timer.state.project(for: $0) }) {
                                        Text(proj.name)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Garden.ink)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Garden.surface.opacity(0.9))
                                            .cornerRadius(3)
                                    }
                                    Text("当前任务")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Garden.red)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Garden.red.opacity(0.12))
                                        .cornerRadius(3)
                                    if !current.tags.isEmpty {
                                        Text(current.tags.map { "#\($0)" }.joined(separator: " "))
                                            .font(.caption2)
                                            .foregroundColor(Garden.color(current.tags.first ?? "", styles: timer.state.categoryStyles))
                                    }
                                }
                                Text(current.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                            }
                            Menu {
                                Button("切回自由专注") { timer.selectCurrentTodo(nil) }
                                Divider()
                                if timer.state.pendingTodos.count > 1 {
                                    Text("切换到其他待办：")
                                    let activeProjects = timer.state.projects.filter { !$0.isArchived }
                                    let looseTodos = timer.state.pendingTodos.filter { $0.id != current.id && $0.projectID == nil }
                                    ForEach(activeProjects) { proj in
                                        let sub = timer.state.pendingTodos.filter { $0.id != current.id && $0.projectID == proj.id }
                                        if !sub.isEmpty {
                                            Section(proj.name) {
                                                ForEach(sub) { todo in
                                                    Button(todo.title) { timer.selectCurrentTodo(todo.id) }
                                                }
                                            }
                                        }
                                    }
                                    if !looseTodos.isEmpty {
                                        if !activeProjects.isEmpty {
                                            Section("独立待办") {
                                                ForEach(looseTodos) { todo in
                                                    Button(todo.title) { timer.selectCurrentTodo(todo.id) }
                                                }
                                            }
                                        } else {
                                            ForEach(looseTodos) { todo in
                                                Button(todo.title) { timer.selectCurrentTodo(todo.id) }
                                            }
                                        }
                                    }
                                }
                            } label: {
                                GardenActionIcon(name: "chevron.up.chevron.down", pointSize: 11, color: Garden.muted)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .frame(width: 20, height: 20)

                            Button {
                                timer.selectCurrentTodo(nil)
                            } label: {
                                GardenActionIcon(name: "xmark.circle.fill", pointSize: 13, color: Garden.muted)
                            }
                            .buttonStyle(.plain)
                            .help("切回自由专注")
                        }
                    } else {
                        HStack(spacing: 8) {
                            TextField("下一段，想专注什么？（支持 #标签）", text: Binding(
                                get: { timer.eventName },
                                set: { timer.setEventName($0) }
                            )).textFieldStyle(.plain).font(.system(size: 14))

                            if !timer.state.pendingTodos.isEmpty {
                                Menu {
                                    Text("选择已有待办专注：")
                                    let activeProjects = timer.state.projects.filter { !$0.isArchived }
                                    let looseTodos = timer.state.pendingTodos.filter { $0.projectID == nil }
                                    ForEach(activeProjects) { proj in
                                        let sub = timer.state.pendingTodos.filter { $0.projectID == proj.id }
                                        if !sub.isEmpty {
                                            Section(proj.name) {
                                                ForEach(sub) { todo in
                                                    Button(todo.title) { timer.selectCurrentTodo(todo.id) }
                                                }
                                            }
                                        }
                                    }
                                    if !looseTodos.isEmpty {
                                        if !activeProjects.isEmpty {
                                            Section("独立待办") {
                                                ForEach(looseTodos) { todo in
                                                    Button(todo.title) { timer.selectCurrentTodo(todo.id) }
                                                }
                                            }
                                        } else {
                                            ForEach(looseTodos) { todo in
                                                Button(todo.title) { timer.selectCurrentTodo(todo.id) }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "target")
                                            .font(.system(size: 11))
                                        Text("选任务")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(Garden.ink)
                                    .padding(.horizontal, 7)
                                    .frame(height: 28)
                                    .background(Garden.surface)
                                    .cornerRadius(Garden.cornerSmall)
                                }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                            }

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
                                HStack(spacing: 3) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 10))
                                    Text(timer.state.draftTags.isEmpty ? "标签" : timer.state.draftTags.map { "#\($0)" }.joined(separator: " "))
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(timer.state.draftTags.isEmpty ? Garden.muted : Garden.color(timer.state.draftTags.first ?? "", styles: timer.state.categoryStyles))
                                .padding(.horizontal, 7)
                                .frame(height: 28)
                                .background(Garden.surface)
                                .cornerRadius(Garden.cornerSmall)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(timer.state.name.isEmpty ? timer.phaseLabel : timer.state.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
                            if !timer.state.activeTags.isEmpty {
                                Text(timer.state.activeTags.map { "#\($0)" }.joined(separator: " "))
                                    .font(.caption2)
                                    .foregroundColor(Garden.color(timer.state.activeTags.first ?? "", styles: timer.state.categoryStyles))
                            }
                        }
                        Text(timer.phaseLabel).font(.caption).foregroundColor(Garden.muted)
                    }
                }
                Spacer()
                if timer.state.isTiming {
                    Text(timer.timeLeft).font(.system(size: 28, weight: .medium, design: .rounded).monospacedDigit())
                    if timer.state.phase == .rest {
                        Button("跳过休息") { timer.skipRest() }
                            .buttonStyle(.bordered)
                    }
                }
                Button(timer.state.isTiming ? (timer.state.paused ? "继续" : "暂停") : timer.state.needsAttention ? "查看提醒" : "开始专注") { timer.primaryAction() }
                    .buttonStyle(.borderedProminent).disabled(timer.storageError != nil && timer.state.phase == .idle)
                Button { expanded = true } label: { GardenActionIcon(name: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(.plain).help("展开倒计时").accessibilityLabel("展开倒计时")
            }
            if let error = timer.storageError {
                HStack(spacing: 10) {
                    Text(error).font(.caption).foregroundColor(.red)
                    Button(timer.storageRetryTitle) { timer.retryStorage() }
                    Button("打开记录文件夹") { timer.openRecordsFolder() }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Garden.red.opacity(0.075))
        .cornerRadius(Garden.cornerMedium)
    }
}

struct ExpandedTimer: View {
    @ObservedObject var timer: TBTimer
    let close: () -> Void
    @State private var showCancelConfirm = false
    // Opening the cancel dialog freezes the clock (see the popover): a completion behind
    // the modal would turn 「放弃这段」 into a silent no-op that keeps the record anyway.
    @State private var cancelWasPaused = false
    var body: some View {
        VStack(spacing: 18) {
            HStack { Spacer(); Button("收起", action: close).keyboardShortcut(.cancelAction) }
            GardenArt(name: "PixelTomato", activity: timer.windowActivity).frame(width: 110, height: 110)
            Text(timer.phaseLabel).foregroundColor(Garden.muted)
            if timer.state.phase == .idle || timer.state.phase == .restFinished {
                if let current = timer.state.currentTodo {
                    HStack(spacing: 8) {
                        Text("🎯")
                        if let proj = current.projectID.flatMap({ timer.state.project(for: $0) }) {
                            Text("[\(proj.name)] · \(current.title)").font(.title3).fontWeight(.medium)
                        } else {
                            Text(current.title).font(.title3).fontWeight(.medium)
                        }
                        if !current.tags.isEmpty {
                            Text(current.tags.map { "#\($0)" }.joined(separator: " "))
                                .font(.subheadline)
                                .foregroundColor(Garden.color(current.tags.first ?? "", styles: timer.state.categoryStyles))
                        }
                    }
                } else {
                    TextField("这次准备做什么？（支持 #标签）", text: Binding(
                        get: { timer.eventName },
                        set: { timer.setEventName($0) }
                    )).textFieldStyle(.roundedBorder).frame(width: 300)
                }
            }
            else { Text(timer.state.name).font(.title3).lineLimit(2) }
            Text(timer.state.isTiming ? timer.timeLeft : timer.state.needsAttention ? "完成" : "\(timer.workIntervalLength):00")
                .font(.system(size: 76, weight: .medium, design: .rounded).monospacedDigit()).foregroundColor(Garden.red)
            VStack(spacing: 10) {
                Button { timer.primaryAction() } label: {
                    Text(timer.state.isTiming ? (timer.state.paused ? "继续专注" : "暂停") : timer.state.needsAttention ? "查看提醒" : "开始专注")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(GardenPrimaryButtonStyle())
                if timer.state.isTiming {
                    HStack(spacing: 10) {
                        Button {
                            if timer.state.phase == .rest {
                                timer.skipRest()
                            } else {
                                timer.stop()
                            }
                        } label: {
                            Text(timer.state.phase == .work ? "结束并记录" : "跳过休息").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                        if timer.state.phase == .rest {
                            Button { timer.stop() } label: {
                                Text("结束本组").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered).foregroundColor(Garden.muted)
                        }
                        if timer.state.phase == .work {
                            Button {
                                cancelWasPaused = timer.state.paused
                                if timer.freezeForCancel() { showCancelConfirm = true }
                            } label: {
                                Text("取消专注").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered).foregroundColor(Garden.muted)
                                .help("丢弃这段专注，不保存为记录")
                        }
                    }
                }
            }.frame(maxWidth: 340)
            Text("收起或关闭主窗口后，菜单栏会继续陪你专注。").font(.caption).foregroundColor(Garden.muted)
        // Height follows the content: a fixed frame smaller than the work-state stack
        // clipped the caption against the sheet edge on both earlier attempts.
        }.padding(28).frame(width: 540)
            .background(Garden.paper).foregroundColor(Garden.ink).accentColor(Garden.red)
            .alert("取消这段专注？", isPresented: $showCancelConfirm) {
                Button("继续专注", role: .cancel) { if !cancelWasPaused { timer.togglePause() } }.keyboardShortcut(.cancelAction)
                Button("放弃这段", role: .destructive) { timer.cancel() }
            } message: { Text(cancelFocusMessage(timer.state)) }
    }
}

struct MainSettings: View {
    @ObservedObject var timer: TBTimer
    let close: () -> Void
    @AppStorage("gentleAnimations") private var animations = true
    @State private var easterEggTapCount = 0
    @State private var lastEasterEggTap = Date.distantPast
    @State private var easterEggNotice: String?

    private func registerEasterEggTap() {
        let now = Date()
        if now.timeIntervalSince(lastEasterEggTap) > 2 { easterEggTapCount = 0 }
        lastEasterEggTap = now
        easterEggTapCount += 1
        guard easterEggTapCount >= 7 else { return }
        easterEggTapCount = 0
        let enabled = timer.toggleSmokeBreakEasterEgg()
        easterEggNotice = enabled ? "🚬 休息彩蛋已开启" : "休息彩蛋已关闭"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { easterEggNotice = nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("设置").font(.title2); Spacer(); Button("完成", action: close).keyboardShortcut(.cancelAction) }
            GardenNumberInputRow(title: "专注", value: $timer.workIntervalLength, range: 1...180, unit: "分钟")
            GardenNumberInputRow(title: "短休息", value: $timer.shortRestIntervalLength, range: 1...60, unit: "分钟")
            GardenNumberInputRow(title: "长休息", value: $timer.longRestIntervalLength, range: 1...60, unit: "分钟")
            GardenNumberInputRow(title: "每组", value: $timer.workIntervalsInSet, range: 1...10, unit: "个番茄")
            Divider()
            Toggle("轻微像素动画", isOn: $animations)
            Toggle("菜单栏显示倒计时", isOn: $timer.showTimerInMenuBar).onChange(of: timer.showTimerInMenuBar) { _ in timer.updateStatus() }
            LaunchAtLogin.Toggle("登录时启动")
            KeyboardShortcuts.Recorder("开始 / 暂停 / 继续", name: .startStopTimer)
            Text("时长可直接输入数字，并从下一段生效。暂停与休息不计入专注；到时显示无声提醒。每条记录的第一个标签用于统计分类，可在编辑时更改。").font(.caption).foregroundColor(Garden.muted)
            HStack {
                Button("打开记录文件夹") { timer.openRecordsFolder() }
                Spacer()
                if let notice = easterEggNotice {
                    Text(notice).font(.caption).foregroundColor(Garden.muted).transition(.opacity)
                }
                Text("Personal · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                    .font(.caption).foregroundColor(Garden.muted)
                    .contentShape(Rectangle())
                    .onTapGesture { registerEasterEggTap() }
            }
        }.padding(28).frame(width: 460).background(Garden.paper).foregroundColor(Garden.ink).accentColor(Garden.red)
    }
}

struct TodoRowView: View {
    let todo: FocusTodo
    let isSubtask: Bool
    let isCurrent: Bool
    let timer: TBTimer
    @Binding var editingTodoID: UUID?
    @Binding var editingTodoTitle: String
    let onStartCustomTag: (UUID) -> Void
    let onNewProject: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if isSubtask {
                Spacer().frame(width: 14)
            }
            Button { timer.toggleTodo(id: todo.id) } label: {
                GardenActionIcon(name: todo.isCompleted ? "checkmark.circle.fill" : "circle", pointSize: 15,
                                 color: todo.isCompleted ? Garden.red : Garden.muted)
            }
            .buttonStyle(.plain)
            .help(todo.isCompleted ? "标记为未完成" : "标记完成")
            .accessibilityLabel("\(todo.isCompleted ? "标记为未完成" : "标记完成")：\(todo.title)")

            if editingTodoID == todo.id {
                TextField("待办名称", text: $editingTodoTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { commitTodoRename() }
                Button { commitTodoRename() } label: {
                    GardenActionIcon(name: "checkmark", pointSize: 12)
                }.buttonStyle(.plain).accessibilityLabel("保存待办名称")
                Button { editingTodoID = nil } label: {
                    GardenActionIcon(name: "xmark", pointSize: 12)
                }.buttonStyle(.plain).accessibilityLabel("取消重命名")
            } else {
                Button {
                    timer.selectCurrentTodo(todo.id)
                } label: {
                    HStack(spacing: 6) {
                        if isCurrent {
                            Text("🎯")
                                .font(.system(size: 11))
                        }
                        Text(todo.title)
                            .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                            .strikethrough(todo.isCompleted)
                            .foregroundColor(todo.isCompleted ? Garden.muted : Garden.ink)
                            .lineLimit(1)
                        if !todo.tags.isEmpty {
                            Text(todo.tags.map { "#\($0)" }.joined(separator: " "))
                                .font(.caption2.weight(.medium))
                                .foregroundColor(Garden.color(todo.tags.first ?? "", styles: timer.state.categoryStyles))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("设为当前专注任务")

                let seconds = timer.state.focusSeconds(forTodo: todo.id)
                if seconds > 0 {
                    Text(focusDuration(seconds))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(Garden.muted)
                }

                if !todo.isCompleted {
                    Button {
                        timer.selectCurrentTodo(todo.id)
                        timer.startWork()
                    } label: {
                        GardenActionIcon(name: "play.fill", pointSize: 12, color: Garden.red)
                    }
                    .buttonStyle(.plain)
                    .help("立即开始这项待办")
                    .accessibilityLabel("开始待办：\(todo.title)")
                    .disabled(timer.state.isTiming || timer.state.needsAttention || timer.storageError != nil)
                    .opacity(isHovered || isCurrent ? 1.0 : 0.0)
                }

                Menu {
                    Button("设为当前任务") { timer.selectCurrentTodo(todo.id) }
                    Menu("设置标签") {
                        if !todo.tags.isEmpty {
                            Button("清除标签") { timer.setTodoTags(id: todo.id, tags: []) }
                            Divider()
                        }
                        Button("+ 自定义新标签...") {
                            onStartCustomTag(todo.id)
                        }
                        Divider()
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
                    Menu("移至大任务") {
                        if todo.projectID != nil {
                            Button("移出大任务 (设为独立待办)") {
                                timer.setTodoProject(todoID: todo.id, projectID: nil)
                            }
                            Divider()
                        }
                        ForEach(timer.state.projects.filter { !$0.isArchived && $0.id != todo.projectID }) { proj in
                            Button(proj.name) {
                                timer.setTodoProject(todoID: todo.id, projectID: proj.id)
                            }
                        }
                        Divider()
                        Button("+ 新建大任务...") {
                            onNewProject()
                        }
                    }
                    Button("重命名") {
                        editingTodoID = todo.id
                        editingTodoTitle = todo.title
                    }
                    Button(todo.isCompleted ? "标记为未完成" : "标记完成") {
                        timer.toggleTodo(id: todo.id)
                    }
                    Divider()
                    Button("删除待办", role: .destructive) { timer.deleteTodo(id: todo.id) }
                } label: {
                    Color.clear.frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24, height: 24)
                .overlay(GardenActionIcon(name: "ellipsis", pointSize: 13).allowsHitTesting(false))
                .opacity(isHovered || isCurrent ? 1.0 : 0.0)
                .accessibilityLabel("更多待办操作：\(todo.title)").help("待办操作")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: Garden.cornerSmall)
                .fill(isCurrent ? Garden.red.opacity(0.10) : (isHovered ? Garden.line.opacity(0.20) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .opacity(todo.isCompleted ? 0.68 : 1)
    }

    private func commitTodoRename() {
        let title = editingTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        timer.renameTodo(id: todo.id, title: title)
        editingTodoID = nil
        editingTodoTitle = ""
    }
}

struct NewProjectSheet: View {
    let suggestedTags: [String]
    let onSave: (String, [String]) -> Void
    let onCancel: () -> Void
    @State private var name: String = ""
    @State private var tagInput: String = ""
    @SwiftUI.FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("新建大任务 / 项目")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .foregroundColor(Garden.muted)
            }
            Text("大任务用于规划长周期目标（如期末复习、比赛项目、课程作业），其下可拆解多项具体子任务，专注时长将自动汇总归属。")
                .font(.caption)
                .foregroundColor(Garden.muted)
                .lineSpacing(2)

            VStack(alignment: .leading, spacing: 6) {
                Text("大任务名称")
                    .font(.caption)
                    .foregroundColor(Garden.muted)
                TextField("例如：Robomaster 校内赛、材料力学大作业", text: $name)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Garden.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .stroke(Garden.line, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onSubmit { commit() }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("主分类标签 (可选)")
                        .font(.caption)
                        .foregroundColor(Garden.muted)
                    Spacer()
                    if !tagInput.isEmpty {
                        Button("清除") { tagInput = "" }
                            .font(.caption2)
                            .buttonStyle(.plain)
                            .foregroundColor(Garden.muted)
                    }
                }
                TextField("例如：竞赛、专业课、科研", text: $tagInput)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Garden.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .stroke(Garden.line, lineWidth: 1)
                    )
                    .onSubmit { commit() }

                if !suggestedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(suggestedTags.prefix(8)), id: \.self) { tag in
                                Button {
                                    tagInput = tag
                                } label: {
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .foregroundColor(tagInput == tag ? Garden.paper : Garden.muted)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule().fill(tagInput == tag ? Garden.red : Garden.surface)
                                        )
                                        .overlay(
                                            Capsule().stroke(tagInput == tag ? Garden.red : Garden.line, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                Text("下属子任务将默认自动继承此主标签，专注统计自动归集至该分类。")
                    .font(.caption2)
                    .foregroundColor(Garden.muted)
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("创建大任务") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GardenPrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Garden.paper)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cleanTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let tags = cleanTag.isEmpty ? [] : [cleanTag]
        onSave(trimmed, tags)
    }
}

struct EditProjectSheet: View {
    let project: FocusProject
    let suggestedTags: [String]
    let onSave: (String, [String]) -> Void
    let onCancel: () -> Void
    @State private var name: String = ""
    @State private var tagInput: String = ""
    @SwiftUI.FocusState private var isFocused: Bool

    init(project: FocusProject, suggestedTags: [String] = [], onSave: @escaping (String, [String]) -> Void, onCancel: @escaping () -> Void) {
        self.project = project
        self.suggestedTags = suggestedTags
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: project.name)
        _tagInput = State(initialValue: project.tags.first ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("编辑大任务 / 项目")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .foregroundColor(Garden.muted)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("大任务名称")
                    .font(.caption)
                    .foregroundColor(Garden.muted)
                TextField("大任务名称", text: $name)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Garden.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .stroke(Garden.line, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onSubmit { commit() }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("主分类标签 (可选)")
                        .font(.caption)
                        .foregroundColor(Garden.muted)
                    Spacer()
                    if !tagInput.isEmpty {
                        Button("清除") { tagInput = "" }
                            .font(.caption2)
                            .buttonStyle(.plain)
                            .foregroundColor(Garden.muted)
                    }
                }
                TextField("例如：竞赛、专业课、科研", text: $tagInput)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Garden.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Garden.cornerSmall)
                            .stroke(Garden.line, lineWidth: 1)
                    )
                    .onSubmit { commit() }

                if !suggestedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(suggestedTags.prefix(8)), id: \.self) { tag in
                                Button {
                                    tagInput = tag
                                } label: {
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .foregroundColor(tagInput == tag ? Garden.paper : Garden.muted)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule().fill(tagInput == tag ? Garden.red : Garden.surface)
                                        )
                                        .overlay(
                                            Capsule().stroke(tagInput == tag ? Garden.red : Garden.line, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                Text("修改后新建子任务将继承新主标签，已创建子任务保留既有标签。")
                    .font(.caption2)
                    .foregroundColor(Garden.muted)
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("保存修改") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GardenPrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Garden.paper)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cleanTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let tags = cleanTag.isEmpty ? [] : [cleanTag]
        onSave(trimmed, tags)
    }
}

typealias RenameProjectSheet = EditProjectSheet
