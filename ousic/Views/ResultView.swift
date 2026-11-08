import SwiftUI

struct ResultView: View {
    let chart: Chart
    let result: GameResult
    var onRestart: () -> Void
    var onExit: () -> Void

    private var rankColor: Color {
        switch result.rank {
        case "S+": return Color(red: 1.0, green: 0.85, blue: 0.35)
        case "S": return Color(red: 1.0, green: 0.76, blue: 0.4)
        case "A": return Color(red: 0.45, green: 0.9, blue: 0.95)
        case "B": return Color(red: 0.55, green: 0.85, blue: 0.6)
        case "C": return Color(red: 0.7, green: 0.7, blue: 0.8)
        default: return Color(red: 0.92, green: 0.5, blue: 0.5)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text(chart.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(chart.difficultyName)  Lv.\(chart.level)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(chart.accent.color)
                }

                Text(result.rank)
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(rankColor)
                    .shadow(color: rankColor.opacity(0.6), radius: 22)

                VStack(spacing: 4) {
                    Text(result.score.formattedScore)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text(String(format: "准确率 %.2f%%   ·   最大连击 %d", result.accuracy * 100, result.maxCombo))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(OusicTheme.textSecondary)
                }

                HStack(spacing: 6) {
                    countChip("PERFECT", result.counts.perfect, Color(red: 0.4, green: 0.95, blue: 0.9))
                    countChip("GREAT", result.counts.great, Color(red: 0.6, green: 0.85, blue: 1))
                    countChip("GOOD", result.counts.good, Color(red: 1, green: 0.85, blue: 0.5))
                    countChip("MISS", result.counts.miss, Color(red: 0.95, green: 0.45, blue: 0.45))
                }

                if result.isFullCombo {
                    Text("FULL COMBO")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(chart.accent.color.opacity(0.35)))
                        .overlay(Capsule().stroke(chart.accent.color, lineWidth: 1))
                }

                VStack(spacing: 10) {
                    Button(action: onRestart) {
                        Text("再来一次")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(chart.accent.color))
                    }
                    Button(action: onExit) {
                        Text("返回曲库")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(OusicTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .padding(24)
        }
    }

    private func countChip(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
}
