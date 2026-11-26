//
//  FMGameData.swift
//  资源装载：JSON、图集切片、音效清单。图集切片用 CGImage 裁剪，
//  所以帧矩形就是 prepare_assets.py 写出的像素坐标，不涉及 UV 上下翻转。
//

import CoreGraphics
import Foundation
import SpriteKit
import UIKit

final class FMGameData {
    static let shared = FMGameData()

    let levels: [String: FMLevel]
    let atlas: FMAtlas
    let dialogs: [String: FMDialogLine]
    let role: FMRoleParams
    let scores: [String: Double]
    let dependency: [String: [Int]]
    let edges: [Int: [CGPoint]]
    let sounds: Set<String>
    let faces: Set<String>
    let tutorialReplays: Set<String>

    private let root: URL
    private var pageImages: [String: UIImage] = [:]
    private var textures: [String: SKTexture] = [:]

    private init() {
        let bundleRoot = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let base = bundleRoot.appendingPathComponent("Resources", isDirectory: true)
        root = base

        func decode<T: Decodable>(_ relative: String, _ type: T.Type) -> T {
            let url = base.appendingPathComponent(relative)
            guard let data = try? Data(contentsOf: url) else {
                NSLog("[FM] 缺资源 %@", relative)
                fatalError("缺少资源: \(relative)")
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                NSLog("[FM] 解析 %@ 失败 %@", relative, String(describing: error))
                fatalError("解析失败: \(relative)")
            }
        }

        levels = decode("data/levels.json", [String: FMLevel].self)
        atlas = decode("atlas/frames.json", FMAtlas.self)
        role = decode("data/role.json", FMRoleParams.self)
        scores = decode("data/score.json", [String: [String: Double]].self)["svrs"] ?? [:]
        dependency = decode("data/dependency.json", [String: [Int]].self)

        let rawEdges = decode("data/edges.json", [String: [[Double]]].self)
        var polygons: [Int: [CGPoint]] = [:]
        for (key, points) in rawEdges {
            guard let id = Int(key), points.count >= 3 else { continue }
            polygons[id] = points.compactMap { pair in
                pair.count >= 2 ? CGPoint(x: pair[0], y: pair[1]) : nil
            }
        }
        edges = polygons

        let rawDialogs = decode("data/dialogs.json", [String: [FMDialogLine]].self)
        var index: [String: FMDialogLine] = [:]
        for (_, list) in rawDialogs {
            for line in list where !line.k.isEmpty { index[line.k] = line }
        }
        dialogs = index

        let audioDir = base.appendingPathComponent("audio", isDirectory: true)
        let audioFiles = (try? FileManager.default.contentsOfDirectory(atPath: audioDir.path)) ?? []
        sounds = Set(audioFiles.filter { $0.hasSuffix(".wav") }.map { ($0 as NSString).deletingPathExtension })

        let artDir = base.appendingPathComponent("art", isDirectory: true)
        let artFiles = (try? FileManager.default.contentsOfDirectory(atPath: artDir.path)) ?? []
        faces = Set(artFiles.filter { $0.hasPrefix("face") && $0.hasSuffix(".png") }
            .map { ($0 as NSString).deletingPathExtension })

        let luaDir = base.appendingPathComponent("data/lua", isDirectory: true)
        let luaFiles = (try? FileManager.default.contentsOfDirectory(atPath: luaDir.path)) ?? []
        tutorialReplays = Set(luaFiles.filter { $0.hasSuffix(".txt") }.map { ($0 as NSString).deletingPathExtension })
    }

    // MARK: - 路径

    func url(_ relative: String) -> URL { root.appendingPathComponent(relative) }

    func faceImage(_ name: String) -> UIImage? {
        guard faces.contains(name) else { return nil }
        return UIImage(contentsOfFile: url("art/\(name).png").path)
    }

    func level(_ id: Int) -> FMLevel? { levels[String(id)] }

    var levelIDs: [Int] { levels.keys.compactMap { Int($0) }.sorted() }

    // MARK: - 图集

    private func pageImage(_ sheet: String, _ index: Int) -> UIImage? {
        guard let definition = atlas.sheets[sheet], index >= 0, index < definition.pages.count else { return nil }
        let key = "\(sheet)#\(index)"
        if let cached = pageImages[key] { return cached }
        let page = definition.pages[index]
        let url = root.appendingPathComponent("atlas/\(page.image)")
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        pageImages[key] = image
        return image
    }

    func frame(_ name: String, sheet: String) -> FMAtlas.Sheet.Frame? {
        atlas.sheets[sheet]?.frames[name]
    }

    func texture(_ name: String, sheet: String) -> SKTexture? {
        let key = "\(sheet)|\(name)"
        if let cached = textures[key] { return cached }
        guard let definition = atlas.sheets[sheet],
              let frame = definition.frames[name],
              frame.w > 0, frame.h > 0,
              let image = pageImage(sheet, frame.p),
              let cgImage = image.cgImage,
              let cropped = cgImage.cropping(to: CGRect(x: frame.x, y: frame.y, width: frame.w, height: frame.h))
        else { return nil }
        let texture = SKTexture(cgImage: cropped)
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }

    /// 名字前缀匹配：精确名优先，其次 `<base>/...` 的序列（字典序）
    func animationFrames(_ base: String, sheet: String) -> [String] {
        guard let definition = atlas.sheets[sheet] else { return [] }
        if definition.frames[base] != nil { return [base] }
        let prefix = base.hasSuffix(".png") ? String(base.dropLast(4)) : base
        return definition.frames.keys.filter { $0 == prefix || $0.hasPrefix(prefix + "/") }.sorted()
    }

    func sheet(for layer: String, suite: Int) -> String? {
        switch layer {
        case "Background", "Farground": return "FargroundsS\(suite)-hd"
        case "Texture", "Foreground": return "TextureS\(suite)-hd"
        case "Item", "DynamicObject": return "DynamicObjectsLite-hd"
        default: return nil
        }
    }

    func frameBase(for layer: String, seq: Int) -> String? {
        switch layer {
        case "Background": return String(format: "Background_%03d.png", seq)
        case "Farground": return String(format: "Farground_%03d.png", seq)
        case "Texture": return String(format: "Texture_%03d.png", seq)
        case "Foreground": return String(format: "Foreground_%03d.png", seq)
        case "Item": return String(format: "Item_%03d", seq)
        case "DynamicObject": return String(format: "DynamicObject_%03d", seq)
        default: return nil
        }
    }

    // MARK: - 文本 / 存档

    func dialog(_ key: String) -> FMDialogLine? { dialogs[key] }

    func scriptText(level: Int) -> String? {
        let url = root.appendingPathComponent(String(format: "data/lua/Level_%03d.lua", level))
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func starThreshold(_ level: Int) -> Double { scores[String(level)] ?? 0 }
}
