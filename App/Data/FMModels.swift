//
//  FMModels.swift
//  Resources/data/*.json 与 atlas/frames.json 对应的数据结构。
//

import CoreGraphics
import Foundation

struct FMLevel: Decodable {
    struct Layer: Decodable {
        let name: String
        let type: Int
        let w: Double
        let h: Double
        let objs: [FMObject]
    }

    struct FMObject: Decodable {
        let x: Double
        let y: Double
        let seq: Int
        let d: Int
        let rot: Double
        let flip: Bool
    }

    let id: Int
    let w: Double
    let h: Double
    let born: [Double]
    let suite: Int
    let layers: [Layer]

    static let fallback = FMLevel(id: 1, w: 960, h: 1440, born: [480, 300], suite: 1, layers: [])

    var bornPoint: CGPoint {
        CGPoint(x: born.count > 0 ? born[0] : w / 2, y: born.count > 1 ? born[1] : h / 2)
    }

    func layer(_ name: String) -> Layer? { layers.first { $0.name == name } }
}

struct FMAtlas: Decodable {
    struct Sheet: Decodable {
        struct Page: Decodable {
            let image: String
            let w: Int
            let h: Int
        }

        struct Frame: Decodable {
            let p: Int
            let x: Int
            let y: Int
            let w: Int
            let h: Int
            let ox: Int
            let oy: Int
            let sw: Int
            let sh: Int
        }

        let pages: [Page]
        let frames: [String: Frame]
    }

    let sheets: [String: Sheet]
}

struct FMDialogLine: Decodable {
    let t: String
    let f: String
    let k: String
}

struct FMRoleParams: Decodable {
    let maxF: Double
    let maxP: Double
    let mass: Double
    let damping: Double
    let maxXSpeed: Double
    let extraXDamping: Double
    let extraNonFlyXDamping: Double
    let yGravity: Double
    let pushAngleRange: Double
    let pushAngleBound1: Double
    let pushAngleBound2: Double
    let stableFlyRate: Double
    let pushDistance1: Double
    let pushDistance2: Double
}

struct FMSave: Codable {
    var passed: [String: Bool] = [:]
    var bestTime: [String: Double] = [:]
    var stars: [String: Int] = [:]
    var flags: [String: Bool] = [:]
}
