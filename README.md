# Fly Me 2 the Moon · arm64 重制

原版是 2011 年的 32 位 iOS 游戏（armv7、iOS 3.2 时代），在 iOS 11 之后已经无法启动。
这个仓库把原版的关卡数据、图集、音效和 Lua 关卡脚本搬到 64 位环境里，用
**SwiftUI + SpriteKit + Lua 5.1.5** 重新实现运行时，由 GitHub Actions 直接产出
**未签名 arm64 IPA**。

## 怎么出包

仓库本身不带素材（原版图集 30 MB，没必要进 git）。工作流 `Build ARM64 IPA` 会：

1. 从 release `assets` 下载原版素材包 `FlyMe2theMoon_v1.7.0_unsigned.ipa`，解包取 `Payload/*.app`；
2. `ci/prepare_assets.py` 把 `data/`、`audio/`、`art/`、`fonts/`、图集页铺进 `Resources/`，
   并把 atlas.json 里 71 个 **rotated 帧**转正后追加到图集补页，生成 `atlas/frames.json`；
3. `ci/verify_data.py` 断言 60 关的 2.2 万个贴图对象、碰撞多边形、Lua 脚本、音效全部对得上；
4. `xcodegen` 生成工程，`xcodebuild` 以 arm64 编 Release；
5. 逐个检查 app 内所有 Mach-O 都是 arm64，再打包成 `FlyMe2theMoon-unsigned.ipa`，
   挂到 release `build` 并上传 artifact。

失败时构建日志会推到 `ci-logs` 分支的 `build-log.md`。

## 目录

```
App/                Swift 源码
  Data/             模型、资源装载（CGImage 直裁图集，不做 UV 翻转）
  Game/             FMLevelScene（图层/精灵/弹射物理/相机/事件）
  Lua/              FMLuaHost（Objective-C 的 Lua 5.1 协程宿主）
  UI/               菜单、选关、关卡 HUD、对话框、结算、设置
  Audio/            音效缓存播放
Sources/lua/        Lua 5.1.5（去掉 io/os/package，构建时下载）
ci/                 prepare_assets.py / verify_data.py / pipeline.sh / smoke.sh
Tools/lua_sim.lua   本地跑一遍 60 个关卡脚本，检查 prelude 接口
project.yml         xcodegen 工程描述
```

## 实现要点

- **坐标与图层**：关卡数据是 cocos2d 坐标系（左下原点、y 向上），与 SpriteKit 一致；
  图层按 `type` 排序（Background→Farground→StaticObject→Texture→DynamicObject→Item→Foreground），
  层内按 `d` 再排。
- **图集**：`atlas.json` 是 9 元组 `x,y,w,h,rotated,offX,offY,srcW,srcH`。未旋转帧直接按原页矩形
  裁像素；旋转帧离线转正放进补页，运行时不需要处理旋转。绘制时外层节点按 `srcW×srcH` 定位，
  内层贴裁剪帧并按 `offset` 偏移。
- **物理**：角色是半径 30px 的圆，StaticObject 的 `seq` 查 `edges.json` 的多边形，圆-多边形
  碰撞后按法线消去速度分量；弹射方向限制在竖直向上左右各 50°（`pushAngleRange`），
  力度由拖拽长度在 `pushDistance1/2` 区间映射。
- **脚本**：`dialog.show` / `script.delay` 用 `coroutine.yield` 交回原生，`FMLuaHost` 每帧 tick；
  `onRoleReachedMoon` / `onRoleDied` 作为全局函数回调。
- **存档**：通关、星级、`global.setBool` 剧情标记写 UserDefaults；解锁关系读 `dependency.json`。

## 已知差距

- 1.1 原版的 6 首 `.caf` BGM 不在素材包里，目前没有背景音乐（音效 70 个都在）。
- 教程图（`game.showTutorialDiagram`）没有素材，用一行操作提示代替。
- 演示回放（`Rep_rd_*.txt`）没有解析，演示段按“2.2 秒后到达月亮”处理。
- 星级阈值来自 `score.json` 的 `svrs`（按通关时间判定），原版是按收集星星计分。
- 手感参数（重力/初速/阻尼）是按设计分辨率离线校准的，没有真机对照，可以在
  `FMLevelScene.Tuning` 里调。

## 验证状态

- CI 会实际跑一遍：装依赖 → 下载 Lua 5.1.5 → 解原版包 → 重建资源并自检 →
  xcodegen → `xcodebuild`（Release/iphoneos）→ 全量 Mach-O arm64 校验 → 打 IPA →
  上传 release `build` 与 artifact。最新一次成功构建的产物：
  `https://github.com/dkx8x4m5sb-art/flyme2themoon_iOS_arm64/releases/download/build/FlyMe2theMoon-v1.7.0-arm64-unsigned.ipa`
- 产物结构为 `Payload/FlyMe2theMoon.app`，`CFBundleIdentifier=com.mihoyo.flyme2themoon.arm64`，
  `MinimumOSVersion=16.0`，主程序 `CPU_TYPE_ARM64`；`Resources/` 内含 `data/`、`atlas/`、
  `audio/`、`art/`、`fonts/`。
- 模拟器冒烟脚本 `ci/smoke.sh` 用于本地验证“能装能启动”：`SIM_SMOKE=1 bash ci/smoke.sh`。
  默认不跑——GitHub macOS 运行器上 `simctl install` 会报 `IXErrorDomain code=13 Missing bundle ID`
  （app 的 `Info.plist` 里 `CFBundleIdentifier` 是正常的，属于运行器/模拟器侧问题），
  因此流水线不把它当作阻断条件。
- 尚未做真机运行验证与手感对照，见“已知差距”。

## 本地构建

```sh
python3 ci/prepare_assets.py <解包的 .app> Resources
python3 ci/verify_data.py Resources
lua Tools/lua_sim.lua Resources/data/lua     # 可选：Lua 5.1
brew install xcodegen && xcodegen generate
xcodebuild -project FlyMe2theMoon.xcodeproj -scheme FlyMe2theMoon \
  -configuration Release -sdk iphoneos ARCHS=arm64 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## 版权

素材、关卡数据与脚本来自原版《Fly Me 2 the Moon》，版权归 miHoYo 所有。
本仓库只做 64 位兼容性重建与本机自用，不对外分发。
