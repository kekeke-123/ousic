import SpriteKit
import UIKit

/// 下落式玩法的核心场景：4K / 6K / 8K 自适应。
final class GameScene: SKScene {

    // MARK: 依赖

    private let chart: Chart
    private let settings: GameSettings
    private let music: MusicPlayer
    weak var controller: GameController?

    // MARK: 布局

    private var laneWidth: CGFloat = 0
    private var judgeY: CGFloat = 0
    private var laneNodes: [SKShapeNode] = []
    private var receptorNodes: [SKShapeNode] = []
    private var judgeLine: SKShapeNode?
    private var backgroundNode: SKSpriteNode?

    private let horizontalInset: CGFloat = 6
    private let noteHeight: CGFloat = 18

    // MARK: 状态

    private final class NoteState {
        let note: Note
        var node: SKNode?
        var headNode: SKShapeNode?
        var judged = false
        var holding = false
        var holdingTouch: ObjectIdentifier?
        var quality: Judgement?
        var created = false

        init(note: Note) { self.note = note }
    }

    private var states: [NoteState] = []
    private var nextSpawn = 0
    private var started = false
    private var finished = false
    private var counts = JudgeCounts()
    private var combo = 0
    private var maxCombo = 0
    private var lastSongTime: Double = 0

    // MARK: 判定窗口（秒）

    private let perfectWindow: Double = 0.055
    private let greatWindow: Double = 0.110
    private let goodWindow: Double = 0.175

    // MARK: 颜色

    private let lanePalette: [UIColor] = [
        UIColor(red: 0.33, green: 0.85, blue: 0.98, alpha: 1),
        UIColor(red: 0.99, green: 0.42, blue: 0.72, alpha: 1),
        UIColor(red: 0.62, green: 0.95, blue: 0.56, alpha: 1),
        UIColor(red: 0.99, green: 0.77, blue: 0.33, alpha: 1),
        UIColor(red: 0.66, green: 0.60, blue: 1.00, alpha: 1),
        UIColor(red: 0.38, green: 0.95, blue: 0.86, alpha: 1),
        UIColor(red: 0.99, green: 0.55, blue: 0.42, alpha: 1),
        UIColor(red: 0.85, green: 0.62, blue: 1.00, alpha: 1)
    ]

