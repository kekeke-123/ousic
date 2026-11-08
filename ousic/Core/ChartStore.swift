import Foundation
import Combine

struct SongGroup: Identifiable {
    let id: String
    let title: String
    let artist: String
    let charts: [Chart]

    var accent: ChartAccent { charts.first?.accent ?? .defaults[0] }
    var highestLevel: Int { charts.map(\.level).max() ?? 0 }
    var isBuiltin: Bool { charts.allSatisfy(\.isBuiltin) }
}

final class ChartStore: ObservableObject {
    static let shared = ChartStore()

    @Published private(set) var songs: [SongGroup] = []
    @Published private(set) var importedSongs: [SongGroup] = []
    @Published var lastImportError: String?
    /// 最近一次导入的结果文案，供 UI 弹提示（来自分享面板或 App 内导入都走这里）
    @Published var importFeedback: String?
    @Published var importFailed = false

    private let fm = FileManager.default
    private var didLoad = false

    var importedDirectory: URL {
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Charts", isDirectory: true)
    }

    var audioDirectory: URL {
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Audio", isDirectory: true)
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        reload()
    }

    func reload() {
        let builtin = loadBuiltin()
        let imported = loadImported()
        let grouped = Self.group(builtin)
        let groupedImported = Self.group(imported)
        let apply = {
            self.songs = grouped
            self.importedSongs = groupedImported
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    // MARK: 内置

    private func loadBuiltin() -> [Chart] {
        var urls: [URL] = []
        if let list = Bundle.main.urls(forResourcesWithExtension: "game", subdirectory: "Charts") {
            urls.append(contentsOf: list)
        }
        if let list = Bundle.main.urls(forResourcesWithExtension: "game", subdirectory: nil) {
            urls.append(contentsOf: list)
        }
        if let resourceRoot = Bundle.main.resourceURL {
            let chartsDir = resourceRoot.appendingPathComponent("Charts", isDirectory: true)
            if let list = try? fm.contentsOfDirectory(at: chartsDir, includingPropertiesForKeys: nil) {
                urls.append(contentsOf: list.filter { $0.pathExtension.lowercased() == "game" })
            }
        }

        var seen = Set<String>()
        var charts: [Chart] = []
        for url in urls where url.pathExtension.lowercased() == "game" {
            guard let data = try? Data(contentsOf: url),
                  let chart = try? ChartParser.decode(data: data, source: url, isBuiltin: true) else { continue }
            if seen.insert(chart.id).inserted {
                charts.append(chart)
            }
        }
        return charts
    }

    // MARK: 导入

    private func loadImported() -> [Chart] {
        ensureDirectories()
        guard let urls = try? fm.contentsOfDirectory(at: importedDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        var charts: [Chart] = []
        for url in urls where url.pathExtension.lowercased() == "game" {
            guard let data = try? Data(contentsOf: url),
                  let chart = try? ChartParser.decode(data: data, source: url, isBuiltin: false) else { continue }
            charts.append(chart)
        }
        return charts
    }

    private func ensureDirectories() {
        for dir in [importedDirectory, audioDirectory] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    /// 单个 .game 关卡文件的大小上限：800 MB
    static let maxImportBytes = 800 * 1024 * 1024

    private static func safeName(_ raw: String) -> String {
        let banned = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")
        let cleaned = raw.components(separatedBy: banned).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "chart" : String(trimmed.prefix(48))
    }

    /// 从系统「文件」App 或其他 App 分享进来的 .game 文件导入
    /// 支持把音频与击打音效以 base64 内嵌在 .game 里，导入时解出为 Documents/Audio 下的真实文件。
    @discardableResult
    func importChart(from url: URL) throws -> Chart {
        ensureDirectories()
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
           let size = values.fileSize,
           size > Self.maxImportBytes {
            throw ChartParseError.fileTooLarge(size)
        }
        let data = try Data(contentsOf: url)
        guard data.count > 0 else { throw ChartParseError.notJSON }
        guard data.count <= Self.maxImportBytes else { throw ChartParseError.fileTooLarge(data.count) }

        var file: ChartFile
        do { file = try JSONDecoder().decode(ChartFile.self, from: data) }
        catch { throw ChartParseError.notJSON }
        // 先预检一次，保证谱面本身合法
        _ = try ChartParser.makeChart(file, source: url, isBuiltin: false)

        var name = url.deletingPathExtension().lastPathComponent
        if name.isEmpty { name = file.songId ?? file.id }
        let slug = Self.safeName(name)

        if var audio = file.audio {
            if let base64 = audio.data, !base64.isEmpty {
                guard let bytes = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
                    throw ChartParseError.badAudio
                }
                var ext = audio.file.map { ($0 as NSString).pathExtension } ?? "m4a"
                if ext.isEmpty { ext = "m4a" }
                let audioName = "\(slug)-audio.\(ext)"
                try bytes.write(to: audioDirectory.appendingPathComponent(audioName), options: .atomic)
                audio.data = nil
                audio.type = "file"
                audio.file = audioName
            }
            if let hit = audio.hitSound, !hit.isEmpty {
                if let bytes = Data(base64Encoded: hit, options: .ignoreUnknownCharacters) {
                    let hitName = "\(slug)-hit.wav"
                    try bytes.write(to: audioDirectory.appendingPathComponent(hitName), options: .atomic)
                    audio.hitSound = hitName
                } else {
                    audio.hitSound = nil
                }
            }
            file.audio = audio
        }

        var destination = importedDirectory.appendingPathComponent(name + ".game")
        var index = 2
        while fm.fileExists(atPath: destination.path) {
            destination = importedDirectory.appendingPathComponent("\(name)-\(index).game")
            index += 1
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let normalized = try encoder.encode(file)
        try normalized.write(to: destination, options: .atomic)

        let chart = try ChartParser.decode(data: normalized, source: destination, isBuiltin: false)
        reload()
        return chart
    }

    func deleteImported(_ chart: Chart) {
        if let url = chart.sourceURL {
            try? fm.removeItem(at: url)
        }
        if let audio = chart.audioFile, !audio.isEmpty {
            try? fm.removeItem(at: audioDirectory.appendingPathComponent(audio))
        }
        if let hit = chart.hitSoundFile, !hit.isEmpty, hit != chart.audioFile {
            try? fm.removeItem(at: audioDirectory.appendingPathComponent(hit))
        }
        reload()
    }

    // MARK: 分组

    private static func group(_ charts: [Chart]) -> [SongGroup] {
        var bySong: [String: [Chart]] = [:]
        for chart in charts {
            bySong[chart.songId, default: []].append(chart)
        }
        return bySong.map { songId, list in
            let sorted = list.sorted { ($0.level, $0.difficultyName) < ($1.level, $1.difficultyName) }
            return SongGroup(
                id: songId,
                title: sorted.first?.title ?? songId,
                artist: sorted.first?.artist ?? "Unknown",
                charts: sorted
            )
        }
        .sorted { ($0.title, $0.id) < ($1.title, $1.id) }
    }
}

// MARK: - 成绩存档

struct BestRecord: Codable {
    var score: Int
    var accuracy: Double
    var rank: String
    var maxCombo: Int
    var fullCombo: Bool
    var date: Date
}

final class ScoreStore {
    static let shared = ScoreStore()
    private let key = "ousic.bestRecords"

    func record(for chart: Chart) -> BestRecord? {
        all()[chart.id]
    }

    func all() -> [String: BestRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode([String: BestRecord].self, from: data) else {
            return [:]
        }
        return value
    }

    func save(_ record: BestRecord, for chart: Chart) {
        var value = all()
        if let old = value[chart.id], old.score >= record.score { return }
        value[chart.id] = record
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
