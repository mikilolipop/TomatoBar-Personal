import Foundation

var checks = 0
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !value() { fatalError("FAIL: \(message)") }
}
let base = Date(timeIntervalSince1970: 1_800_000_000)
var s = FocusState()
s.startWork(name: "  阅读  ", seconds: 60, at: base)
s.pause(at: base.addingTimeInterval(20))
check(s.paused && s.timeLeft(at: base.addingTimeInterval(100)) == 40, "pause freezes countdown")
s.tick(at: base.addingTimeInterval(100))
check(s.records.isEmpty, "paused timer cannot complete")
s.resume(at: base.addingTimeInterval(100))
s.tick(at: base.addingTimeInterval(140))
check(s.phase == .workFinished && s.records.count == 1, "completion waits for confirmation")
check(s.records[0].seconds == 60 && s.records[0].name == "阅读", "pause excluded; event retained")
s.tick(at: base.addingTimeInterval(500))
check(s.records.count == 1, "no duplicate completion or automatic next round")
s.startRest(seconds: 10, at: base.addingTimeInterval(500))
s.tick(at: base.addingTimeInterval(510))
check(s.phase == .restFinished && s.records.count == 1, "rest excluded")
s.startWork(name: "第二轮", seconds: 60, at: base.addingTimeInterval(520))
s.stop(at: base.addingTimeInterval(535))
check(s.records.count == 2 && !s.records[0].completed && s.records[0].seconds == 15, "partial work saved")
s.stop(at: base.addingTimeInterval(536))
check(s.records.count == 2, "stop idempotent")
s.startWork(name: "", seconds: 60, at: base)
s.checkpoint = base.addingTimeInterval(12)
s.recover()
check(s.paused && s.remaining == 48 && s.name == "未命名专注", "restart resumes as paused at checkpoint")
s.stop(at: base.addingTimeInterval(1000))
check(s.records[0].seconds == 12, "offline time excluded")
var boundary = FocusState()
boundary.startWork(name: "边界", seconds: 5, at: base)
boundary.pause(at: base.addingTimeInterval(6))
check(boundary.records.count == 1 && boundary.records[0].seconds == 5, "pause at deadline completes once")
boundary.stop(at: base.addingTimeInterval(7))
check(boundary.records.count == 1, "stop after completion doesn't duplicate")
var c = FocusState()
c.startWork(name: "临时开始", seconds: 600, at: base)
c.tick(at: base.addingTimeInterval(120))
c.pause(at: base.addingTimeInterval(121))
c.resume(at: base.addingTimeInterval(130))
c.rounds = 2
c.cancel(at: base.addingTimeInterval(180))
check(c.phase == .idle && c.records.isEmpty && c.startedAt == nil && c.segments.isEmpty, "cancel discards running work without a record")
check(c.rounds == 2, "cancel keeps the round schedule")
c.cancel(at: base.addingTimeInterval(181))
check(c.phase == .idle && c.records.isEmpty, "cancel is a no-op once idle")
c.startWork(name: "取消后重开", seconds: 60, at: base.addingTimeInterval(200))
check(c.phase == .work && c.startedAt == base.addingTimeInterval(200), "restart works right after a cancel")
var p = FocusState()
p.startWork(name: "暂停中取消", seconds: 60, at: base)
p.pause(at: base.addingTimeInterval(10))
p.cancel(at: base.addingTimeInterval(20))
check(p.phase == .idle && p.records.isEmpty && !p.paused, "cancel works from paused work")
var r = FocusState()
r.startWork(name: "先完成一段", seconds: 1, at: base)
r.tick(at: base.addingTimeInterval(1))
r.startRest(seconds: 10, at: base.addingTimeInterval(5))
r.cancel(at: base.addingTimeInterval(6))
check(r.phase == .rest && r.rounds == 1 && r.records.count == 1, "cancel ignores rest and finished states")
r.stop(at: base.addingTimeInterval(7))
check(r.phase == .idle && r.rounds == 0, "stop still clears rounds where cancel does not")
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let midnight = calendar.startOfDay(for: base)
let record = FocusRecord(id: UUID(), name: "跨日", startedAt: midnight.addingTimeInterval(-30), endedAt: midnight.addingTimeInterval(30), plannedSeconds: 60, completed: true, segments: [FocusSegment(start: midnight.addingTimeInterval(-30), end: midnight.addingTimeInterval(30))])
check(record.seconds(on: midnight, calendar: calendar) == 30, "daily totals split at midnight")
let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let store = FocusStore(url: dir.appendingPathComponent("sessions.json"))
try store.save(s)
let restored = try store.load()
check(restored.records.count == s.records.count && restored.records[0].seconds == 12, "records persist across launches")
try Data("broken".utf8).write(to: store.url)
do { _ = try store.load(); fatalError("corrupt data must fail") } catch { checks += 1 }
let raw = try String(contentsOf: store.url, encoding: .utf8)
check(raw == "broken", "load preserves corrupt file")

// V1.1: decode the exact legacy shape (no tags), back it up, and preserve timing data.
let legacyEncoded = try JSONEncoder().encode(s)
var legacyObject = try JSONSerialization.jsonObject(with: legacyEncoded) as! [String: Any]
var legacyRecords = legacyObject["records"] as! [[String: Any]]
for i in legacyRecords.indices { legacyRecords[i].removeValue(forKey: "tags") }
legacyObject["records"] = legacyRecords
let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
try legacyData.write(to: store.url)
var editable = try store.load()
check(editable.records.allSatisfy { $0.tags.isEmpty }, "legacy records default to empty tags")
let backup = dir.appendingPathComponent("sessions.pre-v1.1.json")
let backupData = try Data(contentsOf: backup)
check(backupData == legacyData, "legacy backup retains exact bytes")
let original = editable.records[0]
let originalPhase = editable.phase
try editable.editRecord(id: original.id, name: "  课程任务  ", tags: [" 学习 ", "", "学习", "Swift", "swift", "课程"])
let edited = editable.records[0]
check(edited.name == "课程任务" && edited.tags == ["学习", "Swift", "课程"], "rename and normalize tags")
check(edited.id == original.id && edited.startedAt == original.startedAt && edited.endedAt == original.endedAt && edited.completed == original.completed && edited.plannedSeconds == original.plannedSeconds && edited.seconds == original.seconds && editable.phase == originalPhase, "editing preserves identity, timing, status and active phase")
check(editable.filteredRecords(tag: "SWIFT").map(\.id) == [original.id], "filter tags case-insensitively")
check(editable.filteredRecords(tag: nil).count == editable.records.count && editable.filteredRecords(tag: "不存在").isEmpty, "all and empty tag filters")
do { try editable.editRecord(id: original.id, name: "  ", tags: []); fatalError("blank name accepted") }
catch RecordEditError.emptyName { checks += 1 }
check(editable.records[0].name == edited.name && editable.records[0].tags == edited.tags, "failed validation leaves record unchanged")
do { try editable.editRecord(id: UUID(), name: "不存在", tags: []); fatalError("unknown record accepted") }
catch RecordEditError.missingRecord { checks += 1 }
try store.save(editable)
let reloaded = try store.load()
check(reloaded.records[0].tags == edited.tags && reloaded.records[0].name == edited.name, "edits survive restart")
let retainedBackup = try Data(contentsOf: backup)
check(retainedBackup == legacyData, "later loads never overwrite migration backup")
try editable.editRecord(id: original.id, name: edited.name, tags: [])
check(editable.records[0].tags.isEmpty && editable.filteredRecords(tag: "学习").isEmpty, "remove tags updates filters")

