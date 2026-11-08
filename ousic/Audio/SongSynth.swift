import Foundation
import AVFoundation

// MARK: - 程序化音乐

/// 内置曲目全部由代码实时合成，不依赖任何音频素材，因此 App 体积极小且没有版权问题。
struct SynthSpec {
    let bpm: Double
    let bars: Int
    let root: Int
    var progression: [[Int]]
    let timbre: Timbre
    let seed: UInt64

    enum Timbre {
        case chip      // 8-bit 方波
        case soft      // 柔和三角波
        case acid      // 锯齿波 + 强低音
        case glass     // 清亮正弦
        case warm      // 圆润
        case hard      // 硬派电子
    }
}

enum SongSynth {
    static let sampleRate: Double = 44100

    static func spec(for audioId: String, bpm: Double, bars: Int) -> SynthSpec {
        let bank: [String: SynthSpec] = [
            "aurora": SynthSpec(bpm: 128, bars: 64, root: 45,
                                 progression: [[0, 4, 7], [5, 9, 12], [7, 11, 14], [0, 4, 9]],
                                 timbre: .glass, seed: 7),
            "neon": SynthSpec(bpm: 152, bars: 72, root: 41,
                               progression: [[0, 3, 7], [-2, 3, 5], [5, 7, 10], [3, 7, 12]],
                               timbre: .acid, seed: 11),
            "sakura": SynthSpec(bpm: 96, bars: 48, root: 48,
                                 progression: [[0, 4, 7], [-3, 2, 5], [5, 9, 12], [7, 11, 14]],
                                 timbre: .soft, seed: 23),
            "midnight": SynthSpec(bpm: 110, bars: 56, root: 38,
                                   progression: [[0, 3, 7], [3, 7, 10], [-2, 1, 5], [5, 8, 12]],
                                   timbre: .warm, seed: 31),
            "arcade": SynthSpec(bpm: 168, bars: 80, root: 43,
                                 progression: [[0, 4, 7], [2, 5, 9], [5, 7, 11], [7, 11, 14]],
                                 timbre: .chip, seed: 43),
            "glacier": SynthSpec(bpm: 138, bars: 64, root: 44,
                                  progression: [[0, 4, 7], [4, 7, 11], [7, 11, 14], [2, 6, 9]],
                                  timbre: .glass, seed: 59),
            "ember": SynthSpec(bpm: 176, bars: 80, root: 40,
                                progression: [[0, 3, 7], [5, 8, 12], [3, 7, 10], [0, 3, 10]],
                                timbre: .hard, seed: 67),
            "echo": SynthSpec(bpm: 124, bars: 60, root: 46,
                               progression: [[0, 4, 7], [5, 9, 12], [9, 12, 16], [7, 11, 14]],
                               timbre: .warm, seed: 71),
            "coral": SynthSpec(bpm: 144, bars: 68, root: 47,
                                progression: [[0, 4, 7], [2, 4, 9], [5, 9, 12], [7, 9, 14]],
                                timbre: .soft, seed: 83),
            "velocity": SynthSpec(bpm: 186, bars: 84, root: 39,
                                   progression: [[0, 3, 7], [3, 6, 10], [5, 8, 12], [7, 10, 14]],
                                   timbre: .hard, seed: 97),
            "lumen": SynthSpec(bpm: 118, bars: 56, root: 49,
                                progression: [[0, 4, 7], [4, 9, 12], [5, 9, 13], [0, 7, 12]],
                                timbre: .chip, seed: 101),
            "prism": SynthSpec(bpm: 160, bars: 76, root: 42,
                                progression: [[0, 4, 7], [2, 6, 9], [4, 7, 11], [9, 12, 16]],
                                timbre: .acid, seed: 113)
        ]
        if var found = bank[audioId] {
            if bars > 0 { found = SynthSpec(bpm: found.bpm, bars: bars, root: found.root,
                                            progression: found.progression, timbre: found.timbre, seed: found.seed) }
            return found
        }
        return SynthSpec(bpm: bpm > 0 ? bpm : 128, bars: bars > 0 ? bars : 60, root: 45,
                          progression: [[0, 4, 7], [5, 9, 12], [3, 7, 10], [7, 11, 14]],
                          timbre: .chip, seed: 5)
    }

