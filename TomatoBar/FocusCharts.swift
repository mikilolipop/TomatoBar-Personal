import SwiftUI

enum Garden {
    static let paper = Color(red: 0.97, green: 0.94, blue: 0.88)
    static let ink = Color(red: 0.29, green: 0.20, blue: 0.15)
    static let muted = Color(red: 0.55, green: 0.47, blue: 0.38)
    static let red = Color(red: 0.70, green: 0.30, blue: 0.24)
    static let line = Color(red: 0.86, green: 0.81, blue: 0.71)
    static let colors: [Color] = [red, Color(red: 0.53, green: 0.61, blue: 0.43),
        Color(red: 0.81, green: 0.65, blue: 0.34), Color(red: 0.48, green: 0.62, blue: 0.66),
        Color(red: 0.71, green: 0.54, blue: 0.40), Color(red: 0.65, green: 0.59, blue: 0.70),
        Color(red: 0.75, green: 0.62, blue: 0.54), Color(red: 0.43, green: 0.54, blue: 0.48)]
    static func symbol(_ name: String) -> String {
        switch name {
        case "材料力学", "阅读": return "book.closed"
        case "建模": return "leaf"
        case "英语": return "headphones"
        case "编程": return "laptopcomputer"
        case "数学": return "function"
        case "写作": return "pencil"
        default: return "square.grid.2x2"
        }
    }
    static func color(_ name: String) -> Color {
        if name == "未分类" { return muted }
        let known = ["材料力学", "建模", "英语", "编程", "阅读", "数学", "写作"]
        if let index = known.firstIndex(of: name) { return colors[index] }
        let hash = name.lowercased().utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        return colors[Int(hash % UInt64(colors.count))]
    }
}

struct GardenArt: View {
    let name: String
    @ObservedObject var activity: WindowActivity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("gentleAnimations") private var animations = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: !activity.visible || activity.paused || reduceMotion || !animations)) { context in
            let moving = activity.visible && !activity.paused && !reduceMotion && animations
            let wave = moving ? sin(context.date.timeIntervalSinceReferenceDate * 1.5) : 0
            Image(name).resizable().interpolation(.none).scaledToFit()
                .rotationEffect(.degrees(name == "PixelTomato" ? 0 : wave * 1.8), anchor: .bottom)
                .scaleEffect(name == "PixelTomato" ? 1 + wave * 0.012 : 1, anchor: .bottom)
        }.accessibilityHidden(true)
    }
}

