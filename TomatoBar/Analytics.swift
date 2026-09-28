import Foundation

enum FocusPeriod: String, CaseIterable, Identifiable {
    case day = "日", week = "周", month = "月"
    var id: String { rawValue }
    var component: Calendar.Component {
        switch self { case .day: return .day; case .week: return .weekOfYear; case .month: return .month }
    }
    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        var calendar = calendar
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar.dateInterval(of: component, for: date)!
    }
}

extension FocusRecord {
    var category: String { tags.first ?? "未分类" }
    func seconds(in interval: DateInterval) -> TimeInterval {
        segments.reduce(0) { sum, segment in
            sum + max(0, min(segment.end, interval.end).timeIntervalSince(max(segment.start, interval.start)))
        }
    }
}

struct CategoryTotal: Identifiable {
    let name: String
    let seconds: TimeInterval
    var id: String { name.lowercased() }
}

struct FocusDay: Identifiable {
    let date: Date
    let categories: [CategoryTotal]
    var id: Date { date }
    var seconds: TimeInterval { categories.reduce(0) { $0 + $1.seconds } }
}

struct FocusSummary {
    let interval: DateInterval
    let records: [FocusRecord]
    let categories: [CategoryTotal]
    let days: [FocusDay]
    var seconds: TimeInterval { categories.reduce(0) { $0 + $1.seconds } }

    init(records: [FocusRecord], period: FocusPeriod, date: Date, category: String? = nil,
         calendar: Calendar = .current) {
        let interval = period.interval(containing: date, calendar: calendar)
        self.interval = interval
        self.records = records.filter {
            (category == nil || $0.category.caseInsensitiveCompare(category!) == .orderedSame)
            && $0.seconds(in: interval) > 0
        }.sorted { $0.startedAt < $1.startedAt }
        categories = Self.totals(records: self.records, interval: interval)
        var days: [FocusDay] = []
        var cursor = interval.start
        while cursor < interval.end {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor)!
            days.append(FocusDay(date: cursor, categories: Self.totals(records: self.records,
                interval: DateInterval(start: cursor, end: min(next, interval.end)))))
            cursor = next
        }
        self.days = days
    }

    private static func totals(records: [FocusRecord], interval: DateInterval) -> [CategoryTotal] {
        var values: [String: (name: String, seconds: TimeInterval)] = [:]
        for record in records {
            let seconds = record.seconds(in: interval)
            guard seconds > 0 else { continue }
            let key = record.category.lowercased()
            let current = values[key] ?? (record.category, 0)
            values[key] = (current.name, current.seconds + seconds)
        }
        return values.values.map { CategoryTotal(name: $0.name, seconds: $0.seconds) }
            .sorted { $0.seconds == $1.seconds ? $0.name < $1.name : $0.seconds > $1.seconds }
    }
}

func focusDuration(_ seconds: TimeInterval) -> String {
    let seconds = max(0, Int(seconds))
    if seconds < 60 { return "\(seconds)秒" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)分钟" }
    return minutes % 60 == 0 ? "\(minutes / 60)小时" : "\(minutes / 60)小时\(minutes % 60)分"
}
