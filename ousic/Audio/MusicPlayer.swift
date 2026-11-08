import Foundation
import AVFoundation
import AudioToolbox

/// 负责准备与播放一首曲子的音频（内置曲目由 SongSynth 实时渲染，导入谱面可附带音频文件）。
final class MusicPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var buffer: AVAudioPCMBuffer?
    private var playbackFormat: AVAudioFormat?
    private var sampleRate: Double = 44100

    private var startedAt: CFTimeInterval = 0
    private var accumulated: Double = 0
    private var playing = false
    private var engineStarted = false
    private var needsReschedule = false

    private(set) var duration: Double = 0
    private(set) var audioOffset: Double = 0
    private(set) var isReady = false
    var errorText: String?

    deinit {
        player.stop()
        if engineStarted { engine.stop() }
    }

    // MARK: 准备

    func prepare(chart: Chart, completion: @escaping (Bool) -> Void) {
        audioOffset = chart.offset
        let audioType = chart.audioType
        let audioFile = chart.audioFile
        let audioId = chart.audioId
        let bpm = chart.bpm
        let bars = chart.audioBars

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var loadedBuffer: AVAudioPCMBuffer?
            var loadedFormat: AVAudioFormat?
            var duration: Double = 0
            var errorText: String?

            if audioType == "file", let name = audioFile, !name.isEmpty {
                if let url = Self.locateAudioFile(named: name) {
                    do {
                        let file = try AVAudioFile(forReading: url)
                        let format = file.processingFormat
                        let frames = AVAudioFrameCount(file.length)
                        if frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) {
                            try file.read(into: buffer)
                            loadedBuffer = buffer
                            loadedFormat = format
                            duration = Double(buffer.frameLength) / format.sampleRate
                        }
                    } catch {
                        errorText = "读取音频失败：\(error.localizedDescription)"
                    }
                } else {
                    errorText = "未找到音频文件 \(name)，已使用内置合成音源"
                }
            }

            if loadedBuffer == nil {
                let spec = SongSynth.spec(for: audioId, bpm: bpm, bars: bars)
                let result = SongSynth.render(spec)
                let format = AVAudioFormat(standardFormatWithSampleRate: SongSynth.sampleRate, channels: 1)!
                if let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                                 frameCapacity: AVAudioFrameCount(result.samples.count)) {
                    buffer.frameLength = AVAudioFrameCount(result.samples.count)
                    if let channel = buffer.floatChannelData?[0] {
                        result.samples.withUnsafeBufferPointer { pointer in
                            if let base = pointer.baseAddress {
                                channel.update(from: base, count: result.samples.count)
                            }
                        }
                    }
                    loadedBuffer = buffer
                    loadedFormat = format
                    duration = result.duration
                }
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.buffer = loadedBuffer
                self.playbackFormat = loadedFormat
                self.sampleRate = loadedFormat?.sampleRate ?? SongSynth.sampleRate
                self.duration = duration
                self.errorText = errorText
                self.isReady = loadedBuffer != nil
                completion(self.isReady)
            }
        }
    }

    static func locateAudioFile(named name: String) -> URL? {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = documents.appendingPathComponent("Audio", isDirectory: true)
        let direct = audioDir.appendingPathComponent(name)
        if fileManager.fileExists(atPath: direct.path) { return direct }
        let bundleURL = Bundle.main.url(forResource: (name as NSString).deletingPathExtension,
                                        withExtension: (name as NSString).pathExtension)
        return bundleURL
    }

    // MARK: 播放控制

    @discardableResult
    func play() -> Bool {
        guard let buffer = buffer, let format = playbackFormat else { return false }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            errorText = "音频会话初始化失败：\(error.localizedDescription)"
        }

        if !engineStarted {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.prepare()
            do { try engine.start() } catch {
                errorText = "音频引擎启动失败：\(error.localizedDescription)"
                return false
            }
            engineStarted = true
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        } else if needsReschedule {
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            needsReschedule = false
        }
        if engineStarted && !engine.isRunning {
            try? engine.start()
        }
        player.play()
        if !playing {
            startedAt = CACurrentMediaTime()
            playing = true
        }
        return true
    }

    func pause() {
        guard playing else { return }
        accumulated = position
        player.pause()
        engine.pause()
        playing = false
    }

    func resume() {
        guard !playing, engineStarted else { return }
        try? engine.start()
        player.play()
        startedAt = CACurrentMediaTime()
        playing = true
    }

    func stop() {
        needsReschedule = true
        player.stop()
        if engineStarted { engine.stop() }
        playing = false
        accumulated = 0
    }

    /// 音频播放位置（秒）
    var position: Double {
        if playing, let nodeTime = player.lastRenderTime, let playerTime = player.playerTime(forNodeTime: nodeTime) {
            if playerTime.sampleRate > 0 {
                let value = Double(playerTime.sampleTime) / playerTime.sampleRate
                if value > 0 { return value }
            }
        }
        if playing { return accumulated + (CACurrentMediaTime() - startedAt) }
        return accumulated
    }
}

// MARK: - 击打音效

/// 播放谱面自带的击打音效；没有内嵌音效时退回系统提示音。
final class HitSoundPlayer {
    static let shared = HitSoundPlayer()

    private var player: AVAudioPlayer?
    private var key: String?

    func prepare(for chart: Chart) {
        let newKey = chart.hitSoundFile ?? "system"
        guard newKey != key else { return }
        key = newKey
        player = nil
        if let name = chart.hitSoundFile, !name.isEmpty,
           let url = MusicPlayer.locateAudioFile(named: name),
           let audio = try? AVAudioPlayer(contentsOf: url) {
            audio.prepareToPlay()
            player = audio
        }
    }

    func play() {
        if let player = player {
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1104)
        }
    }
}
