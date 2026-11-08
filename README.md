# ousic

一个 iOS 上的下落式音乐游戏（4K / 6K / 8K 自适应），内置 12 首曲目、48 张谱面，音乐全部由代码实时合成，并支持导入 `.game` 关卡文件。

## 特性

- **下落式音游核心**：Perfect / Great / Good / Miss 四档判定，长按 note、连击、准确率、S / A / B / C / D 评级、Full Combo
- **多指触控**：基于 SpriteKit 原生多点触控，四轨可同时按下
- **程序化音乐**：`SongSynth` 用方波 / 锯齿 / 正弦 / 噪声实时合成鼓组、贝斯、琶音，不打包任何音频文件，无版权问题
- **48 张内置谱面**：12 首原创曲 × Easy / Normal / Hard / Expert
- **`.game` 关卡导入**：从「文件」App 或首页导入，支持多选、长按删除
- **音频文件支持**：`.game` 可指向 `Documents/Audio` 下的 m4a/wav，并使用 AVAudioPlayerNode 精确时钟
- **手感校准**：下落速度、判定偏移、倒计时、触感、特效均可调
- **成绩存档**：最佳分数 / 准确率 / 评级 / 最大连击保存在本机

## 目录结构

```
ousic.xcodeproj          # Xcode 工程（由 tools/make_project.py 生成）
ousic/
  App/OusicApp.swift     # SwiftUI 入口、.game 文件打开回调
  Core/Chart.swift       # .game 模型与解析
  Core/ChartStore.swift  # 内置 / 导入谱面加载、成绩存档
  Core/GameResult.swift  # 判定与结算模型
  Core/GameSettings.swift
  Audio/SongSynth.swift  # 程序化编曲与 PCM 渲染
  Audio/MusicPlayer.swift# AVAudioEngine 播放与时钟
  Game/GameScene.swift   # SpriteKit 玩法场景、判定、长按
  Game/GameController.swift
  Game/GameView.swift    # HUD、倒计时、暂停
  Views/                 # 首页、曲目详情、结算、设置、格式说明
  Info.plist             # 声明 .game 文件类型
Charts/                  # 48 张内置 .game 谱面（文件夹引用进 Bundle）
tools/make_charts.py     # 谱面生成脚本
tools/make_project.py    # Xcode 工程生成脚本
```

## 构建（GitHub Actions，未签名）

推送到 `main` 或手动触发 `Build unsigned IPA`：

```bash
xcodebuild -project ousic.xcodeproj -scheme ousic -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" ARCHS=arm64 build
mkdir -p Payload && cp -R build/Build/Products/Release-iphoneos/ousic.app Payload/
zip -qr ousic-unsigned.ipa Payload
```

CI 会把 `ousic-unsigned.ipa` 作为 artifact 上传，并在同一次运行里创建 `build-<run_number>` Release 供直接下载。

## 安装

产物是**未签名** ipa，需自行重签后安装：

- 全能签 / 爱思助手 / Sideloadly（导入 p12 + mobileprovision）
- 或用 Xcode / AltStore 自签

> 用第三方证书签名时，Bundle ID 必须与描述文件里的 App ID 完全一致，否则安装会报签名或权限错误。

## .game 格式

UTF-8 JSON，扩展名 `.game`，最小示例：

```json
{
  "format": "ousic.game",
  "version": 1,
  "id": "my-song-easy",
  "songId": "my-song",
  "title": "My Song",
  "artist": "Someone",
  "bpm": 140,
  "offset": 0,
  "lanes": 4,
  "audio": { "type": "synth", "id": "neon", "bars": 72 },
  "difficulty": { "name": "Easy", "level": 4 },
  "color": "#5AD9FA",
  "notes": [
    { "t": 2000, "lane": 0, "type": "tap" },
    { "t": 2800, "lane": 1, "type": "hold", "d": 600 }
  ]
}
```

- `t` / `d` 单位毫秒，`lane` 从 0 开始
- `audio.type = synth` 时使用内置合成曲（`aurora` `neon` `sakura` `midnight` `arcade` `glacier` `ember` `echo` `coral` `velocity` `lumen` `prism`）
- `audio.type = file` 时播放 `Documents/Audio/<file>`，音频需自行通过「文件」App 放入 ousic 的 Audio 目录
- 同一个 `songId` 的多个难度会合并为一首歌

## 说明

内置曲目为程序化生成，不存在第三方音乐版权；谱面为脚本自动生成，可自由修改 `tools/make_charts.py` 后重新生成。