struct FocusChart: View {
    let summary: FocusSummary
    @ObservedObject var activity: WindowActivity
    @AppStorage("gentleAnimations") private var animations = true
    let period: FocusPeriod
    let onDay: (Date) -> Void
    let onRecord: (FocusRecord) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let calendar = Calendar.current
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(period == .day ? "专注足迹" : period == .week ? "这一周，慢慢积累" : "这个月的专注日历")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(period == .day ? "\(summary.records.count) 段" : "点击日期查看").font(.caption).foregroundColor(Garden.muted)
            }
            if period == .day { dayChart }
            else if period == .week { weekChart }
            else { monthChart }
        }.foregroundColor(Garden.ink)
            .animation(!reduceMotion && animations && activity.visible && !activity.paused ? .easeInOut(duration: 0.25) : nil, value: summary.records.map(\.id))
    }
    private func rows(width: CGFloat) -> [[FocusRecord]] {
        var result: [[FocusRecord]] = [[]]
        var used: CGFloat = 0
        for record in summary.records {
            let size = tileWidth(record, available: width)
            if used > 0 && used + 8 + size > width { result.append([]); used = 0 }
            result[result.count - 1].append(record)
            used += size + (used > 0 ? 8 : 0)
        }
        return result
    }
    private func tileWidth(_ record: FocusRecord, available: CGFloat) -> CGFloat {
        min(max(1, available), max(44, min(200, CGFloat(record.seconds(in: summary.interval) / 60) * 4.0)))
    }
    private var dayChart: some View {
        VStack(alignment: .leading, spacing: 8) {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    if summary.records.isEmpty {
                        Text("还没有足迹。完成一段专注后，它会留在这里。")
                            .foregroundColor(Garden.muted).padding(.vertical, 50)
                    }
                    ForEach(Array(rows(width: geometry.size.width - 8).enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 8) {
                            ForEach(row) { record in
                                Button { onRecord(record) } label: {
                                    Image(systemName: Garden.symbol(record.category)).font(.system(size: 22, weight: .medium))
                                        .foregroundColor(Garden.paper)
                                        .frame(width: tileWidth(record, available: geometry.size.width - 8), height: 68)
                                        .background(Garden.color(record.category).opacity(0.85))
                                        .cornerRadius(5)
                                }.buttonStyle(.plain).help("\(record.name) · \(record.category) · \(focusDuration(record.seconds(in: summary.interval)))")
                                    .accessibilityLabel("编辑专注：\(record.name)")
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
            }
        }
        Text("每一块是一段专注 · 按时间排列 · 点击可编辑")
            .font(.caption).foregroundColor(Garden.muted)
        }
    }
    private var weekChart: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(summary.days) { day in
                    Button { onDay(day.date) } label: {
                        VStack(spacing: 7) {
                            Text(day.seconds > 0 ? "\(Int(day.seconds / 60))分" : "—")
                                .font(.system(size: 11)).foregroundColor(Garden.muted)
                            VStack(spacing: 0) {
                                ForEach(day.categories.reversed()) { category in
                                    Rectangle().fill(Garden.color(category.name).opacity(0.78))
                                        .frame(height: CGFloat(category.seconds / max(1, summary.days.map(\.seconds).max() ?? 1)) * max(20, geometry.size.height - 66))
                                }
                            }.frame(maxWidth: .infinity).frame(height: max(20, geometry.size.height - 64), alignment: .bottom)
                            Text(day.date, format: .dateTime.weekday(.abbreviated)).font(.system(size: 12))
                            Text(day.date, format: .dateTime.day()).font(.system(size: 10)).foregroundColor(Garden.muted)
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(day.date > Date())
                        .help("\(day.date.formatted(date: .abbreviated, time: .omitted)) · \(focusDuration(day.seconds))")
                }
            }
        }
    }
    private var monthChart: some View {
        let offset = (calendar.component(.weekday, from: summary.interval.start) + 5) % 7
        let maxSeconds = max(1, summary.days.map(\.seconds).max() ?? 1)
        return GeometryReader { geometry in
        let rowCount = Double((offset + summary.days.count + 6) / 7)
        let cellHeight = max(20, min(38, (geometry.size.height - 60) / rowCount))
        VStack(spacing: 5) {
            HStack { ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { Text($0).font(.caption).frame(maxWidth: .infinity) } }
                .foregroundColor(Garden.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 5) {
                ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: cellHeight) }
                ForEach(summary.days) { day in
                    Button { onDay(day.date) } label: {
                        Text("\(calendar.component(.day, from: day.date))").font(.system(size: 12, weight: calendar.isDateInToday(day.date) ? .bold : .regular))
                            .frame(maxWidth: .infinity).frame(height: cellHeight)
                            .background(day.seconds > 0 ? Garden.red.opacity(0.12 + 0.56 * day.seconds / maxSeconds) : Garden.line.opacity(0.32))
                            .overlay(Rectangle().stroke(calendar.isDateInToday(day.date) ? Garden.red : .clear, lineWidth: 1))
                    }.buttonStyle(.plain).disabled(day.date > Date()).opacity(day.date > Date() ? 0.35 : 1)
                        .help("\(day.date.formatted(date: .abbreviated, time: .omitted)) · \(focusDuration(day.seconds))")
                }
            }
            HStack(spacing: 4) {
                Spacer(); Text("少")
                ForEach(0..<5) { index in Rectangle().fill(Garden.red.opacity(0.12 + Double(index) * 0.14)).frame(width: 13, height: 9) }
                Text("多")
            }.font(.caption2).foregroundColor(Garden.muted)
        }
        }
    }
}
