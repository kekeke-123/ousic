import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var store: ChartStore
    @ObservedObject private var settings = GameSettings.shared

    @State private var showImporter = false
    @State private var showSettings = false
    @State private var toast: String?
    @State private var toastIsError = false
    @State private var pendingImportCount = 0

    private var gameType: UTType {
        UTType(filenameExtension: "game") ?? .json
    }

    private var totalCharts: Int {
        store.songs.reduce(0) { $0 + $1.charts.count } + store.importedSongs.reduce(0) { $0 + $1.charts.count }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    actionRow
                    statsRow

                    sectionHeader("内置曲库", subtitle: "\(store.songs.count) 首")
                    LazyVStack(spacing: 10) {
                        ForEach(store.songs) { song in
                            songCard(song)
                        }
                    }

                    if !store.importedSongs.isEmpty {
                        sectionHeader("我的导入", subtitle: "\(store.importedSongs.count) 首")
                        LazyVStack(spacing: 10) {
                            ForEach(store.importedSongs) { song in
                                songCard(song)
                            }
                        }
                    } else {
                        importEmptyHint
                    }

                    Text("ousic · 用 .game 文件扩展你的曲库")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(OusicTheme.textSecondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .background(OusicTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [gameType, .json],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .overlay(alignment: .top) {
                if let toast = toast {
                    Text(toast)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(toastIsError
                                ? Color(red: 0.45, green: 0.18, blue: 0.22)
                                : Color(red: 0.16, green: 0.2, blue: 0.28))
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear { store.loadIfNeeded() }
            .onChange(of: store.importFeedback) { value in
                guard let value = value else { return }
                showToast(value, isError: store.importFailed)
                DispatchQueue.main.async { store.importFeedback = nil }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OUSIC")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(
                            LinearGradient(colors: [Color(red: 0.45, green: 0.93, blue: 0.98),
                                                    Color(red: 0.72, green: 0.55, blue: 1.0)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    Text("RHYTHM ENGINE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundColor(OusicTheme.textSecondary)
                }
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(OusicTheme.surfaceHigh))
                }
            }
            .padding(.top, 10)
        }
    }

    private var actionRow: some View {
        Button {
            showImporter = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .bold))
                Text("导入 .game 关卡")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text("支持多选")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(OusicTheme.textSecondary)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.28, blue: 0.42),
                                                  Color(red: 0.16, green: 0.2, blue: 0.3)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statTile(value: "\(store.songs.count)", label: "内置曲目")
            statTile(value: "\(totalCharts)", label: "可用谱面")
            statTile(value: "Lv.\(store.songs.map(\.highestLevel).max() ?? 0)", label: "最高难度")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(OusicTheme.surface))
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
            Spacer()
        }
        .padding(.top, 4)
    }

    private var importEmptyHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有导入的谱面")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Text("在「文件」App 里点开任意 .game 文件即可直接导入；也可以从谱面作者那里拿到 .game 后用上面的按钮导入。格式说明见设置页。")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(OusicTheme.surface.opacity(0.7)))
    }

    // MARK: 歌曲卡片

    private func songCard(_ song: SongGroup) -> some View {
        NavigationLink(destination: SongDetailView(song: song)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [song.accent.color.opacity(0.55),
                                                      song.accent.color.opacity(0.16)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 5) {
                    Text(song.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(OusicTheme.textSecondary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        ForEach(song.charts) { chart in
                            DifficultyBadge(name: chart.difficultyName, level: chart.level, accent: chart.accent)
                        }
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(OusicTheme.textSecondary)
            }
            .padding(12)
            .ousicCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: 导入

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let store = self.store
            DispatchQueue.global(qos: .userInitiated).async {
                var succeeded = 0
                var lastError: String?
                for url in urls {
                    do {
                        _ = try store.importChart(from: url)
                        succeeded += 1
                    } catch {
                        lastError = error.localizedDescription
                    }
                }
                DispatchQueue.main.async {
                    if succeeded > 0 {
                        store.importFailed = false
                        store.importFeedback = "已导入 \(succeeded) 个谱面"
                    } else if let lastError = lastError {
                        store.importFailed = true
                        store.importFeedback = lastError
                    }
                }
            }
        case .failure(let error):
            showToast("导入失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func showToast(_ text: String, isError: Bool) {
        toastIsError = isError
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toast = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.25)) {
                toast = nil
            }
        }
    }
}
