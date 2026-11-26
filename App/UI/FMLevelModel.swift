//
//  FMLevelModel.swift
//  关卡视图的状态中枢：把 SKScene 的事件转成 SwiftUI 能绑定的状态。
//

import Foundation
import SwiftUI

struct FMDialogState: Identifiable {
    let id = UUID()
    let key: String
    let text: String
    let face: String
    let minTime: Double
    let autoClose: Bool
}

final class FMLevelModel: ObservableObject, FMLevelSceneDelegate {
    let levelID: Int
    let isRestart: Bool

    @Published var time: Double = 0
    @Published var failures: Int = 0
    @Published var dialog: FMDialogState?
    @Published var result: FMLevelResult?
    @Published var tutorialText: String?
    @Published var skipEnabled = false

    private var skipAll = false
    private var storedScene: FMLevelScene?

    init(levelID: Int, isRestart: Bool) {
        self.levelID = levelID
        self.isRestart = isRestart
    }

    var scene: FMLevelScene {
        if let storedScene { return storedScene }
        let scene = FMLevelScene(levelID: levelID, isRestart: isRestart)
        scene.levelDelegate = self
        storedScene = scene
        return scene
    }

    func stop() {
        storedScene?.isPaused = true
    }

    func dismissDialog(skipped: Bool) {
        guard dialog != nil else { return }
        dialog = nil
        if skipped { skipAll = true }
        storedScene?.resolveDialog(skipped: skipped)
    }

    // MARK: - FMLevelSceneDelegate

    func levelScene(_ scene: FMLevelScene, showDialog key: String, face: String, minTime: Double, autoClose: Bool) {
        if skipAll {
            DispatchQueue.main.async { scene.resolveDialog(skipped: true) }
            return
        }
        let line = FMGameData.shared.dialog(key)
        let state = FMDialogState(key: key, text: line?.t ?? key, face: face,
                                  minTime: max(0, minTime), autoClose: autoClose)
        DispatchQueue.main.async { self.dialog = state }
    }

    func levelScene(_ scene: FMLevelScene, time: Double, failures: Int) {
        self.time = time
        if self.failures != failures { self.failures = failures }
    }

    func levelScene(_ scene: FMLevelScene, finished result: FMLevelResult) {
        DispatchQueue.main.async { self.result = result }
    }

    func levelScene(_ scene: FMLevelScene, showTutorial index: Int) {
        DispatchQueue.main.async {
            self.tutorialText = index == 0 ? nil : "按住屏幕拖动瞵准，松手弹射。飞到月亮即可过关。"
        }
    }

    func levelScene(_ scene: FMLevelScene, skipEnabled enabled: Bool) {
        skipEnabled = enabled
        if !enabled { skipAll = false }
    }
}