try FileManager.default.removeItem(at: dir)
print("PASS: \(checks) timing, persistence and record editing checks")

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ minute: Int = 0) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: minute))!
}
func statsRecord(_ start: Date, _ end: Date, tags: [String] = [], completed: Bool = true) -> FocusRecord {
    FocusRecord(id: UUID(), name: "统计测试", startedAt: start, endedAt: end, plannedSeconds: 1500,
                completed: completed, segments: [FocusSegment(start: start, end: end)], tags: tags)
}
let crossingRecord = statsRecord(day(2026, 9, 27, 23, 45), day(2026, 9, 28, 0, 15), tags: ["建模", "学习"])
let morning = statsRecord(day(2026, 9, 28, 9), day(2026, 9, 28, 9, 25), tags: ["英语"])
let partial = statsRecord(day(2026, 9, 28, 10), day(2026, 9, 28, 10, 10), completed: false)
let data = [crossingRecord, morning, partial]
let today = FocusSummary(records: data, period: .day, date: day(2026, 9, 28), calendar: cal)
check(today.seconds == 3000, "day clips midnight sessions and includes partial work")
check(today.categories.count == 3 && !today.categories.contains { $0.name == "学习" }, "only primary tags contribute to totals")
check(today.categories.reduce(0) { $0 + $1.seconds } == today.seconds, "category totals do not double count")
let lastWeek = FocusSummary(records: data, period: .week, date: day(2026, 9, 27), calendar: cal)
check(lastWeek.interval.start == day(2026, 9, 21) && lastWeek.interval.end == day(2026, 9, 28), "weeks run Monday to Monday")
check(lastWeek.days.count == 7 && lastWeek.seconds == 900, "Sunday clipping ends at Monday boundary")
let month = FocusSummary(records: data, period: .month, date: day(2026, 9, 28), calendar: cal)
check(month.days.count == 30 && month.seconds == 3900, "month includes full cross-day time")
check(month.days.reduce(0) { $0 + $1.seconds } == month.seconds, "daily sums equal month sum")
let filteredSummary = FocusSummary(records: data, period: .month, date: day(2026, 9, 28), category: "建模", calendar: cal)
check(filteredSummary.seconds == 1800 && filteredSummary.records.count == 1, "category filter selects exactly matching primary tag")
check(FocusSummary(records: [], period: .month, date: day(2024, 2, 10), calendar: cal).days.count == 29, "leap February contains 29 days")
check(FocusSummary(records: [], period: .month, date: day(2026, 12, 10), calendar: cal).days.count == 31, "31 day month supported")
let empty = FocusSummary(records: [], period: .day, date: day(2026, 9, 28), calendar: cal)
check(empty.seconds == 0 && empty.categories.isEmpty && empty.days.count == 1, "empty period contains no fabricated values")
var dst = cal; dst.timeZone = TimeZone(identifier: "America/Los_Angeles")!
let spring = dst.date(from: DateComponents(year: 2026, month: 3, day: 8))!
check(FocusPeriod.day.interval(containing: spring, calendar: dst).duration == 23 * 3600, "DST day uses calendar boundaries")
let dstMonth = FocusSummary(records: [], period: .month, date: spring, calendar: dst)
check(dstMonth.days.count == 31 && dstMonth.days.allSatisfy { dst.component(.hour, from: $0.date) == 0 }, "DST daily bins stay at local midnight")
print("PASS: \(checks) total checks including statistics and calendar boundaries")

// Duration formatting. focusDuration drives the main window total, category rows,
// record rows and every chart tooltip, but was previously untested.
check(focusDuration(0) == "0秒" && focusDuration(-100) == "0秒", "zero and negative clamp to zero seconds")
check(focusDuration(1) == "1秒" && focusDuration(59) == "59秒", "sub-minute values stay in seconds")
check(focusDuration(59.9) == "59秒" && focusDuration(3599.9) == "59分钟", "formatting truncates instead of rounding")
check(focusDuration(60) == "1分钟" && focusDuration(3599) == "59分钟", "minute boundaries exclusive of hours")
check(focusDuration(3600) == "1小时" && focusDuration(7200) == "2小时", "whole hours omit the minute part")
check(focusDuration(5400) == "1小时30分" && focusDuration(3661) == "1小时1分", "hours keep a non-zero remainder")

// Real-data regression: the four work segments below are taken verbatim from the
// upstream TomatoBar transition log at
// ~/Library/Containers/com.github.ivoronin.TomatoBar/Data/Library/Caches/TomatoBar.log
// Upstream records no event names and no tags, and the app was retired on
// 2026-09-28, so this log is frozen. Archived copy:
// ~/Library/Application Support/TomatoBarBuildBackups/original-container-20260928/
func legacyRecord(_ start: TimeInterval, _ end: TimeInterval, completed: Bool) -> FocusRecord {
    let startDate = Date(timeIntervalSince1970: start), endDate = Date(timeIntervalSince1970: end)
    return FocusRecord(id: UUID(), name: "未命名专注", startedAt: startDate, endedAt: endDate,
                       plannedSeconds: 1800, completed: completed,
                       segments: [FocusSegment(start: startDate, end: endDate)])
}
let legacy = [
    legacyRecord(1790497863.589353, 1790499664.100515, completed: true),   // 16:31 timerFired, full 30 min
    legacyRecord(1790499964.662455, 1790500090.604278, completed: false),  // 17:06 stopped after 2m06s
    legacyRecord(1790500094.243954, 1790500095.716640, completed: false),  // 17:08 accidental 1.5s tap
    legacyRecord(1790509417.222879, 1790509431.887085, completed: false)   // 19:43 stopped after 14.7s
]
check(focusDuration(legacy[0].seconds) == "30分钟", "real completed pomodoro formats as minutes")
check(focusDuration(legacy[1].seconds) == "2分钟", "real partial record drops the odd seconds")
check(focusDuration(legacy[2].seconds) == "1秒", "real 1.5s accidental tap stays in seconds")
check(focusDuration(legacy[3].seconds) == "14秒", "real sub-minute record stays in seconds")
var legacyCalendar = Calendar(identifier: .gregorian)
legacyCalendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
let legacyDay = FocusSummary(records: legacy, period: .day,
                             date: Date(timeIntervalSince1970: 1790500000), calendar: legacyCalendar)
check(abs(legacyDay.seconds - 1942.589877) < 0.001, "real day total sums all four segments")
check(focusDuration(legacyDay.seconds) == "32分钟", "real day total formats as 32分钟")
check(legacyDay.records.count == 4 && legacyDay.days.count == 1, "early-stopped records still count toward totals")
check(legacyDay.categories.count == 1 && legacyDay.categories[0].name == "未分类",
      "untagged legacy records collapse into a single 未分类 bucket")
print("PASS: \(checks) total checks including duration formatting and real-data regression")

// P9: the recovery path behind the "重新读取" button. TBTimer imports SwiftUI so it is not
// in this compile set; this covers the FocusStore + FocusState half. A failed load must
// keep the original bytes, and an externally repaired file must load on the next attempt
// without a relaunch.
let repairDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let repairStore = FocusStore(url: repairDir.appendingPathComponent("sessions.json"))
var repairState = FocusState()
repairState.startWork(name: "修复前", seconds: 60, at: base)
repairState.tick(at: base.addingTimeInterval(60))
check(repairState.records.count == 1 && repairState.phase == .workFinished, "repair fixture completes one record")
try repairStore.save(repairState)
try Data("{ truncated".utf8).write(to: repairStore.url)
do { _ = try repairStore.load(); fatalError("corrupt file must not load") } catch { checks += 1 }
check((try? String(contentsOf: repairStore.url, encoding: .utf8)) == "{ truncated",
      "failed load leaves the corrupt bytes untouched")
try repairStore.save(repairState)   // stands in for the user repairing the file externally
var repaired = try repairStore.load()
repaired.recover()
check(repaired.records.count == 1 && repaired.records[0].name == "修复前",
      "repaired file loads again without a relaunch")
check(repaired.records[0].seconds == 60 && repaired.phase == .workFinished,
      "reloaded record keeps its duration and its pending confirmation")
check(repaired.needsAttention, "reload never silently clears a waiting reminder")
try FileManager.default.removeItem(at: repairDir)
print("PASS: \(checks) total checks including storage recovery")

