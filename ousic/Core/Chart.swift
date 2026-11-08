import Foundation
import CoreGraphics

// MARK: - .game 文件格式

/// .game 是 ousic 的关卡文件，本质为 UTF-8 JSON，扩展名固定为 .game。
struct ChartFile: Codable {
    var format: String?
    var version: Int?
    var id: String
    var songId: String?
    var title: String
    var artist: String?
    var charter: String?
    var bpm: Double
    var offset: Double?
    var lanes: Int?
    var audio: AudioSpec?
    var difficulty: DifficultyInfo?
    var notes: [RawNote]
    /// 可选的配色主色，格式 "#RRGGBB"
    var color: String?
}

struct DifficultyInfo: Codable {
    var name: String
    var level: Int
}

struct AudioSpec: Codable {
    var type: String?
    var id: String?
    var file: String?
    /// 内置合成曲目的小节数（仅供程序化音频使用，可省略）
    var bars: Int?
    /// 内嵌音频（base64）。导入时解出为 Documents/Audio 下的真实音频文件
    var data: String?
    /// 击打音效（base64 wav）。导入时同样解出为文件，之后这里是文件名
    var hitSound: String?
}

struct RawNote: Codable {
    /// 击打时刻，单位毫秒
    var t: Double
    /// 轨道下标，从 0 开始
    var lane: Int
    /// "tap" 或 "hold"，缺省为 tap
    var type: String?
    /// 长按时长，单位毫秒，仅 hold 有效
    var d: Double?
}

// MARK: - 运行时谱面

struct Note: Identifiable {
    let id: Int
    /// 秒
    let time: Double
    let lane: Int
    /// 秒，0 表示普通 note
    let duration: Double

    var isHold: Bool { duration > 0.001 }
    var endTime: Double { time + duration }
}

struct Chart: Identifiable, Hashable {
    let id: String
    let songId: String
    let title: String
    let artist: String
    let charter: String
    let difficultyName: String
    let level: Int
    let bpm: Double
    let laneCount: Int
    /// 秒：谱面时间 0 对应音频播放位置
    let offset: Double
    let audioType: String
    let audioId: String
    let audioFile: String?
    let hitSoundFile: String?
    let audioBars: Int
    let notes: [Note]
    let sourceURL: URL?
    let isBuiltin: Bool
    let accent: ChartAccent

    var noteCount: Int { notes.count }
    var judgeCount: Int { notes.count }
    var maxCombo: Int { notes.count }
    var duration: Double { max(notes.last?.endTime ?? 0, 0) }

    var levelLabel: String { "\(difficultyName)  Lv.\(level)" }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Chart, rhs: Chart) -> Bool { lhs.id == rhs.id }
}

struct ChartAccent {
    let red: Double
    let green: Double
    let blue: Double

    var colorHex: String {
        String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    static let defaults: [ChartAccent] = [
        ChartAccent(red: 0.36, green: 0.85, blue: 0.98),
        ChartAccent(red: 0.99, green: 0.45, blue: 0.72),
        ChartAccent(red: 0.65, green: 0.95, blue: 0.55),
        ChartAccent(red: 0.99, green: 0.76, blue: 0.35),
        ChartAccent(red: 0.66, green: 0.60, blue: 1.00),
        ChartAccent(red: 0.45, green: 0.95, blue: 0.85)
    ]

    static func from(hex: String?) -> ChartAccent {
        guard var text = hex?.trimmingCharacters(in: .whitespaces), text.hasPrefix("#") else {
            return .defaults[0]
        }
        text.removeFirst()
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return .defaults[0] }
        return ChartAccent(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

// MARK: - 解析

enum ChartParseError: LocalizedError {
    case notJSON
    case missingField(String)
    case badLane(Int)
    case noNotes
    case fileTooLarge(Int)
    case badAudio

    var errorDescription: String? {
        switch self {
        case .notJSON: return "文件不是合法的 JSON：请检查括号、逗号与引号"
        case .missingField(let name): return "缺少必填字段：\(name)"
        case .badLane(let lane): return "第 \(lane) 条音符的 lane 超出范围"
        case .noNotes: return "谱面里没有任何音符"
        case .fileTooLarge(let bytes):
            let mb = Double(bytes) / 1048576.0
            return "关卡文件 \(String(format: "%.1f", mb)) MB，超过 800 MB 上限，无法导入"
        case .badAudio: return "内嵌音频不是合法的 base64 数据"
        }
    }
}

enum ChartParser {
    static func decode(data: Data, source: URL?, isBuiltin: Bool) throws -> Chart {
        let decoder = JSONDecoder()
        let file: ChartFile
        do {
            file = try decoder.decode(ChartFile.self, from: data)
        } catch {
            throw ChartParseError.notJSON
        }
        return try makeChart(file, source: source, isBuiltin: isBuiltin)
    }

    static func makeChart(_ file: ChartFile, source: URL?, isBuiltin: Bool) throws -> Chart {
        let lanes = max(1, min(8, file.lanes ?? 4))
        let offset = (file.offset ?? 0) / 1000.0
        var parsed: [Note] = []
        parsed.reserveCapacity(file.notes.count)

        for (index, raw) in file.notes.enumerated() {
            guard raw.lane >= 0 && raw.lane < lanes else {
                throw ChartParseError.badLane(raw.lane)
            }
            guard raw.t >= 0 else { continue }
            let duration = max(0, (raw.d ?? 0)) / 1000.0
            let kind = (raw.type ?? "tap").lowercased()
            parsed.append(Note(
                id: index,
                time: raw.t / 1000.0,
                lane: raw.lane,
                duration: kind == "hold" ? duration : 0
            ))
        }

        guard !parsed.isEmpty else { throw ChartParseError.noNotes }
        parsed.sort { $0.time < $1.time }

        let difficulty = file.difficulty ?? DifficultyInfo(name: "Normal", level: 8)
        let accent = ChartAccent.from(hex: file.color)
        let songId = file.songId ?? file.id
        let chartId = "\(songId)_\(difficulty.name)_\(difficulty.level)"

        return Chart(
            id: chartId,
            songId: songId,
            title: file.title,
            artist: file.artist ?? "Unknown Artist",
            charter: file.charter ?? "Unknown Charter",
            difficultyName: difficulty.name,
            level: difficulty.level,
            bpm: file.bpm,
            laneCount: lanes,
            offset: offset,
            audioType: file.audio?.type ?? "synth",
            audioId: file.audio?.id ?? "default",
            audioFile: file.audio?.file,
            hitSoundFile: file.audio?.hitSound,
            audioBars: file.audio?.bars ?? 0,
            notes: parsed,
            sourceURL: source,
            isBuiltin: isBuiltin,
            accent: accent
        )
    }
}
