# 原型

> 这里只放**原型**，不放产品代码。
> 原型的状态即"当前 UI 的权威定义"，`docs/03`、`docs/04` 已按它重写。
> **所有连接、权限、成功、失败和延迟均为演示数据，不能作为真实运行证据；页面已标注「演示数据 · 非实时状态」。**

## 1. 目录

```
prototype/
├── README.md
├── voice-remote-mobile/     ← 手机端：React + Vite + Tailwind + zustand，可交互
│   ├── config.json          ← 路由与组件声明（14 个路由）
│   ├── src/pages/           ← M-01…M-09、M-11…M-13 + Index + Components
│   ├── src/components/      ← PhoneScreen / StatusBar / Waveform / HoldButton / ControlPanel
│   ├── src/store/voice.ts   ← 全局状态（连接、权限、后端、最近一条）
│   └── src/data/apps.ts     ← 演示 App 数据、常用键、错误原因、示例句
└── voicerelay-mac/          ← Mac 端：8 个静态 HTML 规格页
    ├── home.html            ← 画板索引
    ├── menubar.html         ← D-01
    ├── popover.html         ← D-02 / D-03 / D-04
    ├── settings.html        ← D-05 / D-06 / D-07
    ├── onboarding.html      ← D-08
    ├── overlay.html         ← D-09
    ├── states.html          ← D-10
    └── components.html      ← C-D
```

## 2. 怎么跑

### 手机端

```bash
cd prototype/voice-remote-mobile
npm install
npm run dev
```

打开终端给出的地址，`/` 是画板索引。项目使用 HashRouter，浏览器地址需写成 `/#/m01`…`/#/m13`，组件页为 `/#/components`。

### Mac 端

直接用浏览器打开 `voicerelay-mac/home.html`。每页右上角可切浅色/深色，多数页面带可点的状态演示。

注意：Mac 端引用了 `modao.cc` 的 Tailwind 与 iconify CDN，**离线打不开样式**；需要离线时把这两个脚本换成本地文件。

## 3. 手机端画板映射

| 画板 | 路由 | 文件 | 关键状态 |
|---|---|---|---|
| M-01 欢迎 | `/m01` | `pages/Welcome.tsx` | 默认 |
| M-02 权限 | `/m02` | `pages/Permissions.tsx` | 待授权 / 已授权 / 已拒绝 |
| M-03 搜索 | `/m03` | `pages/Discover.tsx` | 搜索 / 找到 / 0 个 / 失败（15 s 转空） |
| M-04 扫码 | `/m04` | `pages/ScanPair.tsx` | 取景 / 识别成功 |
| M-05 主屏 | `/m05` | `components/VoiceHomeScreen.tsx` | 最近文本 + App/光标/回车快捷控制 |
| M-06 收音 | `/m06` | `pages/Listening.tsx` | 计时 / 50 s 告警 |
| M-07 识别 | `/m07` | `pages/Recognizing.tsx` | 三步骤推进 / 3 s 超时 |
| M-08 成功 | `/m08` | `pages/Delivered.tsx` | 竖条 2 s 淡出 |
| M-09 失败 | `/m09` | `pages/Failed.tsx` | 四类原因切换 |
| M-11 设置 | `/m11` | `pages/Settings.tsx` | 后端切换 / 开关 |
| M-12 重连 | `/m12` | `pages/Reconnect.tsx` | 自检 4 项 / 重连中 / 成功 |
| M-13 未连接 | `/m13` | `pages/Disconnected.tsx` | 空态 + 禁用按钮 |
| C-01 组件 | `/components` | `pages/Components.tsx` | 主按钮 4 态 / 状态条 7 态 |

## 4. Mac 端画板映射