// Deletion. By UUID only — never by index or name, both of which shift as the list changes.
var delState = FocusState()
let delA = statsRecord(day(2026, 9, 28, 9), day(2026, 9, 28, 9, 25), tags: ["英语"])          // 1500s
let delB = statsRecord(day(2026, 9, 28, 11), day(2026, 9, 28, 11, 30), tags: ["数学"])         // 1800s
let delC = statsRecord(day(2026, 9, 28, 14), day(2026, 9, 28, 14, 10), tags: ["数学", "英语"])  // 600s
delState.records = [delA, delB, delC]
let delBefore = FocusSummary(records: delState.records, period: .day, date: day(2026, 9, 28), calendar: cal)
check(delBefore.seconds == 3900 && delBefore.categories.count == 2, "delete fixture starts at 3900s over 2 categories")
try delState.deleteRecord(id: delB.id)
check(delState.records.map(\.id) == [delA.id, delC.id], "delete by UUID removes only the target and preserves order")
do { try delState.deleteRecord(id: UUID()); fatalError("unknown id must not be accepted") }
catch RecordEditError.missingRecord { checks += 1 }
check(delState.records.count == 2, "a failed delete leaves the list unchanged")
let delAfter = FocusSummary(records: delState.records, period: .day, date: day(2026, 9, 28), calendar: cal)
check(delAfter.seconds == 2100, "deleting the 30 minute record removes exactly its time")
check(delAfter.categories.first { $0.name == "数学" }?.seconds == 600, "surviving category drops to its remaining record")
check(!delAfter.records.contains { $0.id == delB.id }, "deleted record is absent from the summary")
try delState.deleteRecord(id: delA.id)
let delLast = FocusSummary(records: delState.records, period: .day, date: day(2026, 9, 28), calendar: cal)
check(delLast.categories.count == 1 && delLast.categories[0].name == "数学", "a category disappears with its last record")
check(delLast.seconds == 600 && delLast.records.count == 1, "total reflects only the survivor")
let delDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let delStore = FocusStore(url: delDir.appendingPathComponent("sessions.json"))
try delStore.save(delState)
let delRestored = try delStore.load()
check(delRestored.records.count == 1 && delRestored.records[0].id == delC.id,
      "deletion survives save and reload, survivor keeps its identity")
check(!delRestored.records.contains { $0.id == delA.id || $0.id == delB.id }, "deleted records stay deleted")
try FileManager.default.removeItem(at: delDir)

// Deletion must not disturb a running timer. deleteRecord touches `records` and nothing
// else, so this asserts the guarantee rather than trusting the implementation comment.
var timingState = FocusState()
timingState.startWork(name: "第一轮", seconds: 60, at: base)
timingState.tick(at: base.addingTimeInterval(60))
timingState.startRest(seconds: 10, at: base.addingTimeInterval(70))
timingState.tick(at: base.addingTimeInterval(80))
timingState.startWork(name: "第二轮", seconds: 60, at: base.addingTimeInterval(90))
timingState.pause(at: base.addingTimeInterval(100))
check(timingState.rounds == 1 && timingState.records.count == 1, "timing fixture has one round and one record")
let tPhase = timingState.phase, tPaused = timingState.paused, tRounds = timingState.rounds
let tRemaining = timingState.remaining, tDeadline = timingState.deadline
let tName = timingState.name, tSegment = timingState.segmentStart, tStarted = timingState.startedAt
try timingState.deleteRecord(id: timingState.records[0].id)
check(timingState.records.isEmpty, "the finished record is gone")
check(timingState.phase == tPhase && timingState.paused == tPaused && timingState.rounds == tRounds,
      "delete leaves phase, pause state and round count alone")
check(timingState.remaining == tRemaining && timingState.deadline == tDeadline,
      "delete leaves the running countdown and its deadline alone")
check(timingState.name == tName && timingState.segmentStart == tSegment && timingState.startedAt == tStarted,
      "delete leaves the in-progress event and its open segment alone")

// TBTimer commits a delete only after the atomic write succeeds: it mutates a copy, saves,
// then assigns. Both halves of what makes that safe are checked here. The ordering itself
// lives in Timer.swift, which imports SwiftUI and is outside this compile set.
var commitOriginal = FocusState()
commitOriginal.records = [delC]
var commitCopy = commitOriginal
try commitCopy.deleteRecord(id: delC.id)
check(commitOriginal.records.count == 1 && commitCopy.records.isEmpty,
      "mutating a copy leaves the original intact, so a failed save cannot lose the record")
let unwritable = FocusStore(url: URL(fileURLWithPath: "/dev/null/cannot/create/sessions.json"))
do { try unwritable.save(commitCopy); fatalError("an unwritable destination must throw") } catch { checks += 1 }
check(commitOriginal.records.count == 1, "original still holds the record after the failed save")

// Category switching. The statistics category is the first tag, so switching moves the
// chosen tag to the front and keeps everything else.
check(FocusRecord.tags(withPrimaryCategory: "英语", in: ["数学", "英语"]) == ["英语", "数学"],
      "switching category moves the chosen tag to the front")
check(FocusRecord.tags(withPrimaryCategory: "建模", in: ["数学"]) == ["建模", "数学"],
      "a new category is prepended and the old first tag survives as an ordinary tag")
check(FocusRecord.tags(withPrimaryCategory: "建模", in: []) == ["建模"], "an untagged record gains its first category")
check(FocusRecord.tags(withPrimaryCategory: "swift", in: ["Swift", "数学"]) == ["swift", "数学"],
      "case-insensitive dedupe keeps a single spelling")
check(FocusRecord.tags(withPrimaryCategory: "  英语  ", in: ["数学"]) == ["英语", "数学"], "category input is trimmed")
check(FocusRecord.tags(withPrimaryCategory: "数学", in: ["数学"]) == ["数学"],
      "re-selecting the current category does not duplicate it")
check(FocusRecord.tags(withPrimaryCategory: "", in: ["数学", "英语"]) == ["数学", "英语"],
      "an empty category is a no-op, not a way to clear tags")
check(FocusRecord.tags(withPrimaryCategory: "英语", in: ["数学", "英语", " 英语 "]) == ["英语", "数学"],
      "existing duplicates collapse while switching")
let primaryRecord = FocusRecord(id: UUID(), name: "分类", startedAt: base, endedAt: base,
                                plannedSeconds: 60, completed: true, segments: [], tags: ["数学", "英语"])
check(primaryRecord.category == "数学", "the statistics category is the first tag")
check(FocusRecord(id: UUID(), name: "无", startedAt: base, endedAt: base, plannedSeconds: 60,
                  completed: true, segments: []).category == "未分类", "no tags displays as 未分类")
// Per-category icon overrides. The field did not exist in earlier files, so its absence
// must decode; and editing must not disturb it unless the caller passes a new map.
var styleState = FocusState()
styleState.records = [delC]
styleState.categoryStyles = ["学习": "star"]
let styleEncoded = try JSONEncoder().encode(styleState)
var styleObject = try JSONSerialization.jsonObject(with: styleEncoded) as! [String: Any]
styleObject.removeValue(forKey: "categoryStyles")
let styleLegacyData = try JSONSerialization.data(withJSONObject: styleObject)
var styleDecoded = try JSONDecoder().decode(FocusState.self, from: styleLegacyData)
check(styleDecoded.categoryStyles.isEmpty && styleDecoded.records.count == 1,
      "files without categoryStyles still decode; overrides default to empty")
let styleRound = try JSONDecoder().decode(FocusState.self, from: styleEncoded)
check(styleRound.categoryStyles == ["学习": "star"], "overrides survive a save/load round trip")
// The untouched-overrides check must start from a state that HAS an override, otherwise
// "left alone" and "wiped to empty" are indistinguishable — a mutation that resets the
// map on every edit passes a check written against an already-empty map.
var styleRenamed = styleRound
check(styleRenamed.categoryStyles == ["学习": "star"], "fixture starts with an override in place")
try styleRenamed.editRecord(id: delC.id, name: delC.name, tags: delC.tags)
check(styleRenamed.categoryStyles == ["学习": "star"], "a rename without styles leaves overrides untouched")
try styleRenamed.editRecord(id: delC.id, name: delC.name, tags: delC.tags, styleChanges: ["数学": "globe"])
check(styleRenamed.categoryStyles == ["学习": "star", "数学": "globe"],
      "style changes merge into the map instead of replacing it")
