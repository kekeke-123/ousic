import SwiftUI
import UIKit

struct ChartFormatHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private let sample = """
    {
      "format": "ousic.game",
      "version": 1,
      "id": "my-song-easy",
      "songId": "my-song",
      "title": "My Song",
      "artist": "Someone",
      "charter": "Me",
      "bpm": 140,
      "offset": 0,
      "lanes": 4,
      "audio": {
        "type": "embedded",
        "file": "song.m4a",
        "data": "AAAA....（歌曲音频的 base64，可省略）",
        "hitSound": "AAAA....（击打音效 wav 的 base64，可省略）"
      },
      "difficulty": { "name": "Easy", "level": 4 },
      "color": "#5AD9FA",
      "notes": [
        { "t": 2000, "lane": 0, "type": "tap" },
        { "t": 2400, "lane": 2, "type": "tap" },
        { "t": 2800, "lane": 1, "type": "hold", "d": 600 },
        { "t": 3600, "lane": 3, "type": "tap" }
      ]
    }
    """

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    fieldTable
                    sampleSection
                    audioSection
                    importSection
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(OusicTheme.background.ignoresSafeArea())
            .navigationTitle(".game 格式说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一个关卡就是一个 .game 文件")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(".game 是 UTF-8 编码的 JSON 文本，扩展名固定为 .game。一首曲子最重要的音频可以整段以 base64 内嵌在文件里，配合音符位置（notes）、击打音效、曲名与作者一起发给别人，对方导入后即可直接开打。时间单位是毫秒，轨道从 0 开始编号，支持 tap（单击）和 hold（长按）。单个文件上限 800 MB。")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fieldTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("字段")
            VStack(spacing: 0) {
                fieldRow("id", "必填，谱面唯一标识，建议用 songId + 难度")
                divider
                fieldRow("songId", "同一首歌的多个难度使用相同 songId，会合并成一首歌")
                divider
                fieldRow("title / artist", "必填 / 可选，歌曲名与作者")
                divider
                fieldRow("bpm", "必填，节拍速度，用于计算判定与显示")
                divider
                fieldRow("offset", "音频开始到谱面时间 0 的毫秒数，可正可负，默认 0")
                divider
                fieldRow("lanes", "轨道数 1–8，默认 4")
                divider
                fieldRow("audio.type", "synth：内置合成曲；embedded：音频以 base64 存在 data 里，导入时自动解出；file：引用 Documents/Audio 里的文件")
                divider
                fieldRow("audio.data", "歌曲音频的 base64（mp3/m4a/wav/aac/flac 均可，按 file 的扩展名决定存储格式）")
                divider
                fieldRow("audio.hitSound", "击打音效的 base64（wav），导入后点按音符就会播放它；不写则用系统提示音")
                divider
                fieldRow("audio.id / bars", "type=synth 时使用：id 决定曲风（见下），bars 覆盖小节数")
                divider
                fieldRow("difficulty", "{ name, level }，name 会显示在难度标签上")
                divider
                fieldRow("color", "主题色 #RRGGBB，可省略")
                divider
                fieldRow("notes[].t", "击打时刻（毫秒）")
                divider
                fieldRow("notes[].lane", "轨道下标，0 … lanes-1")
                divider
                fieldRow("notes[].type", "tap 或 hold，默认 tap")
                divider
                fieldRow("notes[].d", "hold 的持续毫秒数")
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OusicTheme.surface))
        }
    }

    private func fieldRow(_ name: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.5, green: 0.88, blue: 1))
            Text(description)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, 14)
    }

    private var sampleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("最小示例")
                Spacer()
                Button {
                    UIPasteboard.general.string = sample
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
                } label: {
                    Text(copied ? "已复制" : "复制")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(sample)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(Color(white: 0.85))
                    .padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)))
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("内置曲目 ID")
            Text("aurora · neon · sakura · midnight · arcade · glacier · ember · echo · coral · velocity · lumen · prism")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(OusicTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("推荐把音频直接嵌进 .game：audio.type 写 embedded，file 写歌曲文件名（如 song.m4a），data 填该文件内容的 base64。导入时 App 会把它解成 Documents/Audio 下的真实文件，下次启动直接从那里读，不需要再联网或手动放文件。单个 .game 文件上限 800 MB，超过会拒绝导入。")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("怎么导入")
            bullet("分享面板：在「文件」、微信、QQ、浏览器下载页等地方点分享，选择 ousic 即可直接导入。")
            bullet("「文件」App 里长按/点开 .game，选「用 ousic 打开」，同样会自动导入。")
            bullet("App 内：首页点「导入 .game 关卡」，支持一次选多个文件。")
            bullet("导入的谱面会出现在首页「我的导入」分组，长按谱面行可以删除。")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color(red: 0.5, green: 0.85, blue: 1)).frame(width: 4, height: 4)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(OusicTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(.white)
    }
}
