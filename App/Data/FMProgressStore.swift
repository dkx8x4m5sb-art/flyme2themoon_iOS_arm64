//
//  FMProgressStore.swift
//  通关 / 星级 / 剧情标记，全部落在 UserDefaults 里。
//

import Foundation

final class FMProgressStore {
    static let shared = FMProgressStore()

    private let storageKey = "fm.save.v1"
    private var save: FMSave

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(FMSave.self, from: data) {
            save = decoded
        } else {
            save = FMSave()
        }
    }

    private func flush() {
        if let data = try? JSONEncoder().encode(save) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func isPassed(_ level: Int) -> Bool { save.passed[String(level)] == true }

    func stars(_ level: Int) -> Int { save.stars[String(level)] ?? 0 }

    func bestTime(_ level: Int) -> Double { save.bestTime[String(level)] ?? 0 }

    func markPassed(level: Int, time: Double, stars: Int) {
        let key = String(level)
        save.passed[key] = true
        if save.bestTime[key] == nil || time < (save.bestTime[key] ?? .greatestFiniteMagnitude) {
            save.bestTime[key] = time
        }
        save.stars[key] = max(save.stars[key] ?? 0, stars)
        flush()
    }

    func flag(_ key: String) -> Bool { save.flags[key] == true }

    func setFlag(_ key: String) {
        save.flags[key] = true
        flush()
    }

    /// dependency.json：某关的所有前置关都通关后解锁；已通关的关永远可进。
    func unlockedLevels() -> Set<Int> {
        var open: Set<Int> = [1]
        for id in FMGameData.shared.levelIDs where isPassed(id) { open.insert(id) }
        for (key, requires) in FMGameData.shared.dependency {
            guard let id = Int(key) else { continue }
            if requires.allSatisfy({ isPassed($0) }) { open.insert(id) }
        }
        return open
    }

    var passedCount: Int { save.passed.values.filter { $0 }.count }

    var totalStars: Int { save.stars.values.reduce(0, +) }

    func resetAll() {
        save = FMSave()
        flush()
    }
}