try styleRenamed.editRecord(id: delC.id, name: delC.name, tags: delC.tags, styleChanges: ["数学": nil])
check(styleRenamed.categoryStyles == ["学习": "star"], "a nil change removes only that key")
try styleRenamed.deleteRecord(id: delC.id)
check(styleRenamed.categoryStyles == ["学习": "star"], "deleting a record keeps the style map")
// P13: edits submit only their own delta, so a stale or concurrent draft cannot erase
// overrides saved after it opened.
var styleMerge = FocusState()
styleMerge.records = [delA, delB]
try styleMerge.editRecord(id: delA.id, name: delA.name, tags: delA.tags, styleChanges: ["a": "star"])
try styleMerge.editRecord(id: delB.id, name: delB.name, tags: delB.tags, styleChanges: ["b": "globe"])
check(styleMerge.categoryStyles == ["a": "star", "b": "globe"], "sequential deltas keep both overrides")
try styleMerge.editRecord(id: delA.id, name: "改名", tags: delA.tags, styleChanges: [:])
check(styleMerge.categoryStyles == ["a": "star", "b": "globe"],
      "a name-only edit from a stale draft submits an empty delta and wipes nothing")
// P12: caseInsensitiveCompare and lowercased() disagree on Unicode pairs such as
// Straße/STRASSE, so a key written from a draft spelling must still resolve after the
// tag is canonicalized on save.
var uniState = FocusState()
let uniRecord = statsRecord(day(2026, 9, 28, 9), day(2026, 9, 28, 9, 25), tags: ["Straße"])
uniState.records = [uniRecord]
try uniState.editRecord(id: uniRecord.id, name: uniRecord.name, tags: ["STRASSE"], styleChanges: ["strasse": "star"])
check(uniState.records[0].category == "Straße", "canonical spelling wins on save")
check(uniState.categoryStyles.keys.first == "straße", "override key is re-spelled to the canonical tag")
check(FocusState.styleSymbol(in: uniState.categoryStyles, forCategory: uniState.records[0].category) == "star",
      "override written from a draft spelling resolves against the canonical category")
check(FocusState.styleSymbol(in: ["swift": "star"], forCategory: "Swift") == "star", "exact lowercased key resolves")
check(FocusState.styleSymbol(in: ["Swift": "star"], forCategory: "swift") == "star", "alias fallback matches across case")
check(FocusState.styleSymbol(in: [:], forCategory: "学习") == nil, "no override resolves to nil")
// Colour overrides ride the same map as icons: `symbol|index` carries both, `@auto|index`
// is colour-only, and a bare symbol stays the legacy representation so old files and old
// code paths keep working unchanged.
check(FocusState.styleSymbol(in: ["学习": "star|2"], forCategory: "学习") == "star",
      "a symbol|index payload still resolves the symbol")
check(FocusState.styleColorIndex(in: ["学习": "star|2"], forCategory: "学习") == 2,
      "a symbol|index payload resolves the colour index")
check(FocusState.styleSymbol(in: ["学习": "@auto|2"], forCategory: "学习") == nil,
      "@auto keeps the automatic symbol while the colour is overridden")
check(FocusState.styleColorIndex(in: ["学习": "@auto|2"], forCategory: "学习") == 2,
      "@auto|index carries a colour-only override")
check(FocusState.styleColorIndex(in: ["学习": "star"], forCategory: "学习") == nil,
      "legacy bare-symbol payloads have no colour index")
check(FocusState.styleColorIndex(in: ["学习": "star|nope"], forCategory: "学习") == nil,
      "a non-numeric index falls back to the automatic colour")
check(FocusState.styleSymbol(in: ["学习": "star|nope"], forCategory: "学习") == "star",
      "a malformed index does not poison the symbol")
check(FocusState.styleColorIndex(in: ["学习": "star|-1"], forCategory: "学习") == nil,
      "a negative index is not a colour override")
check(FocusState.styleSymbol(in: ["学习": "star|1|2"], forCategory: "学习") == "star",
      "only the first separator is consumed")
check(FocusState.styleColorIndex(in: ["学习": "star|1|2"], forCategory: "学习") == nil,
      "extra separators make the index unreadable rather than guessing")
check(FocusState.composedStyle(symbol: "star", colorIndex: 2) == "star|2",
      "both overrides compose into symbol|index")
check(FocusState.composedStyle(symbol: "star", colorIndex: nil) == "star",
      "a symbol-only override keeps the legacy bare representation")
check(FocusState.composedStyle(symbol: nil, colorIndex: 2) == "@auto|2",
      "a colour-only override uses the @auto sentinel")
check(FocusState.composedStyle(symbol: nil, colorIndex: nil) == nil,
      "clearing both overrides composes to nil so the key can be removed")
check(FocusState.hasStyleOverride(in: ["学习": "@auto|2"], forCategory: "学习"),
      "a colour-only override counts as customised even with no symbol")
check(!FocusState.hasStyleOverride(in: [:], forCategory: "学习"),
      "an empty style map reports no override")
var colourStyle = styleRound
try colourStyle.editRecord(id: delC.id, name: delC.name, tags: delC.tags, styleChanges: ["学习": "star|2"])
check(colourStyle.categoryStyles == ["学习": "star|2"],
      "colour payloads persist through the same delta-merge path as icons")
let colourRoundTrip = try JSONDecoder().decode(FocusState.self, from: try JSONEncoder().encode(colourStyle))
check(colourRoundTrip.categoryStyles == ["学习": "star|2"], "colour overrides survive a save/load round trip")
// P14: clearing a stale filter must use the right semantics per surface. The overview
// filters by primary category, so a tag that survives only as a secondary tag must count
// as stale there, while history must still treat it as a match.
var filterState = FocusState()
let filterRecord = statsRecord(day(2026, 9, 28, 9), day(2026, 9, 28, 9, 25), tags: ["阅读"])
filterState.records = [filterRecord]
check(filterState.categoryFilterStillMatches("阅读", primaryOnly: true), "primary filter matches its only record")
try filterState.editRecord(id: filterRecord.id, name: filterRecord.name,
                           tags: FocusRecord.tags(withPrimaryCategory: "数学", in: filterRecord.tags))
check(filterState.records[0].tags == ["数学", "阅读"], "recategorising keeps the old primary as a secondary tag")
check(!filterState.categoryFilterStillMatches("阅读", primaryOnly: true),
      "overview treats a secondary-only tag as stale")
check(filterState.categoryFilterStillMatches("阅读", primaryOnly: false),
      "history still matches a secondary tag")
check(filterState.categoryFilterStillMatches("数学", primaryOnly: true), "new primary matches in overview")
filterState.records = []
check(!filterState.categoryFilterStillMatches("数学", primaryOnly: true)
      && !filterState.categoryFilterStillMatches("数学", primaryOnly: false),
      "an empty record set leaves every filter stale")
print("PASS: \(checks) total checks including deletion and category switching")

