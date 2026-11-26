//
//  FMLevelScene.swift
//  一关的 SpriteKit 场景：图层次序、精灵图集、弹射物理、圆形角色、相机跟随、
//  以及把 Lua 关卡脚本接到游戏事件上。
//
//  坐标：关卡数据用的是 cocos2d 的“左下原点、y 向上”坐标系，和 SpriteKit 一致，
//  所以 x/y/rot 直接使用；精灵以 sourceSize 的中心为锚点，裁剪帧再按 offset 摆。
//

import CoreGraphics
import SpriteKit
import UIKit

struct FMLevelResult {
    let levelID: Int
    let time: Double
    let stars: Int
    let isLastLevel: Bool
}

protocol FMLevelSceneDelegate: AnyObject {
    func levelScene(_ scene: FMLevelScene, showDialog key: String, face: String, minTime: Double, autoClose: Bool)
    func levelScene(_ scene: FMLevelScene, time: Double, failures: Int)
    func levelScene(_ scene: FMLevelScene, finished result: FMLevelResult)
    func levelScene(_ scene: FMLevelScene, showTutorial index: Int)
    func levelScene(_ scene: FMLevelScene, skipEnabled enabled: Bool)
}

final class FMLevelScene: SKScene {

    // MARK: - 手感参数
    // 参考 role.json：pushAngleRange=50°、pushDistance1/2 的拖拽区间。
    // 速度/重力的单位换算原版没有留下可验证的数值，这里用 960×1440 设计分辨率
    // 校准成“一次满弓大约飞一屏高”。

    private enum Tuning {
        static let gravity: CGFloat = -900
        static let launchSpeedMin: CGFloat = 520
        static let launchSpeedMax: CGFloat = 980
        static let dragMin: CGFloat = 45
        static let dragMax: CGFloat = 260
        static let maxHorizontal: CGFloat = 860
        static let airDrag: CGFloat = 0.45      // 每秒
        static let groundFriction: CGFloat = 0.82
        static let playerRadius: CGFloat = 30
        static let areaRadius: CGFloat = 64
    }

    // MARK: - 状态

    weak var levelDelegate: FMLevelSceneDelegate?

    let levelID: Int
    let isRestart: Bool

    private let level: FMLevel
    private let world = SKNode()
    private let cameraNode = SKCameraNode()
    private let aimNode = SKShapeNode()

    private var player = SKNode()
    private var playerSprite = SKSpriteNode()
    private var poseName = ""

    private var velocity = CGVector.zero
    private var onGround = false
    private var dead = false
    private var paused = false
    private var inputEnabled = true
    private var idleEnabled = true
    private var completed = false
    private var moonReached = false
    private var replaying = false

    private var levelTime: Double = 0
    private var failures = 0
    private var lastHUDTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    private var charging = false
    private var chargeStart = CGPoint.zero
    private var chargeCurrent = CGPoint.zero

    private var followRole = true
    private var fixedCamera: CGPoint?
    private var cameraCenter = CGPoint.zero

    private var polygons: [[CGPoint]] = []
    private var areas: [CGPoint] = []

    private var lua: FMLuaHost?
    private var dialogPending = false
    private var skipEnabled = false

    // MARK: - 初始化

