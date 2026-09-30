import SwiftUI
import WidgetKit

private enum WidgetGarden {
    static let paper = Color(red: 0.97, green: 0.94, blue: 0.88)
    static let surface = Color(red: 0.985, green: 0.965, blue: 0.925)
    static let ink = Color(red: 0.29, green: 0.20, blue: 0.15)
    static let muted = Color(red: 0.55, green: 0.47, blue: 0.38)
    static let red = Color(red: 0.70, green: 0.30, blue: 0.24)
    static let line = Color(red: 0.86, green: 0.81, blue: 0.71)
}

struct TomatoBarWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TomatoBarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TomatoBarWidgetEntry {
        TomatoBarWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TomatoBarWidgetEntry) -> Void) {
        completion(TomatoBarWidgetEntry(
            date: Date(),
            snapshot: WidgetSnapshotStore.load() ?? .placeholder
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TomatoBarWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        let entry = TomatoBarWidgetEntry(date: now, snapshot: snapshot)

        var refresh = now.addingTimeInterval(15 * 60)
        if let deadline = snapshot.deadline, deadline > now {
            refresh = min(refresh, deadline.addingTimeInterval(2))
        }
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct TomatoBarWidgetView: View {
    let entry: TomatoBarWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var openURL: URL {
        URL(string: "tomatobar-personal://open")!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            status

            if family == .systemMedium {
                Divider().overlay(WidgetGarden.line.opacity(0.6))
                todoList
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .foregroundStyle(WidgetGarden.ink)
        .containerBackground(for: .widget) { WidgetGarden.paper }
        .widgetURL(openURL)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text("🍅")
                .font(.system(size: 18))
            Text("TomatoBar")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Text(todayText)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(WidgetGarden.muted)
        }
    }

    @ViewBuilder
    private var status: some View {
        if entry.snapshot.isTiming {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.snapshot.currentName?.isEmpty == false ? entry.snapshot.currentName! : entry.snapshot.phaseLabel)
                        .font(.system(size: family == .systemSmall ? 15 : 14, weight: .semibold))
                        .lineLimit(1)
                    Text(entry.snapshot.phaseLabel)
                        .font(.caption2)
                        .foregroundStyle(WidgetGarden.muted)
                }
                Spacer()
                timerText
            }
            .padding(10)
            .background(WidgetGarden.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.snapshot.phaseLabel)
                        .font(.system(size: 14, weight: .semibold))
                    Text("完成 \(entry.snapshot.todayCount) 个番茄")
                        .font(.caption2)
                        .foregroundStyle(WidgetGarden.muted)
                }
                Spacer()
                Image(systemName: "leaf")
                    .foregroundStyle(WidgetGarden.red)
            }
            .padding(10)
            .background(WidgetGarden.surface, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var timerText: some View {
        if entry.snapshot.paused {
            Text(formatDuration(entry.snapshot.remainingSeconds))
                .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(WidgetGarden.red)
        } else if let deadline = entry.snapshot.deadline, deadline > entry.date {
            Text(timerInterval: entry.date...deadline, countsDown: true)
                .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(WidgetGarden.red)
        } else {
            Text(formatDuration(entry.snapshot.remainingSeconds))
                .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(WidgetGarden.red)
        }
    }

    private var todoList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("接下来")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(entry.snapshot.pendingTodoCount) 项")
                    .font(.caption2)
                    .foregroundStyle(WidgetGarden.muted)
            }

            if entry.snapshot.todos.isEmpty {
                Text("还没有待办。打开 TomatoBar 添加下一件事。")
                    .font(.caption)
                    .foregroundStyle(WidgetGarden.muted)
                    .lineLimit(2)
            } else {
                ForEach(entry.snapshot.todos.prefix(3)) { todo in
                    Link(destination: todoURL(todo.id)) {
                        HStack(spacing: 7) {
                            Image(systemName: "circle")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(WidgetGarden.muted)
                            Text(todo.title)
                                .font(.system(size: 12))
                                .foregroundStyle(WidgetGarden.ink)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(WidgetGarden.muted.opacity(0.7))
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    private var todayText: String {
        let minutes = Int(entry.snapshot.todaySeconds / 60)
        return minutes > 0 ? "今日 \(minutes) 分" : "今日 0 分"
    }

    private func todoURL(_ id: UUID) -> URL {
        URL(string: "tomatobar-personal://todo/\(id.uuidString)")!
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(ceil(seconds)))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

struct TomatoBarWidget: Widget {
    let kind = "TomatoBarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TomatoBarWidgetProvider()) { entry in
            TomatoBarWidgetView(entry: entry)
        }
        .configurationDisplayName("TomatoBar")
        .description("查看今日专注、当前状态和接下来要做的事。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TomatoBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        TomatoBarWidget()
    }
}