// Independent decoder oracle: the pre-categoryStyles storage shape with synthesized
// Codable. Compare accepted payloads and re-encoded values, not just records.count.
struct LegacyFocusState: Codable {
    var phase: FocusPhase
    var paused: Bool
    var name: String
    var startedAt: Date?
    var segmentStart: Date?
    var deadline: Date?
    var remaining: TimeInterval
    var planned: TimeInterval
    var segments: [FocusSegment]
    var rounds: Int
    var records: [FocusRecord]
    var checkpoint: Date
}
func reviewData(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object)
}
func legacyMatches(_ object: [String: Any]) throws -> Bool {
    let data = try reviewData(object)
    let legacy = try JSONDecoder().decode(LegacyFocusState.self, from: data)
    let current = try JSONDecoder().decode(FocusState.self, from: data)
    let left = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! NSDictionary
    var right = try JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as! [String: Any]
    right.removeValue(forKey: "categoryStyles")
    right.removeValue(forKey: "todos")
    right.removeValue(forKey: "projects")
    right.removeValue(forKey: "activeTodoID")
    right.removeValue(forKey: "seriesTodoID")
    right.removeValue(forKey: "currentTodoID")
    right.removeValue(forKey: "draftTags")
    right.removeValue(forKey: "activeTags")
    return left.isEqual(to: right)
}
func bothReject(_ object: [String: Any]) throws -> Bool {
    let data = try reviewData(object)
    let old = try? JSONDecoder().decode(LegacyFocusState.self, from: data)
    let new = try? JSONDecoder().decode(FocusState.self, from: data)
    return old == nil && new == nil
}
var decoderFixture = FocusState()
decoderFixture.startWork(name: "decoder", seconds: 60, at: base)
decoderFixture.records = [delC]
decoderFixture.categoryStyles = ["swift": "star"]
let decoderObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoderFixture)) as! [String: Any]
for phase in [FocusPhase.idle, .work, .rest, .workFinished, .restFinished] {
    var object = decoderObject
    object["phase"] = phase.rawValue
    let matches = try legacyMatches(object)
    check(matches, "manual decoder preserves every legacy field for \(phase)")
}
for key in ["startedAt", "segmentStart", "deadline"] {
    for value in [nil, NSNull(), NSNumber(value: 123.5)] as [Any?] {
        var object = decoderObject
        object[key] = value
        let matches = try legacyMatches(object)
        check(matches, "optional date \(key): missing/null/value matches synthesis")
    }
    var object = decoderObject
    object[key] = "wrong-type"
    let rejected = try bothReject(object)
    check(rejected, "wrong-type optional date \(key) must still throw")
}
for key in ["phase", "paused", "name", "remaining", "planned", "segments", "rounds", "records", "checkpoint"] {
    for value in [nil, NSNull()] as [Any?] {
        var object = decoderObject
        object[key] = value
        let rejected = try bothReject(object)
        check(rejected, "required legacy field \(key) remains required")
    }
}
for value in [nil, NSNull(), [:]] as [Any?] {
    var object = decoderObject
    object["categoryStyles"] = value
    var records = object["records"] as! [[String: Any]]
    records[0].removeValue(forKey: "tags")
    object["records"] = records
    let decoded = try JSONDecoder().decode(FocusState.self, from: reviewData(object))
    check(decoded.categoryStyles.isEmpty && decoded.records[0].tags.isEmpty,
          "missing legacy nested tags and missing/null/empty styles compose safely")
}
for value: Any in ["invalid", ["swift": 42]] {
    var object = decoderObject
    object["categoryStyles"] = value
    let decoded = try? JSONDecoder().decode(FocusState.self, from: reviewData(object))
    check(decoded == nil, "wrong-type styles are not silently accepted as valid state")
}
var asciiStyles = FocusState()
let asciiRecord = FocusRecord(id: UUID(), name: "ASCII", startedAt: base, endedAt: base,
    plannedSeconds: 60, completed: true, segments: [], tags: ["Swift"])
asciiStyles.records = [asciiRecord]
try asciiStyles.editRecord(id: asciiRecord.id, name: "ASCII", tags: ["sWIFT"], styleChanges: ["swift": "star"])
check(asciiStyles.records[0].tags == ["Swift"] && asciiStyles.categoryStyles[asciiStyles.records[0].category.lowercased()] == "star",
      "ASCII casing canonicalization preserves the icon lookup key")
let asciiRoundTrip = try JSONDecoder().decode(FocusState.self, from: JSONEncoder().encode(asciiStyles))
check(asciiRoundTrip.categoryStyles[asciiRoundTrip.records[0].category.lowercased()] == "star",
      "ASCII category override survives canonicalization and persistence")
print("PASS: \(checks) total checks including independent legacy decoding review")

// P26 (2026-09-29 external review): same-record lost-update guard. An editor snapshot
// that predates another window's save must be REFUSED, not silently revert that save.
var conflict = FocusState()
let sharedRec = FocusRecord(id: UUID(), name: "线性代数", startedAt: base, endedAt: base.addingTimeInterval(60),
    plannedSeconds: 60, completed: true, segments: [], tags: ["数学"])
conflict.records = [sharedRec]
let popoverSnapshot = conflict.records[0]
try conflict.editRecord(id: sharedRec.id, name: popoverSnapshot.name, tags: ["学习", "数学"], expected: popoverSnapshot)
check(conflict.records[0].tags == ["学习", "数学"], "an up-to-date snapshot still saves normally")
do { try conflict.editRecord(id: sharedRec.id, name: "只改名字", tags: popoverSnapshot.tags, expected: popoverSnapshot)
     fatalError("stale draft overwrote another window's tag change") }
catch RecordEditError.concurrentEdit { checks += 1 }
let windowSnapshot = conflict.records[0]
try conflict.editRecord(id: sharedRec.id, name: "作业改名", tags: windowSnapshot.tags, expected: windowSnapshot)
var staleNameCopy = popoverSnapshot
staleNameCopy.tags = windowSnapshot.tags
do { try conflict.editRecord(id: sharedRec.id, name: "再改一次", tags: windowSnapshot.tags, expected: staleNameCopy)
     fatalError("stale draft with an old name was accepted") }
catch RecordEditError.concurrentEdit { checks += 1 }
let freshSnapshot = conflict.records[0]
try conflict.editRecord(id: sharedRec.id, name: freshSnapshot.name, tags: freshSnapshot.tags,
                        styleChanges: ["学习": "globe"], expected: freshSnapshot)
check(conflict.categoryStyles["学习"] == "globe", "concurrent style-only saves pass the record guard")
do { try conflict.editRecord(id: sharedRec.id, name: "旧草稿", tags: popoverSnapshot.tags,
                              styleChanges: ["学习": "star"], expected: popoverSnapshot)
     fatalError("conflicting draft slipped through") }
catch RecordEditError.concurrentEdit { checks += 1 }
check(conflict.categoryStyles["学习"] == "globe" && conflict.records[0].name == "作业改名",
      "a refused edit changes neither the record nor the icon overrides")
try conflict.deleteRecord(id: sharedRec.id)
do { try conflict.editRecord(id: sharedRec.id, name: "x", tags: [], expected: freshSnapshot)
     fatalError("unknown record accepted") }
catch RecordEditError.missingRecord { checks += 1 }
check(RecordEditError.concurrentEdit.errorDescription?.isEmpty == false, "conflict error carries a presentable message")

// P25 rationale, domain level: pause() ticks first, so a 「取消专注」 click at the exact
// deadline COMPLETES the focus instead of pausing it. The dialog must not open in that
// case — cancel() guards on phase == .work and would silently keep the fresh record.
var exactDeadline = FocusState()
exactDeadline.startWork(name: "卡点", seconds: 10, at: base)
exactDeadline.pause(at: base.addingTimeInterval(10))
check(exactDeadline.phase == .workFinished && exactDeadline.records.count == 1,
      "pause at the exact deadline completes instead of pausing")
print("PASS: \(checks) total checks including same-record lost-update guard")

// allCategories (UI redesign handoff via Google Drive, contract completed locally
// 2026-09-30): the 「已有主分类」 menu lists ONLY tags that actually head some record.
var catState = FocusState()
catState.records = [
    FocusRecord(id: UUID(), name: "一", startedAt: base, endedAt: base, plannedSeconds: 60, completed: true, segments: [], tags: ["数学", "作业"]),
    FocusRecord(id: UUID(), name: "二", startedAt: base, endedAt: base, plannedSeconds: 60, completed: true, segments: [], tags: ["swift"]),
    FocusRecord(id: UUID(), name: "三", startedAt: base, endedAt: base, plannedSeconds: 60, completed: true, segments: [], tags: []),
]
check(!catState.allCategories.contains("作业") && !catState.allCategories.contains("未分类"),
      "allCategories excludes secondary tags and never offers 未分类 as a choice")