    init(levelID: Int, isRestart: Bool) {
        self.levelID = levelID
        self.isRestart = isRestart
        self.level = FMGameData.shared.level(levelID) ?? .fallback
        super.init(size: CGSize(width: 960, height: 1440))
        self.anchorPoint = .zero
        self.scaleMode = .aspectFit
        self.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 构建

    override func didMove(to view: SKView) {
        buildWorld()
        buildPlayer()
        startScript()
    }

    private func buildWorld() {
        addChild(world)
        cameraNode.position = level.bornPoint
        addChild(cameraNode)
        camera = cameraNode

        // 天空：原版 Background seq=1 是代码画的，素材包里没有这张图
        let sky = SKSpriteNode(texture: skyTexture(suite: level.suite))
        sky.anchorPoint = .zero
        sky.size = CGSize(width: CGFloat(level.w), height: CGFloat(level.h))
        sky.position = .zero
        sky.zPosition = -3000
        world.addChild(sky)

        aimNode.strokeColor = UIColor(white: 1, alpha: 0.6)
        aimNode.lineWidth = 6
        aimNode.zPosition = 9000
        aimNode.isHidden = true
        world.addChild(aimNode)

        for layer in level.layers {
            switch layer.name {
            case "StaticObject":
                collectPolygons(layer)
            case "Area":
                areas = layer.objs.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            case "Background", "Farground":
                buildLayer(layer, parallax: true)
            default:
                buildLayer(layer, parallax: false)
            }
        }
    }

    private func skyTexture(suite: Int) -> SKTexture {
        let size = CGSize(width: 64, height: 256)
        let colors: [(UIColor, UIColor)] = [
            (UIColor(red: 0.05, green: 0.08, blue: 0.20, alpha: 1), UIColor(red: 0.10, green: 0.35, blue: 0.55, alpha: 1)),
            (UIColor(red: 0.12, green: 0.05, blue: 0.20, alpha: 1), UIColor(red: 0.45, green: 0.20, blue: 0.35, alpha: 1)),
            (UIColor(red: 0.20, green: 0.08, blue: 0.10, alpha: 1), UIColor(red: 0.85, green: 0.45, blue: 0.20, alpha: 1)),
            (UIColor(red: 0.03, green: 0.12, blue: 0.12, alpha: 1), UIColor(red: 0.10, green: 0.45, blue: 0.40, alpha: 1)),
        ]
        let pair = colors[max(0, min(colors.count - 1, suite - 1))]
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: space,
                                      colors: [pair.0.cgColor, pair.1.cgColor] as CFArray,
                                      locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height),
                                  end: CGPoint(x: 0, y: 0), options: [])
        }
        return SKTexture(image: image)
    }

    private func buildLayer(_ layer: FMLevel.Layer, parallax: Bool) {
        guard let sheet = FMGameData.shared.sheet(for: layer.name, suite: level.suite) else { return }
        let container = SKNode()
        container.zPosition = CGFloat(layer.type) * 1000
        if parallax, layer.w > 0, layer.h > 0 {
            let scale = max(level.w / layer.w, level.h / layer.h)
            container.setScale(CGFloat(scale))
        }
        world.addChild(container)

        for obj in layer.objs {
            // Background seq=1：程序天空，跳过
            if layer.name == "Background", obj.seq == 1 { continue }
            guard let base = FMGameData.shared.frameBase(for: layer.name, seq: obj.seq) else { continue }
            let frames = FMGameData.shared.animationFrames(base, sheet: sheet)
            guard let holder = makeSpriteNode(frames: frames, sheet: sheet) else { continue }
            holder.position = CGPoint(x: CGFloat(obj.x), y: CGFloat(obj.y))
            holder.zPosition = CGFloat(obj.d)
            holder.zRotation = CGFloat(obj.rot) * .pi / 180
            container.addChild(holder)
            if frames.count > 1 {
                animate(holder, frames: frames, sheet: sheet)
            }
        }
    }

    /// 帧序列 → 显示节点。外层按 sourceSize 定位，内层贴裁剪帧 + offset。
    private func makeSpriteNode(frames: [String], sheet: String) -> SKNode? {
        guard let firstName = frames.first,
              let first = FMGameData.shared.frame(firstName, sheet: sheet),
              let texture = FMGameData.shared.texture(firstName, sheet: sheet) else { return nil }
        let holder = SKNode()
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: CGFloat(first.w), height: CGFloat(first.h))
        sprite.position = CGPoint(x: CGFloat(first.ox), y: CGFloat(first.oy))
        sprite.name = "sprite"
        holder.addChild(sprite)
        return holder
    }

    private func animate(_ holder: SKNode, frames: [String], sheet: String) {
        guard let sprite = holder.childNode(withName: "sprite") as? SKSpriteNode else { return }
        var actions: [SKAction] = []
        for name in frames {
            guard let frame = FMGameData.shared.frame(name, sheet: sheet),
                  let texture = FMGameData.shared.texture(name, sheet: sheet) else { continue }
            let size = CGSize(width: CGFloat(frame.w), height: CGFloat(frame.h))
            let offset = CGPoint(x: CGFloat(frame.ox), y: CGFloat(frame.oy))
            actions.append(SKAction.group([
                SKAction.setTexture(texture, resize: false),
                SKAction.run { sprite.size = size; sprite.position = offset },
            ]))
            actions.append(SKAction.wait(forDuration: 1.0 / 24.0))
        }
        guard !actions.isEmpty else { return }
        sprite.run(SKAction.repeatForever(SKAction.sequence(actions)), withKey: "animation")
    }

    private func collectPolygons(_ layer: FMLevel.Layer) {
        let table = FMGameData.shared.edges
        for obj in layer.objs {
            if let polygon = table[obj.seq] { polygons.append(polygon) }
        }
    }

    private func buildPlayer() {
        player = SKNode()
        playerSprite = SKSpriteNode()
        playerSprite.name = "sprite"
        player.addChild(playerSprite)
        player.position = level.bornPoint
        player.zPosition = 500
        world.addChild(player)
        cameraCenter = level.bornPoint
        cameraNode.position = cameraCenter
        playPose("charIdle", loop: true)
    }

    // MARK: - 脚本

    private func startScript() {
        FMAudioEngine.shared.prepare()
        guard let text = FMGameData.shared.scriptText(level: levelID) else {
            NSLog("[FM] 缺关卡脚本 %d", levelID)
            return
        }
        let host = FMLuaHost(level: levelID, script: text)
        host.delegate = self
        lua = host
        host.start()
    }

    // MARK: - 帧循环

    override func update(_ currentTime: TimeInterval) {
        let raw = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        let dt = min(CGFloat(1.0 / 20.0), max(CGFloat(1.0 / 240.0), CGFloat(raw)))

        lua?.tick(Double(dt))
        pollLuaDialog()

        if !completed {
            if !paused {
                if !dead { levelTime += Double(dt) }
                step(dt: dt)
            }
            updateCamera(dt: dt)
        }

        if currentTime - lastHUDTime > 0.1 {
            lastHUDTime = currentTime
            levelDelegate?.levelScene(self, time: levelTime, failures: failures)
        }
    }

    private func pollLuaDialog() {
        guard let host = lua, !dialogPending, host.waitKind == .dialog else { return }
        dialogPending = true
        let key = host.waitDialogKey ?? ""
        let fallbackFace = host.waitFace ?? ""
        let line = FMGameData.shared.dialog(key)
        let face = (line?.f.isEmpty == false) ? (line?.f ?? fallbackFace) : fallbackFace
        levelDelegate?.levelScene(self, showDialog: key, face: face,
                                  minTime: host.waitMinTime, autoClose: host.waitAutoClose)
    }

    func resolveDialog(skipped: Bool) {
        dialogPending = false
        lua?.resolveDialogSkipped(skipped)
    }

    // MARK: - 物理

    private func step(dt: CGFloat) {
        guard !charging, !dead else { return }

        velocity.dy += Tuning.gravity * dt
        if onGround {
            velocity.dx *= CGFloat(pow(Double(Tuning.groundFriction), Double(dt) * 60))
        } else {
            velocity.dx *= max(0, 1 - Tuning.airDrag * dt)
        }
        velocity.dx = min(Tuning.maxHorizontal, max(-Tuning.maxHorizontal, velocity.dx))

        var next = CGPoint(x: player.position.x + velocity.dx * dt,
                           y: player.position.y + velocity.dy * dt)
        var landed = false

        for polygon in polygons {
            if let hit = resolveCircle(center: next, radius: Tuning.playerRadius, polygon: polygon) {
                next = hit.point
                let normal = hit.normal
                if normal.dy > 0.45 && velocity.dy <= 0 {
                    velocity.dy = 0
                    landed = true
                } else {
                    let dot = velocity.dx * normal.dx + velocity.dy * normal.dy
                    if dot < 0 {
                        velocity.dx -= normal.dx * dot
                        velocity.dy -= normal.dy * dot
                    }
                }
            }
        }

        onGround = landed
        player.position = next

        if next.y < -180 || next.x < -260 || next.x > CGFloat(level.w) + 260 {
            die()
            return
        }

        if !moonReached, next.y >= CGFloat(level.h) - 24 {
            roleReachedMoon()
            return
        }
        for area in areas {
            if hypot(area.x - next.x, area.y - next.y) < Tuning.areaRadius {
                roleReachedMoon()
                return
            }
        }

        updatePose()
    }

    private func updatePose() {
        if dead { return }
        var target = "charIdle"
        if !onGround {
            if velocity.dy > 140 { target = "charUp" }
            else if velocity.dy < -180 { target = "charDown" }
            else if abs(velocity.dx) > 200 { target = velocity.dx > 0 ? "charRight" : "charLeft" }
            else { target = "charFree" }
        } else if abs(velocity.dx) > 200 {
            target = velocity.dx > 0 ? "charRight" : "charLeft"
        }
        if target != poseName {
            playPose(target, loop: true)
        }
    }

    private func playPose(_ base: String, loop: Bool) {
        let sheet = "CharActions-hd"
        let frames = FMGameData.shared.animationFrames(base + "/001.png", sheet: sheet)
        guard let firstName = frames.first,
              let frame = FMGameData.shared.frame(firstName, sheet: sheet),
              let texture = FMGameData.shared.texture(firstName, sheet: sheet) else { return }
        poseName = base
        playerSprite.texture = texture
        playerSprite.size = CGSize(width: CGFloat(frame.sw), height: CGFloat(frame.sh))
        playerSprite.position = .zero
        playerSprite.removeAction(forKey: "pose")

        var actions: [SKAction] = []
        for name in frames {
            guard let f = FMGameData.shared.frame(name, sheet: sheet),
                  let tex = FMGameData.shared.texture(name, sheet: sheet) else { continue }
            let size = CGSize(width: CGFloat(f.sw), height: CGFloat(f.sh))
            actions.append(SKAction.group([
                SKAction.setTexture(tex, resize: false),
                SKAction.run { self.playerSprite.size = size },
            ]))
            actions.append(SKAction.wait(forDuration: 1.0 / 20.0))
        }
        guard !actions.isEmpty else { return }
        let sequence = loop ? SKAction.repeatForever(SKAction.sequence(actions)) : SKAction.sequence(actions)
        playerSprite.run(sequence, withKey: "pose")
    }

    private func die() {
        guard !dead else { return }
        dead = true
        failures += 1
        velocity = .zero
        playPose("charDeath", loop: false)
        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                self?.onRoleDied()
            },
        ]))
    }

    private func onRoleDied() {
        guard !completed else { return }
        lua?.callGlobal("onRoleDied")
    }

    private func roleReachedMoon() {
        guard !moonReached, !completed, !dead else { return }
        moonReached = true
        lua?.callGlobal("onRoleReachedMoon")
    }

    private func resetRole() {
        dead = false
        moonReached = false
        velocity = .zero
        onGround = false
        player.position = level.bornPoint
        playPose("charIdle", loop: true)
    }

    // MARK: - 相机

    private func updateCamera(dt: CGFloat) {
        var target = cameraCenter
        if let fixed = fixedCamera {
            target = fixed
        } else if followRole {
            target = CGPoint(x: player.position.x, y: player.position.y + 180)
        }
        let halfW = size.width / 2
        let halfH = size.height / 2
        if CGFloat(level.w) > size.width {
            target.x = min(max(target.x, halfW), CGFloat(level.w) - halfW)
        } else {
            target.x = CGFloat(level.w) / 2
        }
        if CGFloat(level.h) > size.height {
            target.y = min(max(target.y, halfH), CGFloat(level.h) - halfH)
        } else {
            target.y = CGFloat(level.h) / 2
        }
        let t = min(1, max(0.02, dt * 8))
        cameraCenter.x += (target.x - cameraCenter.x) * t
        cameraCenter.y += (target.y - cameraCenter.y) * t
        cameraNode.position = cameraCenter
    }

    // MARK: - 输入

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, !dead, !completed, !paused, touches.count == 1, let touch = touches.first else { return }
        charging = true
        chargeStart = touch.location(in: self)
        chargeCurrent = chargeStart
        updateAim()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard charging, let touch = touches.first else { return }
        chargeCurrent = touch.location(in: self)
        updateAim()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard charging else { return }
        charging = false
        aimNode.isHidden = true
        launch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        charging = false
        aimNode.isHidden = true
    }

    private var aimVector: CGVector {
        CGVector(dx: chargeStart.x - chargeCurrent.x, dy: chargeStart.y - chargeCurrent.y)
    }

    private func updateAim() {
        let vector = aimVector
        let length = min(Tuning.dragMax, hypot(vector.dx, vector.dy))
        guard length > 6 else {
            aimNode.isHidden = true
            return
        }
        let angle = clampedAngle(dx: vector.dx, dy: vector.dy)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: chargeStart.x, y: chargeStart.y))
        path.addLine(to: CGPoint(x: chargeStart.x + sin(angle) * length, y: chargeStart.y + cos(angle) * length))
        aimNode.path = path
        aimNode.isHidden = false
    }

    private func clampedAngle(dx: CGFloat, dy: CGFloat) -> CGFloat {
        let range = CGFloat(FMGameData.shared.role.pushAngleRange) * .pi / 180
        if dy <= 0 { return dx >= 0 ? range : -range }
        let angle = atan2(dx, dy)
        return min(range, max(-range, angle))
    }

    private func launch() {
        let vector = aimVector
        let rawLength = hypot(vector.dx, vector.dy)
        guard rawLength > Tuning.dragMin else { return }
        let length = min(Tuning.dragMax, rawLength)
        let angle = clampedAngle(dx: vector.dx, dy: vector.dy)
        let ratio = (length - Tuning.dragMin) / (Tuning.dragMax - Tuning.dragMin)
        let speed = Tuning.launchSpeedMin + (Tuning.launchSpeedMax - Tuning.launchSpeedMin) * ratio
        velocity = CGVector(dx: sin(angle) * speed, dy: cos(angle) * speed)
        onGround = false
        playPose("charUp", loop: true)
    }

    // MARK: - 结束

    private func finishSuccess() {
        guard !completed else { return }
        completed = true
        velocity = .zero
        let threshold = FMGameData.shared.starThreshold(levelID)
        let stars: Int
        if threshold <= 0 { stars = 3 }
        else if levelTime <= threshold { stars = 3 }
        else if levelTime <= threshold * 1.8 { stars = 2 }
        else { stars = 1 }
        FMProgressStore.shared.markPassed(level: levelID, time: levelTime, stars: stars)
        let ids = FMGameData.shared.levelIDs
        let isLast = levelID == (ids.last ?? levelID)
        levelDelegate?.levelScene(self, finished: FMLevelResult(levelID: levelID, time: levelTime, stars: stars, isLastLevel: isLast))
    }

    // MARK: - 碰撞工具

    private struct Hit {
        let point: CGPoint
        let normal: CGVector
    }

    private func resolveCircle(center: CGPoint, radius: CGFloat, polygon: [CGPoint]) -> Hit? {
        guard polygon.count >= 3 else { return nil }
        let inside = pointInPolygon(center, polygon)
        if !inside && distanceToPolygon(center, polygon) > radius { return nil }

        var best: Hit?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for index in 0..<polygon.count {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            let (closest, distance) = closestPointOnSegment(center, a, b)
            if distance < bestDistance {
                bestDistance = distance
                var normal = CGVector(dx: center.x - closest.x, dy: center.y - closest.y)
                let length = max(0.0001, hypot(normal.dx, normal.dy))
                normal = CGVector(dx: normal.dx / length, dy: normal.dy / length)
                if inside {
                    normal = CGVector(dx: -normal.dx, dy: -normal.dy)
                    best = Hit(point: CGPoint(x: closest.x + normal.dx * radius, y: closest.y + normal.dy * radius), normal: normal)
                } else {
                    best = Hit(point: CGPoint(x: center.x + normal.dx * (radius - distance),
                                              y: center.y + normal.dy * (radius - distance)), normal: normal)
                }
            }
        }
        return best
    }

    private func pointInPolygon(_ p: CGPoint, _ polygon: [CGPoint]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let a = polygon[i]
            let b = polygon[j]
            if (a.y > p.y) != (b.y > p.y),
               p.x < (b.x - a.x) * (p.y - a.y) / max(0.0001, b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    private func closestPointOnSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> (CGPoint, CGFloat) {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let lengthSquared = abx * abx + aby * aby
        if lengthSquared < 0.0001 { return (a, hypot(p.x - a.x, p.y - a.y)) }
        var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSquared
        t = min(1, max(0, t))
        let closest = CGPoint(x: a.x + abx * t, y: a.y + aby * t)
        return (closest, hypot(p.x - closest.x, p.y - closest.y))
    }

    private func distanceToPolygon(_ p: CGPoint, _ polygon: [CGPoint]) -> CGFloat {
        var best = CGFloat.greatestFiniteMagnitude
        for index in 0..<polygon.count {
            let (_, distance) = closestPointOnSegment(p, polygon[index], polygon[(index + 1) % polygon.count])
            best = min(best, distance)
        }
        return best
    }
}

// MARK: - Lua 原生回调

extension FMLevelScene: FMLuaHostDelegate {

    func luaPlaySound(_ soundId: String) {
        FMAudioEngine.shared.play(soundId)
    }

    func luaCameraGoto(_ point: CGPoint) {
        fixedCamera = point
        followRole = false
    }

    func luaCameraToRole() {
        fixedCamera = nil
        followRole = true
    }

    func luaSetFollowRoleMode(_ on: Bool) {
        if on {
            followRole = true
            fixedCamera = nil
        } else {
            followRole = false
        }
    }

    func luaSetUserInputEnabled(_ on: Bool) {
        inputEnabled = on
        if !on { charging = false; aimNode.isHidden = true }
    }

    func luaSetLogicPaused(_ paused: Bool) {
        self.paused = paused
    }

    func luaRestartTiming() {
        levelTime = 0
    }

    func luaIsRestart() -> Bool {
        isRestart
    }

    func luaSuccess() {
        finishSuccess()
    }

    func luaShowTutorialDiagram(_ index: Int) {
        levelDelegate?.levelScene(self, showTutorial: index)
    }

    func luaSetIdleActionEnabled(_ on: Bool) {
        idleEnabled = on
    }

    func luaRoleLoadState() {
        resetRole()
    }

    func luaRoleLookLeftRight() {
        guard idleEnabled, !dead else { return }
        playPose("charLookLeftRight", loop: false)
        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.2),
            SKAction.run { [weak self] in
                guard let self, !self.dead else { return }
                self.playPose("charIdle", loop: true)
            },
        ]))
    }

    func luaGlobalGetBool(_ key: String) -> Bool {
        FMProgressStore.shared.flag(key)
    }

    func luaGlobalSetBool(_ key: String) {
        FMProgressStore.shared.setFlag(key)
    }

    func luaIsLevelPassed(_ level: Int) -> Bool {
        FMProgressStore.shared.isPassed(level)
    }

    func luaSetReplayMode() {
        replaying = true
    }

    func luaSetPlayMode() {
        replaying = false
    }

    func luaLoadTutorialReplay(_ name: String) {
        // 原版会回放录制输入；这里把演示段简化为“角色直接到达月亮”。
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.roleReachedMoon()
        }
    }

    func luaReplaySkipNonControlFrames() {}

    func luaReplayPause() {}

    func luaSetSkipEnabled(_ on: Bool) {
        skipEnabled = on
        levelDelegate?.levelScene(self, skipEnabled: on)
    }
}
