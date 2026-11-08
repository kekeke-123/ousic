import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = GameSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false
    @State private var showResetConfirm = false
    @State private var toast: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    group("手感") {
                        sliderRow(title: "下落速度", value: String(format: "%.2fx", settings.scrollSpeed),
                                  range: 0.5...3.0, binding: $settings.scrollSpeed)
                        divider
                        sliderRow(title: "判定偏移", value: String(format: "%+.0f ms", settings.offsetMs),
                                  range: -200...200, binding: $settings.offsetMs)
                        Text("如果总觉得打击偏早/偏晚，可以微调判定偏移：正值让判定线更早，负值更晚。")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundColor(OusicTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                        divider
                        sliderRow(title: "开始前倒计时", value: String(format: "%.0f s", settings.countdown),
                                  range: 0...4, binding: $settings.countdown)
                    }

                    group("反馈") {
                        toggleRow(title: "打击触感", isOn: $settings.haptics)
                        divider
                        toggleRow(title: "连击特效", isOn: $settings.showHitEffects)
                        divider
                        toggleRow(title: "打击音效", isOn: $settings.hitSoundEnabled)
                    }

                    group("谱面与数据") {
                        Button {
                            showHelp = true
                        } label: {
                            rowLabel(title: "关卡文件格式 .game", value: "查看说明", chevron: true)
                        }
                        .buttonStyle(.plain)
                        divider
                        Button {
                            showResetConfirm = true
                        } label: {
                            rowLabel(title: "清除全部成绩", value: "", chevron: true, tint: Color(red: 0.95, green: 0.5, blue: 0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ousic 1.0")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("一个用代码合成音乐的 iOS 下落式音乐游戏。内置 12 首原创曲目、48 张谱面，支持导入 .game 关卡（内嵌音频 / 击打音效 / 800 MB 以内）。")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundColor(OusicTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .background(OusicTheme.background.ignoresSafeArea())

            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showHelp) {
                ChartFormatHelpView()
            }
            .alert("清除全部成绩？", isPresented: $showResetConfirm) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: "ousic.bestRecords")
                    toast = "成绩已清除"
                }
            } message: {
                Text("所有谱面的最佳成绩将被删除，无法恢复。")
            }
            .overlay(alignment: .bottom) {
                if let toast = toast {
                    Text(toast)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(OusicTheme.surfaceHigh))
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, 14)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OusicTheme.surface))
        }
    }

    private func sliderRow(title: String, value: String, range: ClosedRange<Double>, binding: Binding<Double>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(OusicTheme.textSecondary)
                    .monospacedDigit()
            }
            Slider(value: binding, in: range)
                .tint(Color(red: 0.5, green: 0.85, blue: 1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Color(red: 0.4, green: 0.8, blue: 1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func rowLabel(title: String, value: String, chevron: Bool, tint: Color = .white) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(tint)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(OusicTheme.textSecondary)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(OusicTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
