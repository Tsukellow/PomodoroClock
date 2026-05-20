import Foundation

final class HistoryStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = appSupport.appendingPathComponent("PomodoroClock", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        self.fileURL = directory.appendingPathComponent("history.json")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> [PomodoroSessionRecord] {
        guard let data = try? Data(contentsOf: self.fileURL) else {
            return []
        }

        return (try? self.decoder.decode([PomodoroSessionRecord].self, from: data)) ?? []
    }

    func append(_ record: PomodoroSessionRecord) {
        var records = self.load()
        records.append(record)
        self.replace(records)
    }

    func clear() {
        self.replace([])
    }

    func replace(_ records: [PomodoroSessionRecord]) {
        guard let data = try? self.encoder.encode(records) else {
            return
        }

        try? data.write(to: self.fileURL, options: .atomic)
    }
}