check(catState.allTags.contains("作业") && catState.allTags.contains("swift"),
      "allTags still carries secondary tags — the two menus keep distinct meanings")
try catState.editRecord(id: catState.records[2].id, name: "三", tags: ["SWIFT", "阅读"])
check(catState.allCategories.count == 2 && catState.allCategories.contains("swift"),
      "a retagged primary canonicalizes to the known spelling and dedupes case-insensitively")
try catState.editRecord(id: catState.records[2].id, name: "三", tags: ["科研"])
check(catState.allCategories.count == 3 && catState.allCategories.contains("科研"),
      "a genuinely new primary category joins the menu")
check(catState.allCategories == catState.allCategories.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
      "allCategories is sorted the same way as allTags")
print("PASS: \(checks) total checks including primary-category menu contract")


// Todo list + focus linkage (2026-09-30): tasks persist independently from focus records.
// Completing a focus must NEVER auto-complete its task; the task checkmark is an explicit user action.
var todoState = FocusState()
let todoA = todoState.addTodo(title: "  阅读章节  ", at: base)!
let todoB = todoState.addTodo(title: "整理笔记", at: base.addingTimeInterval(1))!
let todoC = todoState.addTodo(title: "项目整理", at: base.addingTimeInterval(2))!
check(todoState.todos.map(\.title) == ["阅读章节", "整理笔记", "项目整理"],
      "todo titles are trimmed and preserve manual insertion order")
check(todoState.pendingTodos.count == 3, "new todos start unfinished")
todoState.moveTodo(id: todoC, before: todoA)
check(todoState.todos.map(\.id) == [todoC, todoA, todoB], "todo reorder is identity-based and stable")
todoState.renameTodo(id: todoA, title: "阅读第二章")
check(todoState.todos.first { $0.id == todoA }?.title == "阅读第二章", "todo rename persists the edited title")
todoState.startWork(name: "阅读第二章", seconds: 60, todoID: todoA, at: base)
todoState.tick(at: base.addingTimeInterval(60))
check(todoState.records.first?.todoID == todoA, "finished focus keeps the originating todo id")
check(todoState.seriesTodoID == todoA && todoState.activeTodoID == nil,
      "work completion keeps the series task but clears the per-round active link")
check(todoState.focusSeconds(forTodo: todoA) == 60, "todo aggregates linked focus duration")
check(todoState.todos.first { $0.id == todoA }?.isCompleted == false,
      "finishing a focus does not auto-complete the todo")

// Multi-round regression: work -> rest -> next work must keep attributing every round to
// the same task until the user ends the set, completes/deletes it, or explicitly switches.
todoState.startRest(seconds: 10, at: base.addingTimeInterval(61))
todoState.tick(at: base.addingTimeInterval(71))
check(todoState.phase == .restFinished && todoState.seriesTodoID == todoA,
      "rest completion preserves the current task series")
todoState.startWork(name: "阅读第二章", seconds: 60, at: base.addingTimeInterval(72))
check(todoState.activeTodoID == todoA && todoState.seriesTodoID == todoA,
      "next round inherits the series task without a new explicit todo id")
todoState.tick(at: base.addingTimeInterval(132))
check(todoState.records.prefix(2).allSatisfy { $0.todoID == todoA } &&
      todoState.focusSeconds(forTodo: todoA) == 120,
      "multiple rounds aggregate under one todo")
todoState.stop(at: base.addingTimeInterval(133))
check(todoState.phase == .idle && todoState.seriesTodoID == nil,
      "ending the set clears the carried todo context")

todoState.toggleTodo(id: todoA, at: base.addingTimeInterval(134))
check(todoState.todos.first { $0.id == todoA }?.isCompleted == true &&
      todoState.todos.first { $0.id == todoA }?.completedAt != nil,
      "todo completion is explicit and records a completion time")
todoState.toggleTodo(id: todoA, at: base.addingTimeInterval(135))
check(todoState.todos.first { $0.id == todoA }?.isCompleted == false &&
      todoState.todos.first { $0.id == todoA }?.completedAt == nil,
      "uncompleting a todo clears its completion time")
let todoEncoded = try JSONEncoder().encode(todoState)
let todoRoundTrip = try JSONDecoder().decode(FocusState.self, from: todoEncoded)
check(todoRoundTrip.todos == todoState.todos && todoRoundTrip.records.first?.todoID == todoA &&
      todoRoundTrip.seriesTodoID == nil,
      "todos, record linkage and cleared series context survive save/load")
var todoLegacyObject = try JSONSerialization.jsonObject(with: todoEncoded) as! [String: Any]
todoLegacyObject.removeValue(forKey: "todos")
todoLegacyObject.removeValue(forKey: "activeTodoID")
todoLegacyObject.removeValue(forKey: "seriesTodoID")
var todoLegacyRecords = todoLegacyObject["records"] as! [[String: Any]]
for index in todoLegacyRecords.indices { todoLegacyRecords[index].removeValue(forKey: "todoID") }
todoLegacyObject["records"] = todoLegacyRecords
let todoLegacyData = try JSONSerialization.data(withJSONObject: todoLegacyObject)
let todoLegacy = try JSONDecoder().decode(FocusState.self, from: todoLegacyData)
check(todoLegacy.todos.isEmpty && todoLegacy.activeTodoID == nil && todoLegacy.seriesTodoID == nil &&
      todoLegacy.records.allSatisfy { $0.todoID == nil },
      "pre-todo sessions.json files still decode with empty task state")
todoState.deleteTodo(id: todoB)
check(!todoState.todos.contains { $0.id == todoB }, "deleting a todo removes only that task")

// A pre-series saved state can still recover continuation from the newest linked record.
var preSeries = FocusState()
let legacySeriesTodo = preSeries.addTodo(title: "兼容任务", at: base)!
preSeries.startWork(name: "兼容任务", seconds: 30, todoID: legacySeriesTodo, at: base)
preSeries.tick(at: base.addingTimeInterval(30))
preSeries.startRest(seconds: 10, at: base.addingTimeInterval(31))
preSeries.tick(at: base.addingTimeInterval(41))
var preSeriesObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preSeries)) as! [String: Any]
preSeriesObject.removeValue(forKey: "seriesTodoID")
let recoveredSeries = try JSONDecoder().decode(FocusState.self, from: JSONSerialization.data(withJSONObject: preSeriesObject))
check(recoveredSeries.phase == .restFinished && recoveredSeries.seriesTodoID == legacySeriesTodo,
      "pre-series rest state infers continuation from the newest linked focus")

// Completing a task between rounds stops continuation without rewriting the focus record
// that just finished.
var completionBreak = FocusState()
let completionTodo = completionBreak.addTodo(title: "完成后停止", at: base)!
completionBreak.startWork(name: "完成后停止", seconds: 10, todoID: completionTodo, at: base)
completionBreak.tick(at: base.addingTimeInterval(10))
completionBreak.toggleTodo(id: completionTodo, at: base.addingTimeInterval(11))
check(completionBreak.seriesTodoID == nil && completionBreak.records.first?.todoID == completionTodo,
      "completing a todo stops future inheritance but keeps finished history linked")

// Deleting the task linked to an in-progress focus must clear both live and series links.
// Otherwise the record written at completion would persist a dangling todoID.
var activeTodoState = FocusState()
let activeTodo = activeTodoState.addTodo(title: "临时任务", at: base)!
activeTodoState.startWork(name: "临时任务", seconds: 60, todoID: activeTodo, at: base)
check(activeTodoState.phase == .work && activeTodoState.activeTodoID == activeTodo &&
      activeTodoState.seriesTodoID == activeTodo,
      "starting from a todo records the live and series task association")
activeTodoState.deleteTodo(id: activeTodo)
check(activeTodoState.phase == .work && activeTodoState.activeTodoID == nil && activeTodoState.seriesTodoID == nil,
      "deleting the active todo clears task links without interrupting focus")
