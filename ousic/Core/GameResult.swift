import Foundation

enum Judgement: String {
    case perfect = "PERFECT"
    case great = "GREAT"
    case good = "GOOD"
    case miss = "MISS"

    var score: Int {
        switch self {
        case .perfect: return 300
        case .great: return 200
        case .good: return 100
        case .miss: return 0
        }
    }

    var accuracyWeight: Double {
        switch self {
        case .perfect: return 1.0
        case .great: return 0.7
        case .good: return 0.4
        case .miss: return 0.0
        }
    }
}

struct JudgeCounts {
    var perfect = 0
    var great = 0
    var good = 0
    var miss = 0

    var total: Int { perfect + great + good + miss }

    var accuracy: Double {
        let weighted = Double(perfect) + Double(great) * 0.7 + Double(good) * 0.4
        guard total > 0 else { return 0 }
        return weighted / Double(total)
    }

    var score: Int { perfect * 300 + great * 200 + good * 100 }
}

struct GameResult {
    let chart: Chart
    let score: Int
    let accuracy: Double
    let maxCombo: Int
    let counts: JudgeCounts
    let rank: String
    let isFullCombo: Bool

    var maxScore: Int { chart.noteCount * 300 }
}