    private struct Tone {
        var start: Int
        var length: Int
        var freq: Double
        var amp: Double
        var wave: Wave
        var attack: Double
        var decay: Double
    }

    private enum Wave {
        case sine, square, saw, triangle, noise, kick
    }

    /// 将整首歌渲染成单声道 Float PCM
    static func render(_ spec: SynthSpec) -> (samples: [Float], duration: Double) {
        let sr = sampleRate
        let beat = 60.0 / max(40, min(240, spec.bpm))
        let barLen = beat * 4
        let introBars = 2
        let totalBars = max(8, spec.bars)
        let totalSeconds = barLen * Double(totalBars) + 1.0
        let totalSamples = Int(totalSeconds * sr) + 1

        var buf = [Float](repeating: 0, count: totalSamples)
        var rng = RNG(seed: spec.seed)
        var tones: [Tone] = []
        tones.reserveCapacity(totalBars * 40)

        for bar in introBars..<totalBars {
            let barStart = Double(bar) * barLen
            let chord = spec.progression[(bar - introBars) % spec.progression.count]
            let barIndex = bar - introBars
            let section = barIndex / 8 // 每 8 小节一个段落，用于增减编制
            let isIntro = barIndex < 2
            let isBreak = section % 3 == 2 && barIndex % 8 >= 6
            let isOutro = barIndex >= (totalBars - introBars) - 2

            // 和弦垫
            for offset in chord {
                let freq = midiToFreq(spec.root + offset + 24)
                tones.append(Tone(start: sampleIndex(barStart, sr), length: Int(barLen * sr),
                                  freq: freq, amp: isIntro ? 0.10 : 0.16, wave: .triangle,
                                  attack: 0.02, decay: 1.0))
            }

            // 鼓组
            for b in 0..<4 {
                let t = barStart + Double(b) * beat
                if isIntro {
                    if b == 0 { tones.append(kick(t, sr, amp: 0.5)) }
                    continue
                }
                if isBreak {
                    if b % 2 == 1 { tones.append(snare(t, sr, amp: 0.12)) }
                    continue
                }
                if b == 0 || b == 2 { tones.append(kick(t, sr, amp: 0.62)) }
                if b == 1 || b == 3 { tones.append(snare(t, sr, amp: 0.22)) }
                // 八分音符 hihat
                for half in 0..<2 {
                    tones.append(hat(t + Double(half) * beat / 2, sr,
                                     amp: half == 1 ? 0.11 : 0.06))
                }
            }

            // 贝斯：每个八分音符
            if !isIntro {
                for step in 0..<8 {
                    let t = barStart + Double(step) * beat / 2
                    let note = chord[step % chord.count]
                    let freq = midiToFreq(spec.root + note - 12)
                    tones.append(Tone(start: sampleIndex(t, sr), length: Int(beat / 2 * sr * 0.9),
                                      freq: freq, amp: 0.30, wave: .saw,
                                      attack: 0.005, decay: 0.9))
                }
            }

            // 主旋律：16 分音符琶音 + 随机装饰音
            if !isOutro && !isBreak {
                let density = isIntro ? 4 : (section % 3 == 1 ? 16 : 8)
                for step in 0..<density {
                    let t = barStart + Double(step) * beat / Double(density)
                    if Double(rng.next() % 1000) / 1000.0 > 0.72 && !isIntro { continue }
                    let chordTone = chord[step % chord.count]
                    let extra = [12, 12, 24, 0, 7, 19][Int(rng.next() % 6)]
                    let freq = midiToFreq(spec.root + chordTone + 24 + extra)
                    tones.append(Tone(start: sampleIndex(t, sr), length: Int(beat / Double(density) * sr * 1.6),
                                      freq: freq, amp: isIntro ? 0.10 : 0.19, wave: wave(for: spec.timbre),
                                      attack: 0.004, decay: 0.82))
                }
            }

            // 段落尾部加花
            if section % 4 == 3 && barIndex % 8 == 7 {
                for i in 0..<8 {
                    let t = barStart + Double(3) * beat + Double(i) * beat / 8
                    tones.append(snare(t, sr, amp: 0.10 + Double(i) * 0.012))
                }
            }
        }

        // 渲染
        for tone in tones {
            guard tone.length > 2 else { continue }
            let start = tone.start
            let end = min(totalSamples, start + tone.length)
            guard start >= 0, start < totalSamples else { continue }
            var phase = 0.0
            let phaseStep = tone.freq / sr * 2 * Double.pi
            var noiseState = rng.next()
            for i in start..<end {
                let p = Double(i - start) / Double(tone.length)
                let env: Double
                if p < tone.attack {
                    env = p / max(tone.attack, 0.0001)
                } else {
                    env = exp(-(p - tone.attack) / max(0.05, tone.decay) * 2.4)
                }
                let grace = min(1.0, Double(end - i) / (sr * 0.004))
                let value: Double
                switch tone.wave {
                case .sine:
                    value = sin(phase)
                case .square:
                    value = sin(phase) >= 0 ? 1 : -1
                case .saw:
                    value = 2 * (phase / (2 * Double.pi) - floor(phase / (2 * Double.pi) + 0.5))
                case .triangle:
                    let s = phase / (2 * Double.pi)
                    value = 2 * abs(2 * (s - floor(s + 0.5))) - 1
                case .noise:
                    noiseState = noiseState &* 6364136223846793005 &+ 1442695040888963407
                    value = Double(noiseState % 2000) / 1000.0 - 1.0
                case .kick:
                    let s = Double(i - start) / sr
                    let localPhase = 2 * Double.pi * (46 * s + (105 / 22) * (1 - exp(-s * 22)))
                    value = sin(localPhase) * exp(-s * 5.5)
                }
                buf[i] += Float(value * env * grace * tone.amp)
                phase += phaseStep
                if phase > 2 * Double.pi * 1000 { phase = phase.truncatingRemainder(dividingBy: 2 * Double.pi) }
            }
        }

        // 简单压缩 + 首尾淡入淡出
        var peak: Float = 0.0001
        for v in buf { peak = max(peak, abs(v)) }
        let gain: Float = peak > 0.98 ? 0.98 / peak : 1.0
        let fadeIn = Int(sr * 0.03)
        let fadeOut = Int(sr * 0.6)
        for i in 0..<totalSamples {
            var v = buf[i] * gain
            if i < fadeIn { v *= Float(i) / Float(fadeIn) }
            let tail = totalSamples - i
            if tail < fadeOut { v *= Float(tail) / Float(fadeOut) }
            buf[i] = max(-1, min(1, v))
        }
        return (buf, Double(totalSamples) / sr)
    }

