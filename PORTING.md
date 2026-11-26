# FlyMe2theMoon ARM64 移植与 IPA 编译流程（实际实施记录）

本文记录本仓库实际做到的路线、证据和取舍，对应“从零重建、不处理签名、产出未签名 arm64 IPA”的目标。
与原版 32 位 IPA 的差别在于：**没有做指令集翻译，而是重建运行时**——原版 32 位 Mach-O 无法转换成 arm64，
素材包里也没有可直接复用的 64 位引擎，因此保留原版的数据与脚本，用原生新引擎承载。

## 1. 素材取证

- 唯一素材来源：release `assets` 的 `FlyMe2theMoon_v1.7.0_unsigned.ipa`
  （35.7 MB，sha256 `4d534ae9f20f5344af535df91022bb207db18e53937de888f959c6168eac87cf`）。
- 该包本身已是 arm64：Bundle ID `com.mihoyo.flyme2themoon.arm64`、`MinimumOSVersion 16.0`、
  SDK 16.4，主程序 `CPU_TYPE_ARM64`——它是“素材来源包”，不是 2011 年那份 armv7 原版。
- 包内可用素材：`levels.json`（60 关）、`atlas.json`（cocos2d 9 元组图集）、`atlas/*.png`（19 页）、
  `edges.json`（碰撞多边形）、`dialogs.json`（145 个可索引键）、`role.json`、`score.json`、
  `audio/`（70 个 wav 音效）、`art/`（12 张表情 + splash）、`lua/`（60 个关卡脚本）。
- 缺口：包内**没有 BGM**（6 首 `.caf` 只在更早的 1.1 版本，直链已 404 不可得）、没有教程图、
  没有原版 cocos2d plist 与回放数据。

## 2. 数据格式结论

- `levels.json`：世界尺寸最大 3200×7200，`born` 为出生点，图层 `type` 取值
  `0 Background / 1 Farground / 2 StaticObject / 3 Texture / 4 DynamicObject / 5 Item / 6 Foreground / 8 Area`。
- `atlas.json`：`[x, y, w, h, rotated, offX, offY, srcW, srcH]`。`rotated` 帧在图集里占 `(x, y, h, w)`，
  像素内容是顺时针 90°，离线用 `rotate(-90, expand=True)` 转正。
- `edges.json`：`StaticObject.seq` → 世界坐标多边形，用于碰撞。
- `role.json`：`pushAngleRange 50`、`pushDistance1/2 = 51.2 / 64`，作为手感基准。
- `score.json.svrs`：星级阈值，按通关时间比较（≤阈值 3 星、≤1.8 倍 2 星、否则 1 星）。

## 3. 运行时架构

| 模块 | 文件 | 职责 |
|---|---|---|
| 入口 | `App/FMApp.swift` | SwiftUI `App`，挂载根视图 |
| 根界面 | `App/UI/FMRootView.swift` | 菜单 / 选关 / 关卡容器切换 |
| 数据 | `App/Data/FMModels.swift`、`FMGameData.swift` | 关卡、图集、碰撞、对话框、角色参数解码 |
| 存档 | `App/Data/FMProgressStore.swift` | 通关、星级、剧情标记写 UserDefaults |
| 关卡场景 | `App/Game/FMLevelScene.swift` | 图层、精灵、物理、相机、输入、事件 |
| 脚本宿主 | `App/Lua/FMLuaHost.{h,m}` | Lua 5.1 状态、协程、30 个接口、23 个委托回调 |
| 音频 | `App/Audio/FMAudioEngine.swift` | 音效预加载与并发播放 |
| 界面 | `App/UI/FMMenuView/FMStageSelectView/FMRichText/FMSettingsView/FMLevelView/FMLevelModel` | 菜单、选关、富文本、HUD、对话框、结算 |

技术选型：SwiftUI 外壳 + SpriteKit 场景 + Lua 5.1.5（Objective-C 宿主）。之所以用 SpriteKit 而不是
自建 Metal 渲染，是因为原版是 2D 精灵 + 固定相机 + 简单刚体的组合，SpriteKit 的坐标系（左下原点、
y 向上）与 cocos2d 一致，能省掉一次坐标翻转的坑。

### 图集与纹理

`atlas.json` 是像素坐标（左上原点），而 `SKTexture(rect:in:)` 用的 UV 是左下原点，直接喂会上下颠倒。
实现改为 `CGImage.cropping(to:)` 按像素矩形裁剪，再 `SKTexture(cgImage:)`：外层 holder 节点按
`srcW×srcH` 定位，内层裁剪帧按 `offset` 摆放。旋转帧在离线阶段转正并写进补页，运行时不处理旋转。

### 物理

自写圆 vs 多边形线段求解（`resolveCircle`）：角色半径 30px，`StaticObject` 的 `seq` 查 `edges.json`
得到多边形，碰撞后按法线消去速度分量。调参：重力 −900、弹射初速 520–980、拖拽 45–260、
空中阻尼 0.45、地面摩擦 0.82、`Area` 判定半径 64、弹射角度 ±50°。

过关判定：触达 `Area` 点（半径 64）或 `y ≥ 关卡高度 − 24`（无 `Area` 关卡的兜底）。

### Lua 宿主

