import AppKit
import SwiftUI

enum Garden {
    /// One source of truth for palette names and RGB values. The SwiftUI charts and the
    /// AppKit-backed native menu swatches are derived from the same entries, so they cannot
    /// silently drift to different shades.
    struct PaletteColor {
        let name: String
        let red: Double
        let green: Double
        let blue: Double

        var color: Color { Color(red: red, green: green, blue: blue) }
        var nsColor: NSColor {
            NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
        }
    }

    static let colorPalette: [PaletteColor] = [
        PaletteColor(name: "番茄红", red: 0.70, green: 0.30, blue: 0.24),
        PaletteColor(name: "鼠尾草绿", red: 0.53, green: 0.61, blue: 0.43),
        PaletteColor(name: "暖黄", red: 0.81, green: 0.65, blue: 0.34),
        PaletteColor(name: "雾蓝", red: 0.48, green: 0.62, blue: 0.66),
        PaletteColor(name: "陶土棕", red: 0.71, green: 0.54, blue: 0.40),
        PaletteColor(name: "灰紫", red: 0.65, green: 0.59, blue: 0.70),
        PaletteColor(name: "豆沙粉", red: 0.75, green: 0.62, blue: 0.54),
        PaletteColor(name: "松石绿", red: 0.43, green: 0.54, blue: 0.48)
    ]
    static let colors: [Color] = colorPalette.map(\.color)
    static let colorNames: [String] = colorPalette.map(\.name)

    static let paper = Color(red: 0.97, green: 0.94, blue: 0.88)
    static let ink = Color(red: 0.29, green: 0.20, blue: 0.15)
    static let muted = Color(red: 0.55, green: 0.47, blue: 0.38)
    static let red = colorPalette[0].color
    static let line = Color(red: 0.86, green: 0.81, blue: 0.71)
    // Shared surfaces/radii for the main window and menu-bar popover. Keeping these
    // tokens here prevents the two UI surfaces from drifting into separate visual systems.
    static let surface = Color(red: 0.985, green: 0.965, blue: 0.925)
    static let surfaceMuted = Color(red: 0.93, green: 0.88, blue: 0.79)
    static let cornerSmall: CGFloat = 7
    static let cornerMedium: CGFloat = 10
    static let cornerLarge: CGFloat = 14
    /// Categories offered in the record editor. These are suggestions only: choosing one
    /// tags that record and nothing else — no sample records, no edits to existing ones,
    /// no invented statistics.
    ///
    /// Order is load-bearing. `color()` indexes `colors` by position in this array, so
    /// reordering or inserting an entry would silently recolour records the user has
    /// already tagged. Append new suggestions at the end only.
    static let suggestedCategories = ["材料力学", "建模", "英语", "编程", "阅读", "数学", "写作"]
    /// FNV-1a over the lowercased name, shared by color() and symbol() so a category's
    /// colour and fallback glyph are both stable for a given name.
    private static func hashOf(_ name: String) -> UInt64 {
        name.lowercased().utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }
    /// Glyphs for categories outside the named set. Hashing means different custom
    /// categories look different; before this, every one of them collapsed onto a single
    /// grid glyph, which made the day tiles and the editor preview carry no information.
    /// Deliberately disjoint from the named symbols so a custom tag never looks like one
    /// of the seven.
    static let symbolFallbacks = ["tag", "book", "paintbrush", "figure.walk", "music.note",
                                  "globe", "camera", "cup.and.saucer", "gamecontroller", "star"]
    /// Offered by the editor's icon picker. `symbol` is what gets stored per category in
    /// FocusState.categoryStyles; `label` exists only for the menu.
    struct SymbolChoice: Identifiable {
        let symbol: String
        let label: String
        var id: String { symbol }
    }
    static let palette: [SymbolChoice] = [
        SymbolChoice(symbol: "book.closed", label: "书本"), SymbolChoice(symbol: "leaf", label: "叶子"),
        SymbolChoice(symbol: "headphones", label: "耳机"), SymbolChoice(symbol: "laptopcomputer", label: "电脑"),
        SymbolChoice(symbol: "function", label: "函数"), SymbolChoice(symbol: "pencil", label: "铅笔"),
        SymbolChoice(symbol: "tag", label: "标签"), SymbolChoice(symbol: "book", label: "书"),
        SymbolChoice(symbol: "paintbrush", label: "画笔"), SymbolChoice(symbol: "figure.walk", label: "步行"),
        SymbolChoice(symbol: "music.note", label: "音乐"), SymbolChoice(symbol: "globe", label: "地球"),
        SymbolChoice(symbol: "camera", label: "相机"), SymbolChoice(symbol: "cup.and.saucer", label: "杯子"),
        SymbolChoice(symbol: "gamecontroller", label: "游戏"), SymbolChoice(symbol: "star", label: "星星")
    ]
    static func symbol(_ name: String) -> String {
        if name == "未分类" { return "square.grid.2x2" }
        switch name {
        case "材料力学", "阅读": return "book.closed"
        case "建模": return "leaf"
        case "英语": return "headphones"
        case "编程": return "laptopcomputer"
        case "数学": return "function"
        case "写作": return "pencil"
        default: return symbolFallbacks[Int(hashOf(name) % UInt64(symbolFallbacks.count))]
        }
    }
    static func color(_ name: String) -> Color {
        if name == "未分类" { return muted }
        if let index = suggestedCategories.firstIndex(of: name) { return colors[index] }
        return colors[Int(hashOf(name) % UInt64(colors.count))]
    }