    private static func wave(for timbre: SynthSpec.Timbre) -> Wave {
        switch timbre {
        case .chip: return .square
        case .acid: return .saw
        case .hard: return .square
        case .glass: return .sine
        case .soft: return .triangle
        case .warm: return .triangle
        }
    }

    private static func kick(_ time: Double, _ sr: Double, amp: Double) -> Tone {
        Tone(start: sampleIndex(time, sr), length: Int(sr * 0.32), freq: 60,
             amp: amp, wave: .kick, attack: 0.002, decay: 0.9)
    }

    private static func snare(_ time: Double, _ sr: Double, amp: Double) -> Tone {
        let start = sampleIndex(time, sr)
        var tone = Tone(start: start, length: Int(sr * 0.14), freq: 180,
                        amp: amp, wave: .noise, attack: 0.002, decay: 0.55)
        tone.amp = amp * 0.9
        return tone
    }

    private static func hat(_ time: Double, _ sr: Double, amp: Double) -> Tone {
        Tone(start: sampleIndex(time, sr), length: Int(sr * 0.05), freq: 8000,
             amp: amp, wave: .noise, attack: 0.001, decay: 0.18)
    }

    private static func sampleIndex(_ time: Double, _ sr: Double) -> Int {
        max(0, Int(time * sr))
    }

    private static func midiToFreq(_ note: Int) -> Double {
        440 * pow(2, Double(note - 69) / 12)
    }

    private struct RNG {
        var state: UInt64
        init(seed: UInt64) { state = seed &* 1315423911 &+ 2654435761 }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 17
        }
    }
}
