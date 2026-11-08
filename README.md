# ousic

一个用代码合成音乐的 iOS 下落式音游：4K / 6K / 8K 自适应、内置 12 首原创曲目共 48 张谱面、支持导入 `.game` 关卡（音频可直接内嵌）。

- 系统要求：iOS 15.0+（arm64），新旧系统通用；界面使用系统标准控件，iOS 26 起的液态玻璃外观自动生效。
- Bundle ID：`com.ousic.game`

## 玩法

- 判定窗口：Perfect 55 ms / Great 110 ms / Good 175 ms。
- 支持 tap 与 hold（长按到尾部结算，提前松手记 MISS）。
- 连击、准确率、评级 S+ / S / A / B / C / D，零 miss 且 ≥ 99.5% 为 S+，全连显示 Full Combo。
- 设置：下落速度 0.5–3.0x、判定偏移 ±200 ms、倒计时、触感、打击音效、清除成绩。

## 构建（GitHub Actions，未签名）

仓库自带 `.github/workflows/build.yml`：推送到 `main` 后在 macOS runner 上生成图标与内置谱面，`CODE_SIGNING_ALLOWED=NO` 编译，打包成 `Payload/ousic.app` 结构的 `ousic-unsigned.ipa`，上传 artifact 并创建 Release。

本地构建：

```bash
python3 tools/make_icon.py
python3 tools/make_charts.py
xcodebuild -project ousic.xcodeproj -scheme ousic -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" ARCHS=arm64 build
```

产物是**未签名 IPA**，用全能签 / Sideloadly / AltStore 等工具自行签名安装。
如果使用自带 `app.xigua642.river1600` 的描述文件签名，签名工具的 Bundle ID 必须改成 `app.xigua642.river1600`（`com.ousic.game` 与那张描述文件不匹配）。

## 导入 `.game`

三种方式都会导入到「我的导入」分组：

1. 分享面板：在「文件」、微信、QQ、浏览器下载页里点分享，选择 ousic。
2. 「文件」App 里点开 `.game`，选「用 ousic 打开」。
3. App 首页「导入 .game 关卡」，支持多选。

单个 `.game` 文件上限 **800 MB**，超过会直接拒绝并提示。

## `.game` 格式

UTF-8 JSON，扩展名固定 `.game`。音频、击打音效、谱面、曲名、作者都放在同一个文件里：

```json
{
  "format": "ousic.game",
  "version": 2,
  "id": "my-song-expert",
  "songId": "my-song",
  "title": "My Song",
  "artist": "Someone",
  "charter": "Me",
  "bpm": 150,
  "offset": 0,
  "lanes": 4,
  "audio": {
    "type": "embedded",
    "file": "song.m4a",
    "data": "……歌曲音频的 base64……",
    "hitSound": "……击打音效 wav 的 base64，可省略……"
  },
  "difficulty": { "name": "Expert", "level": 12 },
  "color": "#5AD9FA",
  "notes": [
    { "t": 2000, "lane": 0, "type": "tap" },
    { "t": 2400, "lane": 2, "type": "tap" },
    { "t": 2800, "lane": 1, "type": "hold", "d": 600 }
  ]
}
```

- `audio.type = embedded`：导入时把 `data` 解成 `Documents/Audio/<名字>-audio.<扩展名>`，之后直接从本地读，不再需要原文件。
- `audio.hitSound`：导入时解成 wav 文件，游戏里每次点中音符播放它；不写则用系统提示音。
- `audio.type = synth`：不写音频，用内置合成曲，`id` 取 `aurora / neon / sakura / midnight / arcade / glacier / ember / echo / coral / velocity / lumen / prism`，`bars` 可覆盖曲长。
- `audio.type = file`：引用 `Documents/Audio` 里已经存在的文件（配合「文件」App 手动放置）。
- 同一 `songId` 的多个难度会合并为一首歌。

## 目录

```
ousic/App        SwiftUI 入口
ousic/Core       .game 模型与解析、谱面库、成绩
o​usic/Audio      合成器与 AVAudioEngine 播放、打击音效
ousic/Game       SpriteKit 场景与游戏状态机
ousic/Views      首页 / 曲目详情 / 设置 / 结算 / 格式说明
ousic/Resources  Assets.xcassets、Charts（构建时生成）
tools            make_icon.py、make_charts.py、make_project.py
```