activeTodoState.tick(at: base.addingTimeInterval(60))
check(activeTodoState.records.first?.todoID == nil,
      "a focus completed after its todo was deleted does not persist a dangling todo id")
print("PASS: \(checks) total checks including todo persistence and multi-round linkage")

// Skipping rest must keep the set: rounds, carried task and long-rest schedule survive,
// and nothing is recorded for the skipped break.
var skip = FocusState()
let skipTodo = skip.addTodo(title: "机械原理作业", at: base)!
skip.startWork(name: "机械原理作业", seconds: 60, todoID: skipTodo, at: base)
skip.tick(at: base.addingTimeInterval(60))
check(skip.phase == .workFinished && skip.rounds == 1, "skip fixture finishes one round")
skip.skipRest(at: base.addingTimeInterval(61))
check(skip.phase == .restFinished && skip.rounds == 1 && skip.seriesTodoID == skipTodo && skip.records.count == 1,
      "skipping rest from the reminder keeps the set and records nothing")
skip.startWork(name: "机械原理作业", seconds: 60, at: base.addingTimeInterval(62))
skip.tick(at: base.addingTimeInterval(122))
check(skip.rounds == 2 && skip.records.prefix(2).allSatisfy { $0.todoID == skipTodo },
      "the round after a skipped rest continues the same task and round count")
skip.startRest(seconds: 300, at: base.addingTimeInterval(123))
skip.pause(at: base.addingTimeInterval(150))
skip.skipRest(at: base.addingTimeInterval(151))
check(skip.phase == .restFinished && !skip.paused && skip.deadline == nil && skip.rounds == 2 &&
      skip.seriesTodoID == skipTodo,
      "skipping a running or paused rest lands in the ready-for-next-round state")
check(skip.records.reduce(0) { $0 + $1.seconds } == 120, "skipped rest never adds focus time")
var skipIdle = FocusState()
skipIdle.skipRest(at: base)
check(skipIdle.phase == .idle, "skipRest is a no-op outside rest phases")
skipIdle.startWork(name: "专注中", seconds: 60, at: base)
skipIdle.skipRest(at: base.addingTimeInterval(10))
check(skipIdle.phase == .work, "skipRest never interrupts a running focus")

// Start-time tags: free focus writes its draft tags; a task start writes the task's tags.
var tagged = FocusState()
tagged.records = [FocusRecord(id: UUID(), name: "旧", startedAt: base, endedAt: base.addingTimeInterval(60),
                              plannedSeconds: 60, completed: true,
                              segments: [FocusSegment(start: base, end: base.addingTimeInterval(60))],
                              tags: ["学习"])]
tagged.setDraftTags([" 学习 ", "复习", "学习"])
check(tagged.draftTags == ["学习", "复习"], "draft tags are trimmed and deduplicated")
tagged.startWork(name: "自由专注", seconds: 60, tags: tagged.draftTags, at: base.addingTimeInterval(100))
tagged.tick(at: base.addingTimeInterval(160))
check(tagged.records.first?.tags == ["学习", "复习"] && tagged.records.first?.category == "学习",
      "free focus records the tags chosen before starting; first tag is the category")
check(tagged.activeTags.isEmpty && tagged.draftTags == ["学习", "复习"],
      "draft tags stay selected for the next free focus")
tagged.stop(at: base.addingTimeInterval(161))
let taggedTodo = tagged.addTodo(title: "画图", at: base)!
tagged.setTodoTags(id: taggedTodo, tags: ["制图", "学习"])
tagged.startWork(name: "画图", seconds: 60, todoID: taggedTodo, at: base.addingTimeInterval(200))
tagged.tick(at: base.addingTimeInterval(260))
check(tagged.records.first?.tags == ["制图", "学习"] && tagged.records.first?.todoID == taggedTodo,
      "a task start inherits the task's tags")
tagged.stop(at: base.addingTimeInterval(261))
tagged.startWork(name: "大小写", seconds: 60, tags: ["学习".uppercased(), "ENGLISH"], at: base.addingTimeInterval(300))
tagged.stop(at: base.addingTimeInterval(330))
check(tagged.records.first?.tags.contains("ENGLISH") == true, "new start tags keep their spelling")
var canonical = FocusState()
canonical.records = [FocusRecord(id: UUID(), name: "旧", startedAt: base, endedAt: base.addingTimeInterval(60),
                                 plannedSeconds: 60, completed: true,
                                 segments: [FocusSegment(start: base, end: base.addingTimeInterval(60))],
                                 tags: ["English"])]
canonical.startWork(name: "背单词", seconds: 60, tags: ["english"], at: base.addingTimeInterval(100))
canonical.stop(at: base.addingTimeInterval(130))
check(canonical.records.first?.tags == ["English"], "start tags reuse the existing spelling of a category")
check(canonical.knownTags == ["English"], "knownTags dedupes record tags case-insensitively")
var cancelled = FocusState()
cancelled.startWork(name: "放弃", seconds: 60, tags: ["临时"], at: base)
cancelled.cancel(at: base.addingTimeInterval(5))
check(cancelled.activeTags.isEmpty && cancelled.records.isEmpty, "cancel discards the active tags")

// Sticky current task: survives ending the set, cleared by completion/deletion/free focus.
var sticky = FocusState()
let stickyA = sticky.addTodo(title: "任务 A", at: base)!
let stickyB = sticky.addTodo(title: "任务 B", at: base)!
sticky.selectCurrentTodo(stickyA)
check(sticky.currentTodo?.id == stickyA, "selecting a task makes it current")
sticky.startWork(name: "任务 A", seconds: 60, todoID: sticky.currentTodoID, at: base)
sticky.tick(at: base.addingTimeInterval(60))
sticky.stop(at: base.addingTimeInterval(61))
check(sticky.currentTodoID == stickyA && sticky.seriesTodoID == nil,
      "ending the set keeps the current task while clearing the set context")
let stickyRoundTrip = try JSONDecoder().decode(FocusState.self, from: JSONEncoder().encode(sticky))
check(stickyRoundTrip.currentTodoID == stickyA, "current task survives save/load")
sticky.startWork(name: "任务 A", seconds: 60, todoID: stickyA, at: base.addingTimeInterval(100))
sticky.tick(at: base.addingTimeInterval(160))
sticky.startRest(seconds: 10, at: base.addingTimeInterval(161))
sticky.skipRest(at: base.addingTimeInterval(162))
sticky.selectCurrentTodo(nil)
check(sticky.currentTodoID == nil && sticky.seriesTodoID == nil,
      "switching to free focus between rounds drops the carried task")
sticky.startWork(name: "自由", seconds: 60, at: base.addingTimeInterval(163))
check(sticky.activeTodoID == nil, "the next round after choosing free focus is unlinked")
sticky.selectCurrentTodo(stickyB)
check(sticky.currentTodoID == stickyB && sticky.activeTodoID == nil,
      "changing the current task mid-focus never relinks the running work")
sticky.stop(at: base.addingTimeInterval(170))
sticky.toggleTodo(id: stickyB, at: base.addingTimeInterval(171))
check(sticky.currentTodoID == nil, "completing the current task clears it")
sticky.selectCurrentTodo(stickyB)
check(sticky.currentTodoID == nil, "a completed task cannot become current")
sticky.selectCurrentTodo(stickyA)
sticky.deleteTodo(id: stickyA)
check(sticky.currentTodoID == nil && sticky.currentTodo == nil, "deleting the current task clears it")