| 画板 | 文件 | 覆盖 |
|---|---|---|
| D-01 菜单栏 | `menubar.html` | 四态图标、浅深色、200 ms 过渡 |
| D-02/03/04 弹窗 | `popover.html` | 已连接 / 收音中 / 未连接、后端切换、退出确认 |
| D-05 通用 | `settings.html` | 自启、悬浮窗、图标样式、语言 |
| D-06 权限 | `settings.html` | 三态总览、卡片三态、为什么展开、重新检测 |
| D-07 语音 | `settings.html` | 后端、模型、灵敏度、松手延迟、最长录音 |
| D-08 向导 | `onboarding.html` | 三步 + 跳过 + 第 3 步需真实音频 |
| D-09 悬浮窗 | `overlay.html` | 140×44、淡入淡出、不抢焦点 |
| D-10 异常态 | `states.html` | 5 个场景 + 通知策略 |
| C-D 组件 | `components.html` | 权限卡、状态行、电平条、下拉、文本项 |

## 5. 视觉基线

| 端 | 基准 | 关键尺寸 |
|---|---|---|
| 手机 | 390 × 844，竖屏 | 状态条 44、主按钮 112/120、波形 96、抽屉 ≤62% |
| Mac 弹窗 | 320 × 420，圆角 12 | 状态行 44、电平 72、底部 40 + 44 |
| Mac 设置 | 720 × 520（最小 680 × 480） | 6 分区 |
| Mac 向导 | 560 × 400 | 3 步 |
| Mac 悬浮窗 | 140 × 44，圆角 10 | 5 条 + 红点 |

| 端 | 主色 | 圆角 | 字号 |
|---|---|---|---|
| 手机 | `#2563eb` + slate 灰阶 | 16 / 28 | 26 / 18 / 15 / 13 / 11 |
| Mac | 系统语义色（accent `#0a6cff`） | 12 / 10 / 8 | 15 / 13 / 11 |

## 6. 原型里是假数据的部分

实现时全部替换为真实值，不要照抄：

| 位置 | 假数据 |
|---|---|
| 手机 M-05 | 「延迟 0.3 秒」、光标位置文案 |
| 手机 M-08 | 「用时 0.3 秒」、字数 |
| 手机 M-12 | 自检 4 项的结果 |
| Mac 弹窗 | 局域网 IP、`18 ms` |
| Mac 设置 | 端口 `8787`（真实）、版本已改为 `1.0.0 (1)`、配对设备 `iPhone 15 Pro` |
| Mac 向导 | `voicerelay.local:8787`、信号 `-∞ dB` |

## 7. 文案修正记录（2026-11-26 已完成）

原型是视觉参考，`docs/03`、`docs/04` 才是工程依据（D-12）。以下 5 处已按文档改完：

| # | 文件 | 改动 | 状态 |
|---|---|---|---|
| C-01 | `voicerelay-mac/settings.html`、`popover.html`、`states.html` | `Whisper Small / 466 MB / 420 MB` → `SenseVoice Small（int8）/ 约 230 MB / 约 300 MB`；许可文案改 `sherpa-onnx · Apache-2.0` | ✅ |
| C-02 | `voice-remote-mobile/src/pages/Settings.tsx` | 「在手机上识别，快，断网也能用」→「在 Mac 上识别，音频不出局域网」 | ✅ |
| C-03 | `voicerelay-mac/settings.html` | 仅输入监控显示「立即重启」，辅助功能/蓝牙显示「重新检测」；"需重启"演示数据改为只有输入监控 | ✅ |
| C-04 | `voice-remote-mobile/src/pages/Components.tsx` | 「状态条 · 5 态」→「6 态」 | ✅ |
| C-05 | 手机 Welcome / Recognizing / Delivered / Components | 「本机识别 / 本机处理」→「Mac 端识别 / 在 Mac 上处理」 | ✅ |
| C-06 | Mac / mobile 全部原型 | 成功、权限、延迟等演示数据容易被当作真实状态 | 每页标注「演示数据 · 非实时状态」；B 改为「已发送·未确认」；状态条补第 7 态 | ✅ |

后续如再改原型，先改 `docs/`，再同步这里和 `README.md` 第四节。
