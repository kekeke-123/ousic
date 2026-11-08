import Foundation
import Combine

final class GameSettings: ObservableObject {
    static let shared = GameSettings()

    private let defaults = UserDefaults.standard

    /// 1.0 为默认下落速度
    @Published var scrollSpeed: Double {
        didSet { defaults.set(scrollSpeed, forKey: "ousic.scrollSpeed") }
    }
    /// 全局判定偏移（毫秒，正数表示判定线提前）
    @Published var offsetMs: Double {
        didSet { defaults.set(offsetMs, forKey: "ousic.offsetMs") }
    }
    @Published var haptics: Bool {
        didSet { defaults.set(haptics, forKey: "ousic.haptics") }
    }
    @Published var showHitEffects: Bool {
        didSet { defaults.set(showHitEffects, forKey: "ousic.hitEffects") }
    }
    /// 击打音效（谱面内嵌音效或系统提示音）
    @Published var hitSoundEnabled: Bool {
        didSet { defaults.set(hitSoundEnabled, forKey: "ousic.hitSound") }
    }
    /// 每首曲子开始前的准备时间（秒）
    @Published var countdown: Double {
        didSet { defaults.set(countdown, forKey: "ousic.countdown") }
    }

    private init() {
        scrollSpeed = defaults.object(forKey: "ousic.scrollSpeed") as? Double ?? 1.0
        offsetMs = defaults.object(forKey: "ousic.offsetMs") as? Double ?? 0
        haptics = defaults.object(forKey: "ousic.haptics") as? Bool ?? true
        showHitEffects = defaults.object(forKey: "ousic.hitEffects") as? Bool ?? true
        hitSoundEnabled = defaults.object(forKey: "ousic.hitSound") as? Bool ?? true
        countdown = defaults.object(forKey: "ousic.countdown") as? Double ?? 2.0
    }

    /// 音符从出现到判定线所需时间（秒）
    var approachTime: Double {
        let speed = min(max(scrollSpeed, 0.5), 3.0)
        return 1.75 / speed
    }
}
