import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name { static let startStopTimer = Self("startStopTimer") }

struct TBPopoverView: View {
    @ObservedObject var timer: TBTimer
    @State private var tab = 0
    @State private var editingRecord: FocusRecord?
    @State private var selectedTag: String?
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
                HStack {
                    Button(timer.state.paused ? "继续" : "暂停") { timer.togglePause() }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    Button(timer.state.phase == .work ? "结束并记录" : "结束休息") { timer.stop() }
                }.frame(maxWidth: .infinity)
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
                VStack(alignment: .leading) {
                    Text(error).foregroundColor(.red)
                    Button("重试保存") { timer.retrySave() }
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
            }.frame(height: 270)
            Divider()
            HStack {
                Button("打开主窗口") { TBStatusItem.shared?.showMainWindow() }
                    .buttonStyle(.plain).font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }.buttonStyle(.plain)
            }
        }.padding(18).frame(width: 350)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let record = editingRecord {
                RecordEditor(record: record, availableTags: timer.state.allTags, onCancel: {
                    editingRecord = nil
                }, onSave: { name, tags in
                    let error = timer.editRecord(id: record.id, name: name, tags: tags)
                    if error == nil {
                        if let tag = selectedTag, !timer.state.records.contains(where: { $0.hasTag(tag) }) {
                            selectedTag = nil
                        }
                        editingRecord = nil
                    }
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

struct RecordEditor: View {
    let availableTags: [String]
    let onCancel: () -> Void
    let onSave: (String, [String]) -> String?
    @State private var name: String
    @State private var tags: [String]
    @State private var newTag = ""
    @State private var error: String?

    init(record: FocusRecord, availableTags: [String], onCancel: @escaping () -> Void,
         onSave: @escaping (String, [String]) -> String?) {
        self.availableTags = availableTags
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: record.name)
        _tags = State(initialValue: record.tags)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("编辑记录").font(.headline)
            TextField("事件名称", text: $name).textFieldStyle(.roundedBorder)
                .accessibilityLabel("修改事件名称")
            HStack {
                TextField("新标签，例如：学习", text: $newTag)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("新标签")
                    .onSubmit { addTag() }
                Button("添加") { addTag() }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if tags.count > 1 {
                Menu("统计分类：\(tags.first ?? "未分类")") {
                    ForEach(tags, id: \.self) { tag in
                        Button(tag) { tags = [tag] + tags.filter { $0 != tag } }
                    }
                }.help("每条记录只计入一个分类，其余标签仍可用于筛选")
            }
            Menu("选择已有标签") {
                ForEach(availableTags, id: \.self) { tag in
                    Button(tag) { tags = FocusRecord.normalizedTags(tags + [tag]) }
                        .disabled(tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame })
                }
            }.disabled(availableTags.isEmpty)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag).lineLimit(1).help(tag)
                            Spacer(minLength: 0)
                            Button { tags.removeAll { $0 == tag } } label: {
                                Image(systemName: "xmark.circle.fill")
                            }.buttonStyle(.plain).accessibilityLabel("移除标签：\(tag)")
                        }.font(.caption).padding(5)
                            .background(Color.accentColor.opacity(0.12)).cornerRadius(5)
                    }
                }
                if tags.isEmpty { Text("暂无标签").font(.caption).foregroundColor(.secondary) }
            }.frame(maxHeight: .infinity)
            if let error = error { Text(error).font(.caption).foregroundColor(.red) }
            HStack {
                Text("时长和完成状态保持不变").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Button("取消", action: onCancel)
                Button("保存") {
                    addTag()
                    error = onSave(name, tags)
                }.buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    private func addTag() {
        tags = FocusRecord.normalizedTags(tags + [newTag])
        newTag = ""
    }
}
