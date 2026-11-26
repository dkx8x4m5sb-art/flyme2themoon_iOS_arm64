//
//  FMAudioEngine.swift
//  原版音效（70 个 wav）全部由脚本 sound.play("xx-y") 触发，这里做缓存播放。
//  BGM 的 6 首 .caf 只在 1.1 包里，当前素材包没有，所以不播放背景音乐。
//

import AVFoundation
import Foundation

final class FMAudioEngine {
    static let shared = FMAudioEngine()

    private var players: [String: AVAudioPlayer] = [:]
    private let lock = NSLock()
    private var configured = false
    private var muted = false

    private init() {}

    func prepare() {
        guard !configured else { return }
        configured = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func setMuted(_ value: Bool) { muted = value }

    func play(_ identifier: String) {
        guard !muted else { return }
        guard FMGameData.shared.sounds.contains(identifier) else {
            NSLog("[FM] 缺音效 %@", identifier)
            return
        }
        prepare()
        lock.lock()
        let player: AVAudioPlayer?
        if let cached = players[identifier] {
            player = cached
        } else {
            let url = FMGameData.shared.url("audio/\(identifier).wav")
            player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            players[identifier] = player
        }
        lock.unlock()
        guard let p = player else { return }
        p.currentTime = 0
        p.play()
    }
}