    static func color(_ name: String, styles: [String: String]) -> Color {
        if let index = FocusState.styleColorIndex(in: styles, forCategory: name),
           colors.indices.contains(index) {
            return colors[index]
        }
        return color(name)
    }
}

/// Keep small actions optically consistent while giving each a usable macOS hit area.
struct GardenActionIcon: View {
    let name: String
    var pointSize: CGFloat = 14
    var color: Color = Garden.muted
    var targetSize: CGFloat = 24

    var body: some View {
        Image(systemName: name)
            .font(.system(size: pointSize, weight: .medium))
            .foregroundColor(color)
            .frame(width: targetSize, height: targetSize)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }
}

struct GardenArt: View {
    let name: String
    @ObservedObject var activity: WindowActivity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("gentleAnimations") private var animations = true
    var body: some View {
        // The tomato is always static. Its breathing scaleEffect re-rasterised the
        // hard-edged art a few percent every 0.16s; nearest-neighbour resampling made
        // the pixel grid visibly crawl. Plants keep a light base-anchored sway, which
        // survives resampling gracefully.
        if name == "PixelTomato" {
            Image(name).resizable().interpolation(.none).scaledToFit()
                .accessibilityHidden(true)
        } else {
            TimelineView(.animation(minimumInterval: 0.16, paused: !activity.visible || activity.paused || reduceMotion || !animations)) { context in
                let moving = activity.visible && !activity.paused && !reduceMotion && animations
                let wave = moving ? sin(context.date.timeIntervalSinceReferenceDate * 1.5) : 0
                Image(name).resizable().interpolation(.none).scaledToFit()
                    .rotationEffect(.degrees(wave * 1.8), anchor: .bottom)
            }.accessibilityHidden(true)
        }
    }
}

struct FocusChart: View {
    let summary: FocusSummary
    let styles: [String: String]
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
        min(max(1, available), max(64, min(200, CGFloat(record.seconds(in: summary.interval) / 60) * 4.0)))
    }
    private var dayChart: some View {
        VStack(alignment: .leading, spacing: 8) {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    if summary.records.isEmpty {
                        Text("还没有足迹。完成一段专注后，它会留在这里。")
                            .font(.system(size: 13)).foregroundColor(Garden.muted)
                            .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
                    }
                    ForEach(Array(rows(width: geometry.size.width - 8).enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 8) {
                            ForEach(row) { record in
                                Button { onRecord(record) } label: {
                                    Image(systemName: FocusState.styleSymbol(in: styles, forCategory: record.category) ?? Garden.symbol(record.category)).font(.system(size: 22, weight: .medium))
                                        .foregroundColor(Garden.paper)
                                        .frame(width: tileWidth(record, available: geometry.size.width - 8), height: 64)
                                        .background(Garden.color(record.category, styles: styles).opacity(0.85))
                                        .cornerRadius(5)
                                }.buttonStyle(.plain).help("\(record.name) · \(record.category) · \(focusDuration(record.seconds(in: summary.interval)))")
                                    .accessibilityLabel("编辑专注：\(record.name)")
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
            }
        }
        Text("每一块是一段专注，按时间排列。点击色块，编辑名称、分类和标签。")
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
                                    Rectangle().fill(Garden.color(category.name, styles: styles).opacity(0.78))
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
        let rowCount = (offset + summary.days.count + 6) / 7
        // Reserve the actual weekday/legend heights and grid gaps. A minimum cell
        // height here used to force the last week out of its card and over the records.
        let gridHeight = max(0, geometry.size.height - 36 - CGFloat(rowCount - 1) * 5)
        let cellHeight = min(34, gridHeight / CGFloat(rowCount))
        VStack(spacing: 5) {
            HStack { ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { Text($0).font(.caption).frame(maxWidth: .infinity) } }
                .foregroundColor(Garden.muted)
                .frame(height: 14)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 5) {
                ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: cellHeight) }
                ForEach(summary.days) { day in
                    Button { onDay(day.date) } label: {
                        Text("\(calendar.component(.day, from: day.date))").font(.system(size: 12, weight: calendar.isDateInToday(day.date) ? .bold : .regular))
                            .frame(maxWidth: .infinity).frame(height: cellHeight)
                            .background(RoundedRectangle(cornerRadius: 3).fill(day.seconds > 0 ? Garden.red.opacity(0.12 + 0.56 * day.seconds / maxSeconds) : Garden.line.opacity(0.32)))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(calendar.isDateInToday(day.date) ? Garden.red : .clear, lineWidth: 1))
                    }.buttonStyle(.plain).disabled(day.date > Date()).opacity(day.date > Date() ? 0.35 : 1)
                        .help("\(day.date.formatted(date: .abbreviated, time: .omitted)) · \(focusDuration(day.seconds))")
                        .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted))，专注\(focusDuration(day.seconds))")
                }
            }
            HStack(spacing: 4) {
                Spacer(); Text("少")
                ForEach(0..<5) { index in Rectangle().fill(Garden.red.opacity(0.12 + Double(index) * 0.14)).frame(width: 13, height: 9) }
                Text("多")
            }.font(.caption2).foregroundColor(Garden.muted)
                .frame(height: 12)
        }
        }
    }
}
