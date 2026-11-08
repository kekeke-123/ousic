import SwiftUI
import Foundation

enum OusicTheme {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.075)
    static let surface = Color(red: 0.075, green: 0.085, blue: 0.125)
    static let surfaceHigh = Color(red: 0.11, green: 0.12, blue: 0.17)
    static let textPrimary = Color(white: 0.95)
    static let textSecondary = Color(white: 0.62)
    static let stroke = Color(white: 0.22)

    static func color(_ accent: ChartAccent, alpha: Double = 1) -> Color {
        Color(red: accent.red, green: accent.green, blue: accent.blue, opacity: alpha)
    }
}

extension Color {
    init(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: text).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension ChartAccent {
    var color: Color { OusicTheme.color(self) }
}

extension Int {
    var formattedScore: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

struct DifficultyBadge: View {
    let name: String
    let level: Int
    let accent: ChartAccent
    var compact: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Text(name.uppercased())
                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
            Text("\(level)")
                .font(.system(size: compact ? 11 : 12, weight: .heavy, design: .rounded))
        }
        .foregroundColor(accent.color)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 5)
        .background(
            Capsule().fill(accent.color.opacity(0.12))
                .overlay(Capsule().stroke(accent.color.opacity(0.45), lineWidth: 0.8))
        )
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(OusicTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func ousicCard() -> some View { modifier(CardModifier()) }
}
