import Foundation

struct FocusStore {
    let url: URL
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TomatoBarPersonal", isDirectory: true)
            .appendingPathComponent("sessions.json")
    }
    func load() throws -> FocusState {
        guard FileManager.default.fileExists(atPath: url.path) else { return FocusState() }
        let data = try Data(contentsOf: url)
        let state = try JSONDecoder().decode(FocusState.self, from: data)
        // Keep an untouched copy before the first tagged-format save.
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let records = object?["records"] as? [[String: Any]] ?? []
        let backup = url.deletingLastPathComponent().appendingPathComponent("sessions.pre-v1.1.json")
        if records.contains(where: { $0["tags"] == nil }), !FileManager.default.fileExists(atPath: backup.path) {
            try FileManager.default.copyItem(at: url, to: backup)
        }
        return state
    }
    func save(_ state: FocusState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}