// Legacy files: no tags on todos, no currentTodoID / draftTags / activeTags keys.
var legacyNew = FocusState()
_ = legacyNew.addTodo(title: "旧待办", at: base)
var legacyNewObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacyNew)) as! [String: Any]
for key in ["currentTodoID", "draftTags", "activeTags"] { legacyNewObject.removeValue(forKey: key) }
var legacyTodos = legacyNewObject["todos"] as! [[String: Any]]
for index in legacyTodos.indices { legacyTodos[index].removeValue(forKey: "tags") }
legacyNewObject["todos"] = legacyTodos
let legacyNewDecoded = try JSONDecoder().decode(FocusState.self, from: JSONSerialization.data(withJSONObject: legacyNewObject))
check(legacyNewDecoded.todos.first?.tags == [] && legacyNewDecoded.currentTodoID == nil &&
      legacyNewDecoded.draftTags.isEmpty && legacyNewDecoded.activeTags.isEmpty,
      "pre-current-task sessions.json files decode with empty task tags and selections")
let (parsedTitle, parsedTags) = FocusTodo.parseInput("完成机械原理作业 #学习 #期中复习")
check(parsedTitle == "完成机械原理作业" && parsedTags == ["学习", "期中复习"],
      "parseInput extracts title and normalized tags")
let (plainTitle, plainTags) = FocusTodo.parseInput("  纯任务名称  ")
check(plainTitle == "纯任务名称" && plainTags.isEmpty, "parseInput works without tags")
let (tagOnlyTitle, tagOnlyTags) = FocusTodo.parseInput("#仅标签")
check(tagOnlyTitle == "#仅标签" && tagOnlyTags == ["仅标签"], "parseInput preserves standalone tag title fallback")

// FocusProject: CRUD, subtask affiliation, tag inheritance, project-level focus seconds aggregation and legacy compatibility.
var projState = FocusState()
let projA = projState.addProject(name: "Robomaster校内赛", tags: ["竞赛"], color: "red", at: base)!
let projB = projState.addProject(name: "材料力学", tags: ["专业课"], color: "blue", at: base)!
check(projState.projects.count == 2, "projects can be added")
check(projState.project(for: projA)?.name == "Robomaster校内赛", "project(for:) looks up project by UUID")
check(projState.project(for: projA)?.tags == ["竞赛"], "project stores its primary tag")
check(projState.knownTags.contains("竞赛") && projState.knownTags.contains("专业课"), "knownTags includes project tags")

projState.updateProject(id: projA, name: "Robomaster 2026", tags: ["竞赛", "科创"])
check(projState.project(for: projA)?.name == "Robomaster 2026" && projState.project(for: projA)?.tags == ["竞赛", "科创"],
      "project can be updated with new name and tags")
projState.toggleProjectArchived(id: projB)
check(projState.project(for: projB)?.isArchived == true, "project can be archived")

// Subtask tag inheritance & merging:
// 1. Subtask with child tag merges with parent project tags: ["竞赛", "科创", "机械"]
let subtaskA1 = projState.addTodo(title: "底盘机械设计", tags: ["机械"], projectID: projA, at: base)!
check(projState.todos.first { $0.id == subtaskA1 }?.tags == ["竞赛", "科创", "机械"],
      "subtask with own tags merges parent project tags as prefix")

// 2. Subtask without tags automatically inherits parent project tags
let subtaskA2 = projState.addTodo(title: "采购螺丝", projectID: projA, at: base)!
check(projState.todos.first { $0.id == subtaskA2 }?.tags == ["竞赛", "科创"],
      "subtask without tags automatically inherits parent project tags")

let subtaskLoose = projState.addTodo(title: "英语单词", at: base)!
check(projState.todos.first { $0.id == subtaskLoose }?.tags.isEmpty == true, "loose todo starts without tags")

// 3. Assigning untagged loose todo to project inherits project's tags
projState.setTodoProject(todoID: subtaskLoose, projectID: projB)
check(projState.todos.first { $0.id == subtaskLoose }?.projectID == projB &&
      projState.todos.first { $0.id == subtaskLoose }?.tags == ["专业课"],
      "assigning untagged loose todo to project inherits target project's tags")

// Focus on subtaskA1: record gets both todoID, projectID, and inherited tags (with parent category first)
projState.startWork(name: "底盘机械设计", seconds: 120, todoID: subtaskA1, at: base)
projState.tick(at: base.addingTimeInterval(120))
projState.stop(at: base.addingTimeInterval(121))
let recA1 = projState.records.first!
check(recA1.todoID == subtaskA1 && recA1.projectID == projA, "record inherits both todoID and projectID")
check(recA1.tags == ["竞赛", "科创", "机械"], "record inherits merged project and subtask tags")
check(projState.focusSeconds(forTodo: subtaskA1) == 120, "subtask focusSeconds records 120s")
check(projState.focusSeconds(forProject: projA) == 120, "project focusSeconds includes subtask time")

// Focus on subtaskA2: project aggregation sums up both subtasks
projState.startWork(name: "采购螺丝", seconds: 60, todoID: subtaskA2, at: base.addingTimeInterval(200))
projState.tick(at: base.addingTimeInterval(260))
projState.stop(at: base.addingTimeInterval(261))
check(projState.focusSeconds(forProject: projA) == 180, "project focusSeconds aggregates all subtasks")
check(projState.focusSeconds(forProject: projB) == 0, "unrelated project focusSeconds stays 0")

// Deleting a project leaves its subtasks intact with projectID = nil (safe detachment)
projState.deleteProject(id: projA)
check(projState.projects.count == 1 && projState.project(for: projA) == nil, "project is deleted")
check(projState.todos.filter { $0.id == subtaskA1 || $0.id == subtaskA2 }.allSatisfy { $0.projectID == nil },
      "subtasks of deleted project detach cleanly into loose todos rather than being deleted")

// Serialization roundtrip with projects and project tags
var projRoundTripState = FocusState()
let roundProjID = projRoundTripState.addProject(name: "毕业论文", tags: ["学术"], at: base)!
_ = projRoundTripState.addTodo(title: "开题报告", projectID: roundProjID, at: base)
let roundTripDecoded = try JSONDecoder().decode(FocusState.self, from: JSONEncoder().encode(projRoundTripState))
check(roundTripDecoded.projects.first?.name == "毕业论文" &&
      roundTripDecoded.projects.first?.tags == ["学术"] &&
      roundTripDecoded.todos.first?.projectID == roundProjID &&
      roundTripDecoded.todos.first?.tags == ["学术"],
      "projects and subtask affiliations and tags survive serialization roundtrip")

// Compatibility: Project JSON without 'tags' (build 5 format) decodes safely with empty tags array
var legacyProjectWithoutTags = try JSONSerialization.jsonObject(with: JSONEncoder().encode(projRoundTripState)) as! [String: Any]
var legacyProjectsList = legacyProjectWithoutTags["projects"] as! [[String: Any]]
for i in legacyProjectsList.indices { legacyProjectsList[i].removeValue(forKey: "tags") }
legacyProjectWithoutTags["projects"] = legacyProjectsList
let legacyProjDecoded = try JSONDecoder().decode(FocusState.self, from: JSONSerialization.data(withJSONObject: legacyProjectWithoutTags))
check(legacyProjDecoded.projects.first?.name == "毕业论文" &&
      legacyProjDecoded.projects.first?.tags.isEmpty == true,
      "build-5 sessions.json without project tags decodes with empty tags array")

// Legacy sessions.json without projects decodes with empty array
var legacyWithoutProjects = try JSONSerialization.jsonObject(with: JSONEncoder().encode(projRoundTripState)) as! [String: Any]
legacyWithoutProjects.removeValue(forKey: "projects")
var legacyTodosList = legacyWithoutProjects["todos"] as! [[String: Any]]
for i in legacyTodosList.indices { legacyTodosList[i].removeValue(forKey: "projectID") }
legacyWithoutProjects["todos"] = legacyTodosList
let legacyDecodedState = try JSONDecoder().decode(FocusState.self, from: JSONSerialization.data(withJSONObject: legacyWithoutProjects))
check(legacyDecodedState.projects.isEmpty && legacyDecodedState.todos.first?.projectID == nil,
      "pre-projects sessions.json decodes with empty projects and nil subtask projectID")

print("PASS: \(checks) total checks including project hierarchy, tag inheritance, subtask aggregation and legacy compatibility")
