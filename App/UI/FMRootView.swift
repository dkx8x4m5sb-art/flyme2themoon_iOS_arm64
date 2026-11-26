//
//  FMRootView.swift
//  菜单 / 选关 / 关卡三个界面的切换。
//

import SwiftUI

struct FMRootView: View {
    enum Screen: Equatable {
        case menu
        case stages
        case level(Int)
    }

    @State private var screen: Screen = .menu
    @State private var attempt = 0
    @State private var showsSettings = false

    var body: some View {
        ZStack {
            switch screen {
            case .menu:
                FMMenuView(
                    onPlay: { screen = .level(nextLevelToPlay()) },
                    onSelectLevel: { screen = .stages },
                    onSettings: { showsSettings = true }
                )
            case .stages:
                FMStageSelectView(
                    onSelect: { level in
                        attempt = 0
                        screen = .level(level)
                    },
                    onBack: { screen = .menu }
                )
            case .level(let level):
                FMLevelView(
                    levelID: level,
                    isRestart: attempt > 0,
                    onExit: {
                        attempt = 0
                        screen = .stages
                    },
                    onRetry: { attempt += 1 },
                    onNext: { next in
                        attempt = 0
                        screen = .level(next)
                    }
                )
                .id("level-\(level)-\(attempt)")
            }
        }
        .sheet(isPresented: $showsSettings) {
            FMSettingsView(onClose: { showsSettings = false })
        }
    }

    private func nextLevelToPlay() -> Int {
        let ids = FMGameData.shared.levelIDs
        let unlocked = FMProgressStore.shared.unlockedLevels()
        let firstUnpassed = ids.first { unlocked.contains($0) && !FMProgressStore.shared.isPassed($0) }
        return firstUnpassed ?? ids.first ?? 1
    }
}
