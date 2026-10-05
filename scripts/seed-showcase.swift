import Foundation

// ShowcaseSeeder generates clean, professional showcase demo data for TomatoBar Personal
// completely isolated from private personal usage data.

@main
struct ShowcaseSeeder {
    static func main() throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        func timeAt(hour: Int, minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay)!
        }

        let proj1ID = UUID()
        let proj2ID = UUID()

        let proj1 = FocusProject(id: proj1ID, name: "TomatoBar 架构演进与体验迭代", tags: ["开发"], color: nil, isArchived: false, createdAt: timeAt(hour: 8, minute: 0))
        let proj2 = FocusProject(id: proj2ID, name: "Ivory & Terracotta 设计规范", tags: ["设计"], color: nil, isArchived: false, createdAt: timeAt(hour: 8, minute: 30))

        let todo1ID = UUID() // Active/Current
        let todo2ID = UUID()
        let todo3ID = UUID()

        let todo1 = FocusTodo(id: todo1ID, title: "大任务层级树与归属沉淀", isCompleted: false, createdAt: timeAt(hour: 9, minute: 0), tags: ["开发"], projectID: proj1ID)
        let todo2 = FocusTodo(id: todo2ID, title: "无声状态栏微交互调优", isCompleted: true, createdAt: timeAt(hour: 9, minute: 15), completedAt: timeAt(hour: 11, minute: 30), tags: ["开发"], projectID: proj1ID)
        let todo3 = FocusTodo(id: todo3ID, title: "快捷按键流线响应验证", isCompleted: false, createdAt: timeAt(hour: 9, minute: 30), tags: ["开发"], projectID: proj1ID)

        func makeRecord(name: String, startHour: Int, startMin: Int, durationMin: Int, tags: [String], todoID: UUID?, projectID: UUID?) -> FocusRecord {
            let s = timeAt(hour: startHour, minute: startMin)
            let e = s.addingTimeInterval(Double(durationMin * 60))
            return FocusRecord(id: UUID(), name: name, startedAt: s, endedAt: e, plannedSeconds: Double(durationMin * 60), completed: true, segments: [FocusSegment(start: s, end: e)], tags: tags, todoID: todoID, projectID: projectID)
        }

        var records: [FocusRecord] = []
        // Clean records for today (Total: 2h 25m)
        records.append(makeRecord(name: "暗调与暖象牙白配色矩阵", startHour: 9, startMin: 30, durationMin: 25, tags: ["设计"], todoID: nil, projectID: proj2ID))
        records.append(makeRecord(name: "无声状态栏微交互调优", startHour: 10, startMin: 15, durationMin: 25, tags: ["开发"], todoID: todo2ID, projectID: proj1ID))
        records.append(makeRecord(name: "《心流：最优体验心理学》精读", startHour: 14, startMin: 0, durationMin: 25, tags: ["阅读"], todoID: nil, projectID: nil))
        records.append(makeRecord(name: "微观足迹时间轴栅格对齐", startHour: 15, startMin: 10, durationMin: 25, tags: ["设计"], todoID: nil, projectID: proj2ID))
        records.append(makeRecord(name: "大任务层级树与归属沉淀", startHour: 16, startMin: 30, durationMin: 45, tags: ["开发"], todoID: todo1ID, projectID: proj1ID))

        // Previous days records for week chart
        for dayOffset in 1...6 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let dayStart = calendar.startOfDay(for: day)
            let s1 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: dayStart)!
            let e1 = s1.addingTimeInterval(2700) // 45m
            records.append(FocusRecord(id: UUID(), name: "架构重构与性能优化", startedAt: s1, endedAt: e1, plannedSeconds: 2700, completed: true, segments: [FocusSegment(start: s1, end: e1)], tags: ["开发"], todoID: todo1ID, projectID: proj1ID))
            let s2 = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: dayStart)!
            let e2 = s2.addingTimeInterval(2400) // 40m
            records.append(FocusRecord(id: UUID(), name: "设计评审与排版复盘", startedAt: s2, endedAt: e2, plannedSeconds: 2400, completed: true, segments: [FocusSegment(start: s2, end: e2)], tags: ["设计"], todoID: nil, projectID: proj2ID))
            let s3 = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: dayStart)!
            let e3 = s3.addingTimeInterval(1500) // 25m
            records.append(FocusRecord(id: UUID(), name: "技术方案阅读笔记", startedAt: s3, endedAt: e3, plannedSeconds: 1500, completed: true, segments: [FocusSegment(start: s3, end: e3)], tags: ["阅读"], todoID: nil, projectID: nil))
        }

        var state = FocusState()
        state.phase = .idle
        state.projects = [proj1, proj2]
        state.todos = [todo1, todo2, todo3]
        state.records = records
        state.currentTodoID = todo1ID
        state.rounds = 5
        state.categoryStyles = [
            "开发": "hammer.fill",
            "设计": "paintbrush.fill",
            "阅读": "book.closed.fill",
            "学习": "graduationcap.fill",
            "体验": "sparkles"
        ]

        let targetPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "demo/sessions.json"
        let url = URL(fileURLWithPath: targetPath)
        let store = FocusStore(url: url)
        try store.save(state)
        print("Successfully generated showcase data at: \(url.path)")
    }
}
