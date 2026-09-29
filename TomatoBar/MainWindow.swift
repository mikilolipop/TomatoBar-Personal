import SwiftUI
import LaunchAtLogin
import KeyboardShortcuts

struct MainWindowView: View {
    let timer: TBTimer
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
        VStack(spacing: 0) {
            header
            Rectangle().fill(Garden.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 20) {
                if !historyTab {
                    heading
                    HStack(alignment: .top, spacing: 36) {
                        summaryPanel.frame(width: 340)
                        FocusChart(summary: filtered, styles: timer.state.categoryStyles, activity: timer.windowActivity, period: period, onDay: { date = $0; period = .day }, onRecord: { editing = $0 })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.frame(minHeight: 170, idealHeight: 280, maxHeight: 280)
                    Rectangle().fill(Garden.line).frame(height: 1)
                }
                recordHeader
                if let message = deleteError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Garden.red)
                        Text(message).font(.caption).foregroundColor(Garden.red)
                        Spacer()
                        Button("知道了") { deleteError = nil }.font(.caption)
                    }.padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Garden.red.opacity(0.08)).cornerRadius(6)
                }
                recordList
            }.padding(.horizontal, 32).padding(.top, 23)
            TimerCard(timer: timer, expanded: $expandedTimer).padding(20)
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
            GardenArt(name: "PixelTomato", activity: timer.windowActivity).frame(width: 38, height: 38)
            Text("TomatoBar").font(.system(size: 21, weight: .bold, design: .rounded))
            Spacer().frame(width: 28)
            Button("概览") { historyTab = false; search = ""; selectedCategory = nil }.font(.system(size: 15, weight: .medium))
                .foregroundColor(historyTab ? Garden.muted : Garden.red)
            Button("历史") { historyTab = true; selectedCategory = nil }.font(.system(size: 15, weight: .medium)).padding(.leading, 16)
                .foregroundColor(historyTab ? Garden.red : Garden.muted)
            Spacer()
            Text("让专注，慢慢生长").font(.caption).foregroundColor(Garden.muted)
            Button { settings = true } label: { Image(systemName: "gearshape").font(.system(size: 18)) }
                .padding(.leading, 16).help("设置").accessibilityLabel("设置")
        }.buttonStyle(.plain).padding(.horizontal, 28).frame(height: 62)
    }
    private var heading: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text(period == .day ? (Calendar.current.isDateInToday(date) ? "今天，把时间留给了什么？" : "这一天，把时间留给了什么？") : period == .week ? "这一周的专注时光" : "这个月，留下的点点滴滴")
                    .font(.system(size: 36, weight: .semibold))
                HStack(spacing: 12) {
                    Button { step(-1) } label: { Image(systemName: "chevron.left") }.help("上一\(period.rawValue)")
                    Text(dateTitle).font(.system(size: 13))
                    Button { step(1) } label: { Image(systemName: "chevron.right") }
                        .disabled(summary.interval.end > Date()).help("下一\(period.rawValue)")
                    if !summary.interval.contains(Date()) { Button("回到今天") { date = Date() } }
                }.buttonStyle(.plain).foregroundColor(Garden.muted)
            }
            Spacer()
            HStack(spacing: 3) {
                ForEach(FocusPeriod.allCases) { option in
                    Button { period = option } label: {
                        Text(option.rawValue).font(.system(size: 15, weight: .medium))
                            .frame(width: 48, height: 32)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("\(period == .day ? "当日" : period == .week ? "本周" : "本月")累计专注（不含进行中）").font(.system(size: 13)).foregroundColor(Garden.muted)
            Text(focusDuration(summary.seconds)).font(.system(size: 46, weight: .semibold, design: .rounded)).foregroundColor(Garden.red).minimumScaleFactor(0.7).lineLimit(1)
            ScrollView {
                VStack(spacing: 7) {
                    ForEach(showAllCategories ? summary.categories : Array(summary.categories.prefix(5))) { category in
                        Button { selectedCategory = selectedCategory == category.name ? nil : category.name } label: {
                            HStack {
                                Rectangle().fill(Garden.color(category.name)).frame(width: 10, height: 10)
                                Text(category.name).lineLimit(1)
                                Spacer()
                                Text(focusDuration(category.seconds)).foregroundColor(Garden.muted)
                            }.font(.system(size: 14)).padding(.vertical, 1)
                                .background(selectedCategory == category.name ? Garden.line.opacity(0.4) : .clear)
                        }.buttonStyle(.plain)
                    }
                    if summary.categories.count > 5 {
                        Button(showAllCategories ? "收起标签" : "展开其余 \(summary.categories.count - 5) 个标签") { showAllCategories.toggle() }
                            .buttonStyle(.plain).font(.caption).foregroundColor(Garden.muted).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if summary.categories.isEmpty { Text("专注之后，再来看看时间的去向。 ").font(.caption).foregroundColor(Garden.muted) }
                }.padding(.trailing, 8)
            }
            HStack {
                GardenArt(name: "PixelSprout", activity: timer.windowActivity).frame(width: 46, height: 35)
                Text("每一段投入，都有迹可循").font(.caption2).foregroundColor(Garden.muted)
                Spacer()
            }
        }
    }
    private var recordHeader: some View {
        HStack {
            Text(historyTab ? "所有专注记录" : "专注记录").font(.system(size: 18, weight: .semibold))
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
                GardenArt(name: "PixelPlant", activity: timer.windowActivity).frame(width: 60, height: 28)
            }
        }
    }
    private var recordList: some View {
        ZStack(alignment: .bottomTrailing) {
            if visibleRecords.isEmpty {
                VStack(spacing: 10) {
                    Text(historyTab ? "没有匹配的记录" : "这里会记下你做过的事情").font(.headline)
                    Text("从下方开始一段专注，结束后再为它添加标签。").font(.caption).foregroundColor(Garden.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleRecords) { record in
                            HStack(spacing: 12) {
                                Circle().fill(Garden.color(record.category)).frame(width: 8, height: 8)
                                Group {
                                    if historyTab || period != .day {
                                        Text(record.startedAt, format: .dateTime.month().day().hour().minute())
                                    } else {
                                        Text("\(record.startedAt.formatted(date: .omitted, time: .shortened)) – \(record.endedAt.formatted(date: .omitted, time: .shortened))")
                                    }
                                }.font(.system(size: 12).monospacedDigit()).foregroundColor(Garden.muted)
                                    .frame(width: 125, alignment: .leading)
                                    .help("\(record.startedAt.formatted()) — \(record.endedAt.formatted())；暂停不计入专注时长")
                                Text(record.name).font(.system(size: 15)).lineLimit(1).help(record.name)
                                Spacer()
                                Text(record.tags.isEmpty ? "未分类" : record.tags.joined(separator: " · ")).font(.caption).foregroundColor(Garden.color(record.category)).lineLimit(1).frame(maxWidth: 140, alignment: .trailing)
                                if !record.completed { Text("提前结束").font(.caption2).foregroundColor(Garden.muted) }
                                Text(focusDuration(historyTab ? record.seconds : record.seconds(in: summary.interval)))
                                    .font(.system(size: 13).monospacedDigit()).frame(width: 90, alignment: .trailing)
                                Button { pendingDelete = record } label: {
                                    Image(systemName: "trash").foregroundColor(Garden.red)
                                }.buttonStyle(.plain)
                                    .opacity(hoverDelete == record.id ? 1 : 0)
                                    .allowsHitTesting(hoverDelete == record.id)
                                    .help("删除记录").accessibilityLabel("删除记录：\(record.name)")
                                Menu {
                                    Button("编辑记录") { editing = record }
                                    Button("删除记录", role: .destructive) { pendingDelete = record }
                                } label: {
                                    Image(systemName: "ellipsis.circle").foregroundColor(Garden.muted)
                                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                                    .help("编辑或删除").accessibilityLabel("更多操作：\(record.name)")
                            }.padding(.vertical, 12)
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
}

struct TimerCard: View {
    @ObservedObject var timer: TBTimer
    @Binding var expanded: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 14) {
                GardenArt(name: "PixelTomato", activity: timer.windowActivity).frame(width: 44, height: 44)
                if timer.state.phase == .idle {
                    TextField("下一段，想专注什么？", text: $timer.eventName).textFieldStyle(.plain).font(.system(size: 15))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timer.state.name.isEmpty ? timer.phaseLabel : timer.state.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
                        Text(timer.phaseLabel).font(.caption).foregroundColor(Garden.muted)
                    }
                }
                Spacer()
                if timer.state.isTiming { Text(timer.timeLeft).font(.system(size: 28, weight: .medium, design: .rounded).monospacedDigit()) }
                Button(timer.state.isTiming ? (timer.state.paused ? "继续" : "暂停") : timer.state.needsAttention ? "查看提醒" : "开始专注") { timer.primaryAction() }
                    .buttonStyle(.borderedProminent).disabled(timer.storageError != nil && timer.state.phase == .idle)
                Button { expanded = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(.plain).help("展开倒计时").accessibilityLabel("展开倒计时")
            }
            if let error = timer.storageError {
                HStack(spacing: 10) {
                    Text(error).font(.caption).foregroundColor(.red)
                    Button(timer.storageRetryTitle) { timer.retryStorage() }
                    Button("打开记录文件夹") { timer.openRecordsFolder() }
                }
            }
        }.padding(.horizontal, 18).padding(.vertical, 9).background(Garden.red.opacity(0.085)).cornerRadius(9)
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
            if timer.state.phase == .idle { TextField("这次准备做什么？", text: $timer.eventName).textFieldStyle(.roundedBorder).frame(width: 300) }
            else { Text(timer.state.name).font(.title3).lineLimit(2) }
            Text(timer.state.isTiming ? timer.timeLeft : timer.state.needsAttention ? "完成" : "\(timer.workIntervalLength):00")
                .font(.system(size: 76, weight: .medium, design: .rounded).monospacedDigit()).foregroundColor(Garden.red)
            VStack(spacing: 10) {
                Button { timer.primaryAction() } label: {
                    Text(timer.state.isTiming ? (timer.state.paused ? "继续专注" : "暂停") : timer.state.needsAttention ? "查看提醒" : "开始专注")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large)
                if timer.state.isTiming {
                    HStack(spacing: 10) {
                        Button { timer.stop() } label: {
                            Text(timer.state.phase == .work ? "结束并记录" : "结束休息").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("设置").font(.title2); Spacer(); Button("完成", action: close).keyboardShortcut(.cancelAction) }
            Stepper("专注：\(timer.workIntervalLength) 分钟", value: $timer.workIntervalLength, in: 1...180)
            Stepper("短休息：\(timer.shortRestIntervalLength) 分钟", value: $timer.shortRestIntervalLength, in: 1...60)
            Stepper("长休息：\(timer.longRestIntervalLength) 分钟", value: $timer.longRestIntervalLength, in: 1...60)
            Stepper("每组：\(timer.workIntervalsInSet) 个番茄", value: $timer.workIntervalsInSet, in: 1...10)
            Divider()
            Toggle("轻微像素动画", isOn: $animations)
            Toggle("菜单栏显示倒计时", isOn: $timer.showTimerInMenuBar).onChange(of: timer.showTimerInMenuBar) { _ in timer.updateStatus() }
            LaunchAtLogin.Toggle("登录时启动")
            KeyboardShortcuts.Recorder("开始 / 暂停 / 继续", name: .startStopTimer)
            Text("时长调整从下一段生效。暂停与休息不计入专注；到时显示无声提醒。每条记录的第一个标签用于统计分类，可在编辑时更改。").font(.caption).foregroundColor(Garden.muted)
            HStack { Button("打开记录文件夹") { timer.openRecordsFolder() }; Spacer(); Text("Personal · V1.3").font(.caption).foregroundColor(Garden.muted) }
        }.padding(28).frame(width: 460).background(Garden.paper).foregroundColor(Garden.ink).accentColor(Garden.red)
    }
}
