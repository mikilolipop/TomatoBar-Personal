import Foundation

struct WidgetTodoSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
}

struct WidgetSnapshot: Codable, Equatable {
    static let appGroupIdentifier = "group.com.dilyar.TomatoBarPersonal"
    static let fileName = "widget-snapshot.json"

    let updatedAt: Date
    let phase: String
    let phaseLabel: String
    let currentName: String?
    let paused: Bool
    let deadline: Date?
    let remainingSeconds: TimeInterval
    let todaySeconds: TimeInterval
    let todayCount: Int
    let pendingTodoCount: Int
    let todos: [WidgetTodoSnapshot]

    static let placeholder = WidgetSnapshot(
        updatedAt: Date(timeIntervalSince1970: 0),
        phase: "idle",
        phaseLabel: "准备开始",
        currentName: nil,
        paused: false,
        deadline: nil,
        remainingSeconds: 0,
        todaySeconds: 0,
        todayCount: 0,
        pendingTodoCount: 2,
        todos: [
            WidgetTodoSnapshot(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "阅读章节"),
            WidgetTodoSnapshot(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, title: "整理笔记")
        ]
    )

    var isTiming: Bool { phase == "work" || phase == "rest" }
}

enum WidgetSnapshotStore {
    private static func containerURL() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroupIdentifier
        )
    }

    static func snapshotURL() -> URL? {
        containerURL()?.appendingPathComponent(WidgetSnapshot.fileName, isDirectory: false)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = snapshotURL(),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) throws {
        guard let url = snapshotURL() else {
            throw WidgetSnapshotStoreError.sharedContainerUnavailable
        }
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    static func encoded(_ snapshot: WidgetSnapshot) throws -> Data {
        try encoder.encode(snapshot)
    }

    static func decoded(_ data: Data) throws -> WidgetSnapshot {
        try decoder.decode(WidgetSnapshot.self, from: data)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}

enum WidgetSnapshotStoreError: Error {
    case sharedContainerUnavailable
}