    init(chart: Chart, settings: GameSettings, music: MusicPlayer) {
        self.chart = chart
        self.settings = settings
        self.music = music
        super.init(size: CGSize(width: 393, height: 852))
        self.scaleMode = .resizeFill
        self.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1)
        self.anchorPoint = .zero
        self.states = chart.notes.map { NoteState(note: $0) }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: 生命周期

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        buildLaneLayout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        buildLaneLayout()
        relayoutExistingNotes()
    }

    private var travelDistance: CGFloat {
        size.height + 160 - judgeY
    }

    private var pointsPerSecond: CGFloat {
        travelDistance / CGFloat(settings.approachTime)
    }

    private func buildLaneLayout() {
        backgroundNode?.removeFromParent()
        laneNodes.forEach { $0.removeFromParent() }
        receptorNodes.forEach { $0.removeFromParent() }
        judgeLine?.removeFromParent()
        laneNodes = []
        receptorNodes = []

        let laneCount = max(1, min(8, chart.laneCount))
        let usableWidth = size.width - horizontalInset * 2
        laneWidth = usableWidth / CGFloat(laneCount)
        judgeY = size.height * 0.135

        // 背景
        let background = SKSpriteNode(color: UIColor(white: 1, alpha: 0.02), size: size)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.zPosition = -10
        addChild(background)
        backgroundNode = background

        for lane in 0..<laneCount {
            let x = horizontalInset + laneWidth * (CGFloat(lane) + 0.5)
            let laneNode = SKShapeNode(rect: CGRect(x: x - laneWidth / 2 + 2, y: 0,
                                                    width: laneWidth - 4, height: size.height),
                                       cornerRadius: 0)
            laneNode.fillColor = UIColor(white: 1, alpha: lane % 2 == 0 ? 0.045 : 0.025)
            laneNode.strokeColor = UIColor(white: 1, alpha: 0.06)
            laneNode.lineWidth = 0.5
            laneNode.zPosition = -5
            addChild(laneNode)
            laneNodes.append(laneNode)

            let receptor = SKShapeNode(rectOf: CGSize(width: laneWidth - 10, height: 20), cornerRadius: 10)
            receptor.position = CGPoint(x: x, y: judgeY)
            receptor.fillColor = UIColor(white: 1, alpha: 0.10)
            receptor.strokeColor = laneColor(lane).withAlphaComponent(0.55)
            receptor.glowWidth = 1.5
            receptor.zPosition = 2
            addChild(receptor)
            receptorNodes.append(receptor)
        }

        let line = SKShapeNode(rect: CGRect(x: horizontalInset, y: judgeY + 12,
                                            width: usableWidth, height: 2))
        line.fillColor = UIColor(white: 1, alpha: 0.55)
        line.strokeColor = .clear
        line.zPosition = 1
        addChild(line)
        judgeLine = line
    }

    private func laneColor(_ lane: Int) -> UIColor {
        lanePalette[lane % lanePalette.count]
    }

    private func laneIndex(at x: CGFloat) -> Int? {
        guard laneWidth > 0 else { return nil }
        let relative = x - horizontalInset
        guard relative >= 0, relative < laneWidth * CGFloat(chart.laneCount) else { return nil }
        let index = Int(relative / laneWidth)
        return max(0, min(chart.laneCount - 1, index))
    }

    private func laneX(_ lane: Int) -> CGFloat {
        horizontalInset + laneWidth * (CGFloat(lane) + 0.5)
    }

    // MARK: 开始

    func start() {
        started = true
        finished = false
        lastSongTime = 0
        HitSoundPlayer.shared.prepare(for: chart)
    }

    // MARK: 每帧

    override func update(_ currentTime: TimeInterval) {
        guard started, !finished, let controller = controller else { return }
        guard controller.phase == .playing else { return }

        let songTime = controller.songTime
        lastSongTime = songTime

        // 生成即将到来的音符
        let spawnWindow = Double(settings.approachTime) + 0.2
        while nextSpawn < states.count, states[nextSpawn].note.time - songTime <= spawnWindow {
            spawnNote(at: nextSpawn)
            nextSpawn += 1
        }

        // 更新位置
        for state in states where state.created {
            updatePosition(state, songTime: songTime)
        }

        // 自动 Miss
        for state in states where state.created && !state.judged {
            if songTime > state.note.time + goodWindow {
                if state.holding {
                    breakHold(state, removeNode: true)
                } else {
                    apply(judgement: .miss, to: state, allowHold: false)
                }
            }
        }

        // 长按结束
        for state in states where state.holding && state.judged {
            if songTime >= state.note.endTime - 0.02 {
                finishHold(state)
            }
        }

        controller.update(score: counts.score,
                          combo: combo,
                          maxCombo: maxCombo,
                          counts: counts,
                          progress: progress(songTime: songTime))

        if songTime > chart.duration + 1.0 {
            finishGame()
        }
    }

    private func progress(songTime: Double) -> Double {
        guard chart.duration > 0 else { return 0 }
        return min(1, max(0, songTime / chart.duration))
    }

    private func spawnNote(at index: Int) {
        let state = states[index]
        let note = state.note
        let color = laneColor(note.lane)
        let width = laneWidth - 12
        let container = SKNode()
        container.position = CGPoint(x: laneX(note.lane), y: judgeY)
        container.zPosition = 5

        if note.isHold {
            let bodyHeight = max(8, CGFloat(note.duration) * pointsPerSecond)
            let body = SKShapeNode(rectOf: CGSize(width: width, height: bodyHeight + noteHeight), cornerRadius: 9)
            body.fillColor = color.withAlphaComponent(0.28)
            body.strokeColor = color.withAlphaComponent(0.65)
            body.lineWidth = 1
            body.position = CGPoint(x: 0, y: (bodyHeight + noteHeight) / 2 + 2)
            body.zPosition = 0
            container.addChild(body)

            let head = SKShapeNode(rectOf: CGSize(width: width + 4, height: noteHeight), cornerRadius: 9)
            head.fillColor = color
            head.strokeColor = color.withAlphaComponent(0.9)
            head.glowWidth = 4
            head.zPosition = 1
            container.addChild(head)
            state.headNode = head
        } else {
            let head = SKShapeNode(rectOf: CGSize(width: width, height: noteHeight), cornerRadius: 9)
            head.fillColor = color
            head.strokeColor = color.withAlphaComponent(0.9)
            head.glowWidth = 4
            container.addChild(head)
            state.headNode = head
        }

        state.node = container
        state.created = true
        addChild(container)
        updatePosition(state, songTime: lastSongTime)
    }

    private func updatePosition(_ state: NoteState, songTime: Double) {
        guard let node = state.node else { return }
        let delta = state.note.time - songTime
        node.position = CGPoint(x: laneX(state.note.lane), y: judgeY + CGFloat(delta) * pointsPerSecond)
    }

    private func relayoutExistingNotes() {
        for state in states where state.created {
            updatePosition(state, songTime: lastSongTime)
        }
    }

    // MARK: 判定

    private func apply(judgement: Judgement, to state: NoteState, allowHold: Bool) {
        guard !state.judged else { return }
        state.judged = true
        state.quality = judgement

        switch judgement {
        case .perfect: counts.perfect += 1
        case .great: counts.great += 1
        case .good: counts.good += 1
        case .miss: counts.miss += 1
        }

        if judgement == .miss {
            combo = 0
            showJudgement(text: "MISS", color: UIColor(red: 0.9, green: 0.35, blue: 0.4, alpha: 1))
            if settings.haptics { Haptics.error() }
        } else {
            combo += 1
            maxCombo = max(maxCombo, combo)
            let color: UIColor
            switch judgement {
            case .perfect: color = UIColor(red: 0.4, green: 0.95, blue: 0.9, alpha: 1)
            case .great: color = UIColor(red: 0.6, green: 0.85, blue: 1, alpha: 1)
            default: color = UIColor(red: 1, green: 0.85, blue: 0.5, alpha: 1)
            }
            showJudgement(text: judgement.rawValue, color: color)
            flashReceptor(lane: state.note.lane, color: laneColor(state.note.lane))
            if settings.haptics { Haptics.light() }
            if settings.hitSoundEnabled { HitSoundPlayer.shared.play() }
        }

        if state.holding {
            // 长按头判完成，等待尾部
            state.headNode?.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.25, duration: 0.1)
            ]))
            if judgement == .miss { breakHold(state, removeNode: true) }
        } else {
            removeNoteNode(state, judgement: judgement)
        }
    }

    private func finishHold(_ state: NoteState) {
        state.holding = false
        state.holdingTouch = nil
        if let node = state.node {
            node.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.12),
                SKAction.removeFromParent()
            ]))
        }
        state.node = nil
        flashReceptor(lane: state.note.lane, color: laneColor(state.note.lane))
    }

    private func breakHold(_ state: NoteState, removeNode: Bool) {
        guard state.holding else { return }
        state.holding = false
        let touchId = state.holdingTouch
        state.holdingTouch = nil
        if let touchId = touchId { holdingMap.removeValue(forKey: touchId) }

        if let quality = state.quality, quality != .miss {
            switch quality {
            case .perfect: counts.perfect = max(0, counts.perfect - 1)
            case .great: counts.great = max(0, counts.great - 1)
            case .good: counts.good = max(0, counts.good - 1)
            case .miss: break
            }
            counts.miss += 1
        }
        state.quality = .miss
        combo = 0
        showJudgement(text: "MISS", color: UIColor(red: 0.9, green: 0.35, blue: 0.4, alpha: 1))
        if removeNode { removeNoteNode(state, judgement: .miss) }
    }

    private func removeNoteNode(_ state: NoteState, judgement: Judgement) {
        guard let node = state.node else { return }
        state.node = nil
        if judgement == .miss {
            let move = SKAction.moveBy(x: 0, y: -18, duration: 0.12)
            let fade = SKAction.fadeOut(withDuration: 0.12)
            node.run(SKAction.sequence([SKAction.group([move, fade]), SKAction.removeFromParent()]))
        } else {
            let fade = SKAction.fadeOut(withDuration: 0.08)
            let shrink = SKAction.scaleY(to: 0.6, duration: 0.08)
            node.run(SKAction.sequence([SKAction.group([fade, shrink]), SKAction.removeFromParent()]))
        }
    }

    private func showJudgement(text: String, color: UIColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 22
        label.fontColor = color
        label.position = CGPoint(x: size.width / 2, y: judgeY + 78)
        label.zPosition = 40
        label.alpha = 0
        addChild(label)
        label.run(SKAction.sequence([
            SKAction.group([SKAction.fadeIn(withDuration: 0.06),
                            SKAction.moveBy(x: 0, y: 10, duration: 0.18)]),
            SKAction.wait(forDuration: 0.18),
            SKAction.fadeOut(withDuration: 0.18),
            SKAction.removeFromParent()
        ]))
    }

    private func flashReceptor(lane: Int, color: UIColor) {
        guard lane >= 0, lane < receptorNodes.count else { return }
        let receptor = receptorNodes[lane]
        receptor.removeAllActions()
        receptor.fillColor = color.withAlphaComponent(0.55)
        receptor.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 1, duration: 0.06),
            SKAction.wait(forDuration: 0.06),
            SKAction.run { receptor.fillColor = UIColor(white: 1, alpha: 0.10) }
        ]))
    }

    // MARK: 触控

    private var holdingMap: [ObjectIdentifier: NoteState] = [:]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard started, let controller = controller, controller.phase == .playing else { return }
        for touch in touches {
            let location = touch.location(in: self)
            guard let lane = laneIndex(at: location.x) else { continue }
            handleTouchDown(at: lane, touch: touch)
        }
    }

    private func handleTouchDown(at lane: Int, touch: UITouch) {
        let songTime = controller?.songTime ?? 0
        var best: NoteState?
        var bestDelta = Double.greatestFiniteMagnitude
        for state in states where state.created && !state.judged && state.note.lane == lane {
            let delta = abs(state.note.time - songTime)
            if delta <= goodWindow && delta < bestDelta {
                best = state
                bestDelta = delta
            }
        }
        guard let state = best else { return }
        let delta = abs(state.note.time - songTime)
        let judgement: Judgement
        if delta <= perfectWindow { judgement = .perfect }
        else if delta <= greatWindow { judgement = .great }
        else { judgement = .good }

        if state.note.isHold {
            state.holding = true
            state.holdingTouch = ObjectIdentifier(touch)
            holdingMap[ObjectIdentifier(touch)] = state
        }
        apply(judgement: judgement, to: state, allowHold: true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard let state = holdingMap.removeValue(forKey: key) else { continue }
            guard state.holding else { continue }
            let songTime = controller?.songTime ?? 0
            if songTime >= state.note.endTime - 0.12 {
                finishHold(state)
            } else {
                breakHold(state, removeNode: true)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: 结束

    private func finishGame() {
        guard !finished else { return }
        finished = true
        for state in states where state.node != nil {
            state.node?.removeFromParent()
            state.node = nil
        }
        controller?.finish(counts: counts, maxCombo: maxCombo)
    }

    func abort() {
        finished = true
    }

    func resetForRestart() {
        for state in states {
            state.node?.removeFromParent()
            state.node = nil
            state.headNode = nil
            state.created = false
            state.judged = false
            state.holding = false
            state.holdingTouch = nil
            state.quality = nil
        }
        holdingMap.removeAll()
        nextSpawn = 0
        counts = JudgeCounts()
        combo = 0
        maxCombo = 0
        started = false
        finished = false
    }
}

// MARK: - 触感

enum Haptics {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func light() {
        lightGenerator.impactOccurred()
    }

    static func error() {
        notificationGenerator.notificationOccurred(.error)
    }
}