`FMLuaHost` 注册 base/table/string/math 四库（去掉 io/os/package），按原版脚本的调用面提供 30 个
全局接口。`dialog.show`、`script.delay` 之类用 `coroutine.yield` 把控制权交回原生，原生每帧
`tick` 恢复协程；`onRoleReachedMoon` / `onRoleDied` 作为全局函数回调。`FM_DELEGATE` 宏负责把
Lua 调用转成 Objective-C 消息（注意宏参数必须是带冒号的完整消息，例如 `luaPlaySound:s`）。

### 资源管线

`ci/prepare_assets.py`：从 `.app` 取 `data/`、`audio/`、`art/`、`fonts/` 与图集页，未旋转帧按原页矩形
零拷贝引用，旋转帧转正后写 `*-extraN.png` 补页，输出 `atlas/frames.json`（1051 帧 + 补页共 1122 帧、
71 个旋转帧、Resources 约 38 MB）。`ci/verify_data.py` 断言 60 关 / 22403 个贴图对象 / 1122 帧 /
60 个 Lua 脚本 / 70 个音效；`ci/check_ipa.py` 在打包后断言结构、arm64 与“完全未签名”。

## 4. GitHub Actions 流水线

`.github/workflows/build.yml`：`push main` 与 `workflow_dispatch` 触发，`permissions: contents: write`，
`runs-on: macos-15`（实测 Xcode 16.4 / iPhoneOS 18.5 SDK），60 分钟超时，`concurrency` 取消旧运行。
`ci/pipeline.sh` 的步骤：

1. 装 `xcodegen`；用 `python3 -m venv` 装 Pillow（macOS 运行器是 PEP 668 的 externally-managed 环境，
   `--user`/`--break-system-packages` 都会失败）。
2. 下载 Lua 5.1.5 源码（`https://www.lua.org/ftp/lua-5.1.5.tar.gz`），剔掉 `lua.c/luac.c/liolib/loslib/loadlib/linit`。
3. 下载并解包素材 IPA，调 `prepare_assets.py` 与 `verify_data.py`。
4. `xcodegen generate`，`xcodebuild -configuration Release -sdk iphoneos ARCHS=arm64 CODE_SIGNING_ALLOWED=NO`。
5. 全量校验：主程序 `lipo -info` 必须是 arm64，app 内每个 Mach-O 都必须是 arm64。
6. 打 IPA：建 `Payload/`，`codesign --remove-signature` 去掉 linker 残留签名并删除
   `_CodeSignature`，`zip -qry $IPA Payload`，再用 `ci/check_ipa.py` 断言 Payload 顶层结构、
   主程序 arm64、完全未签名（无 `LC_CODE_SIGNATURE`）、资源齐全。
7. `gh release upload build` 覆盖上传 `FlyMe2theMoon-v1.7.0-arm64-unsigned.ipa`；同时上传 artifact
   `FlyMe2theMoon-unsigned-ipa`。失败时把 `build-log.md` 推到 `ci-logs` 分支。

产物直链：
`https://github.com/dkx8x4m5sb-art/flyme2themoon_iOS_arm64/releases/download/build/FlyMe2theMoon-v1.7.0-arm64-unsigned.ipa`

## 5. 产物校验（实测）

- 结构：`Payload/FlyMe2theMoon.app`，无 `_CodeSignature`，主程序无 `LC_CODE_SIGNATURE`（完全未签名）。
- 架构：主程序 magic `0xfeedfacf`、`cputype 16777228`（ARM64），`lipo -info` 输出 `architecture: arm64`。
- 元信息：`CFBundleIdentifier=com.mihoyo.flyme2themoon.arm64`、`CFBundleShortVersionString=1.7.0`、
  `CFBundleVersion=6`、`MinimumOSVersion=16.0`、`CFBundleExecutable=FlyMe2theMoon`、
  `UIRequiredDeviceCapabilities=[arm64]`。
- 资源：`Resources/{data,atlas,audio,art,fonts}`，60 个 Lua、70 个 wav、19 张图集页、
  `atlas/frames.json` 约 102 KB。
- 体积：解包后 app 约 38.5 MB，IPA 约 35 MB。

## 6. 验证边界与已知差距

- **已证明**：工程可从零生成、可编译、可打包；产物结构、架构、未签名状态、资源齐全性均经脚本断言。
- **未证明**：真机 / 模拟器上的可运行性。GitHub macOS 运行器上 `simctl install` 会报
  `IXErrorDomain code=13 Missing bundle ID`，而 app 的 `Info.plist` 中 `CFBundleIdentifier` 正常、
  `CFBundleSupportedPlatforms=[iPhoneSimulator]` 正常，属于运行器/模拟器侧问题；`ci/smoke.sh`
  保留为本地脚本（`SIM_SMOKE=1 bash ci/smoke.sh`），默认不参与流水线。
- 手感（重力、初速、阻尼）来自设计分辨率下的离线校准，没有真机对照，统一放在 `FMLevelScene.Tuning`。
- 无 BGM；教程图用一行文字提示代替；`Rep_rd_*.txt` 回放未解析，演示段按“2.2 秒后到达月亮”处理。

## 7. 复现

```sh
python3 ci/prepare_assets.py <解包的 .app> Resources
python3 ci/verify_data.py Resources
lua Tools/lua_sim.lua Resources/data/lua          # 需系统 Lua 5.1
SIM_SMOKE=1 bash ci/smoke.sh                      # 可选，需 macOS + Xcode
```

CI 上直接 push，无需任何本地环境。

## 版权

素材、关卡数据与脚本来自原版《Fly Me 2 the Moon》，版权归 miHoYo 所有；本仓库只做 64 位兼容性重建。
