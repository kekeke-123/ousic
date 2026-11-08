import SwiftUI
import SpriteKit

struct GameSceneView: UIViewRepresentable {
    @ObservedObject var controller: GameController

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.backgroundColor = .black

        let scene = GameScene(chart: controller.chart,
                              settings: GameSettings.shared,
                              music: controller.music)
        controller.attach(scene: scene)
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {}
}

// MARK: - 游戏界面

struct GameView: View {
    @StateObject private var controller: GameController
    @ObservedObject private var settings = GameSettings.shared
    @Environment(\.dismiss) private var dismiss

    init(chart: Chart) {
        _controller = StateObject(wrappedValue: GameController(chart: chart))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GameSceneView(controller: controller)
                .ignoresSafeArea()

            hud

            overlay

            if let result = controller.result {
                ResultView(chart: controller.chart,
                           result: result,
                           onRestart: { controller.restart() },
                           onExit: {
                               controller.quit()
                               dismiss()
                           })
                    .transition(.opacity)
            }
        }
        .statusBarHidden(true)
        .onAppear { controller.load() }
    }

    private var accent: ChartAccent { controller.chart.accent }

    private var hud: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(controller.score.formattedScore)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text(String(format: "%.2f%%", controller.counts.accuracy * 100))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(OusicTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("MISS \(controller.counts.miss)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(controller.counts.miss > 0 ? Color(red: 0.95, green: 0.45, blue: 0.45) : OusicTheme.textSecondary)
                    Text("MAX \(controller.maxCombo)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(OusicTheme.textSecondary)
                }
                Button {
                    controller.pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .padding(.leading, 10)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(accent.color)
                        .frame(width: max(0, proxy.size.width * CGFloat(controller.progress)))
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 18)
            .padding(.top, 10)

            Spacer()

            if controller.combo >= 3 {
                VStack(spacing: -2) {
                    Text("\(controller.combo)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: accent.color.opacity(0.8), radius: 14)
                        .monospacedDigit()
                    Text("COMBO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundColor(accent.color)
                }
                .padding(.bottom, 150)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .allowsHitTesting(controller.phase == .playing)
    }

    @ViewBuilder
    private var overlay: some View {
        switch controller.phase {
        case .loading:
            overlayCard {
                VStack(spacing: 14) {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                    Text("正在合成曲目…")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(OusicTheme.textSecondary)
                    Text(controller.chart.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        case .countdown:
            VStack(spacing: 6) {
                Text("\(controller.countdownValue)")
                    .font(.system(size: 90, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: accent.color, radius: 24)
                    .id(controller.countdownValue)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                Text(controller.chart.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(OusicTheme.textSecondary)
            }
            .allowsHitTesting(false)
        case .paused:
            overlayCard {
                VStack(spacing: 18) {
                    Text("已暂停")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(controller.chart.title)  ·  \(controller.chart.levelLabel)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(OusicTheme.textSecondary)

                    VStack(spacing: 10) {
                        Button {
                            controller.resume()
                        } label: {
                            Text("继续")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(accent.color))
                        }
                        Button {
                            controller.restart()
                        } label: {
                            Text("重新开始")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        Button {
                            controller.quit()
                            dismiss()
                        } label: {
                            Text("退出")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(OusicTheme.textSecondary)
                                .padding(.vertical, 6)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        case .playing, .finished:
            EmptyView()
        }
    }

    private func overlayCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            content()
                .padding(24)
                .frame(maxWidth: 300)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(OusicTheme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
                .padding(40)
        }
    }
}
