import Foundation
import Combine

final class GameController: ObservableObject {
    enum Phase: Equatable {
        case loading, countdown, playing, paused, finished
    }

    let chart: Chart
    let music = MusicPlayer()
    private let settings = GameSettings.shared

    weak var scene: GameScene?

    @Published var phase: Phase = .loading
    @Published var countdownValue: Int = 3
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var maxCombo: Int = 0
    @Published var counts = JudgeCounts()
    @Published var progress: Double = 0
    @Published var result: GameResult?
    @Published var warning: String?

    private var timer: Timer?

    init(chart: Chart) {
        self.chart = chart
    }

    /// 谱面时间（秒）：已扣除谱面 offset 与玩家校准值
    var songTime: Double {
        music.position - chart.offset - settings.offsetMs / 1000
    }

    // MARK: 加载

    func load() {
        guard phase == .loading else { return }
        music.prepare(chart: chart) { [weak self] ok in
            guard let self = self else { return }
            self.warning = self.music.errorText
            if !ok {
                self.warning = "音频准备失败，将只播放静音谱面"
            }
            self.startCountdown(resume: false)
        }
    }

    func attach(scene: GameScene) {
        self.scene = scene
        scene.controller = self
    }

    // MARK: 倒计时

    private func startCountdown(resume: Bool) {
        timer?.invalidate()
        countdownValue = 3
        phase = .countdown
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.countdownValue > 1 {
                self.countdownValue -= 1
                if self.settings.haptics { Haptics.light() }
            } else {
                timer.invalidate()
                self.beginPlay(resume: resume)
            }
        }
    }

    private func beginPlay(resume: Bool) {
        if resume {
            music.resume()
        } else {
            if !music.play() {
                warning = music.errorText ?? "音频无法播放"
            }
        }
        scene?.start()
        phase = .playing
    }

    // MARK: 游玩中回调

    func update(score: Int, combo: Int, maxCombo: Int, counts: JudgeCounts, progress: Double) {
        if self.score != score { self.score = score }
        if self.combo != combo { self.combo = combo }
        if self.maxCombo != maxCombo { self.maxCombo = maxCombo }
        if self.counts.total != counts.total || self.counts.miss != counts.miss || self.counts.perfect != counts.perfect {
            self.counts = counts
        }
        if abs(self.progress - progress) > 0.001 { self.progress = progress }
    }

    func finish(counts: JudgeCounts, maxCombo: Int) {
        guard result == nil else { return }
        timer?.invalidate()
        music.stop()
        let accuracy = counts.accuracy
        let rank = Self.rank(accuracy: accuracy, miss: counts.miss)
        let result = GameResult(
            chart: chart,
            score: counts.score,
            accuracy: accuracy,
            maxCombo: maxCombo,
            counts: counts,
            rank: rank,
            isFullCombo: counts.miss == 0
        )
        self.result = result
        self.phase = .finished
        ScoreStore.shared.save(BestRecord(score: result.score,
                                          accuracy: result.accuracy,
                                          rank: result.rank,
                                          maxCombo: result.maxCombo,
                                          fullCombo: result.isFullCombo,
                                          date: Date()), for: chart)
        if result.isFullCombo && settings.haptics {
            Haptics.light()
        }
    }

    static func rank(accuracy: Double, miss: Int) -> String {
        if accuracy >= 0.995 && miss == 0 { return "S+" }
        if accuracy >= 0.95 { return "S" }
        if accuracy >= 0.90 { return "A" }
        if accuracy >= 0.80 { return "B" }
        if accuracy >= 0.70 { return "C" }
        return "D"
    }

    // MARK: 暂停 / 退出 / 重来

    func pause() {
        guard phase == .playing else { return }
        music.pause()
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        startCountdown(resume: true)
    }

    func quit() {
        timer?.invalidate()
        music.stop()
        scene?.abort()
        phase = .finished
    }

    func restart() {
        timer?.invalidate()
        music.stop()
        scene?.resetForRestart()
        score = 0
        combo = 0
        maxCombo = 0
        counts = JudgeCounts()
        progress = 0
        result = nil
        warning = nil
        phase = .loading
        music.prepare(chart: chart) { [weak self] ok in
            guard let self = self else { return }
            if !ok { self.warning = "音频准备失败" }
            self.startCountdown(resume: false)
        }
    }
}
