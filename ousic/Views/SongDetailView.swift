import SwiftUI

struct SongDetailView: View {
    let song: SongGroup
    @EnvironmentObject private var store: ChartStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedChart: Chart?
    @State private var pendingDelete: Chart?
    @State private var showHelp = false

    private var accent: ChartAccent { song.accent }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                infoGrid
                chartList
                Text("提示：长按谱面行可删除导入的谱面。所有成绩自动保存在本机。")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(OusicTheme.textSecondary.opacity(0.8))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(OusicTheme.background.ignoresSafeArea())
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(OusicTheme.textSecondary)
                }
            }
        }
        .fullScreenCover(item: $selectedChart) { chart in
            GameView(chart: chart)
        }
        .sheet(isPresented: $showHelp) {
            ChartFormatHelpView()
        }
        .alert(item: $pendingDelete) { chart in
            Alert(title: Text("删除谱面"),
                  message: Text("将从本机移除「\(chart.title) \(chart.difficultyName)」，确定吗？"),
                  primaryButton: .destructive(Text("删除")) {
                      store.deleteImported(chart)
                  },
                  secondaryButton: .cancel(Text("取消")))
        }
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [accent.color.opacity(0.5), accent.color.opacity(0.08)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "waveform.path")
                            .font(.system(size: 60, weight: .heavy))
                            .foregroundColor(.white.opacity(0.12))
                            .offset(x: 110, y: -10)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text(song.artist)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(16)
            }

            HStack(spacing: 8) {
                ForEach(song.charts) { chart in
                    DifficultyBadge(name: chart.difficultyName, level: chart.level, accent: chart.accent, compact: false)
                }
                Spacer()
            }
        }
        .padding(.top, 6)
    }

    private var infoGrid: some View {
        let chart = song.charts.first
        return HStack(spacing: 10) {
            infoTile("BPM", chart.map { String(format: "%.0f", $0.bpm) } ?? "-")
            infoTile("轨道", chart.map { "\($0.laneCount)K" } ?? "-")
            infoTile("谱面", "\(song.charts.count)")
            infoTile("音符", chart.map { "\($0.noteCount)" } ?? "-")
        }
    }

    private func infoTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(OusicTheme.surface))
    }

    private var chartList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择难度")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            ForEach(song.charts) { chart in
                chartRow(chart)
            }
        }
    }

    private func chartRow(_ chart: Chart) -> some View {
        let best = ScoreStore.shared.record(for: chart)
        return Button {
            selectedChart = chart
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(chart.accent.color.opacity(0.16))
                    Text("\(chart.level)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(chart.accent.color)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(chart.difficultyName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Lv.\(chart.level)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(OusicTheme.textSecondary)
                    }
                    Text("\(chart.noteCount) 音符 · \(chart.charter)")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(OusicTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let best = best {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(best.rank)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(chart.accent.color)
                        Text(best.score.formattedScore)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(OusicTheme.textSecondary)
                    }
                }

                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(chart.accent.color.opacity(0.28)))
            }
            .padding(12)
            .ousicCard()
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !chart.isBuiltin {
                Button(role: .destructive) {
                    pendingDelete = chart
                } label: {
                    Label("删除这个谱面", systemImage: "trash")
                }
            }
        }
    }
}
