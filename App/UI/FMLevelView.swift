//
//  FMLevelView.swift
//  关卡界面：SpriteKit 渲染 + 顶部 HUD + 对话框 + 结算面板。
//

import SpriteKit
import SwiftUI
import UIKit

struct FMLevelView: View {
    let levelID: Int
    let isRestart: Bool
    let onExit: () -> Void
    let onRetry: () -> Void
    let onNext: (Int) -> Void

    @StateObject private var model: FMLevelModel

    init(levelID: Int, isRestart: Bool, onExit: @escaping () -> Void,
         onRetry: @escaping () -> Void, onNext: @escaping (Int) -> Void) {
        self.levelID = levelID
        self.isRestart = isRestart
        self.onExit = onExit
        self.onRetry = onRetry
        self.onNext = onNext
        _model = StateObject(wrappedValue: FMLevelModel(levelID: levelID, isRestart: isRestart))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            SpriteView(scene: model.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HUDView(levelID: levelID, time: model.time, failures: model.failures, onExit: onExit)
                if let tip = model.tutorialText {
                    Text(tip)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                Spacer()
                if model.result == nil {
                    Text("按住拖动瞄准 · 松手弹射")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.bottom, 18)
                }
            }

            if let dialog = model.dialog {
                FMDialogCard(state: dialog, skipEnabled: model.skipEnabled) { skipped in
                    model.dismissDialog(skipped: skipped)
                }
                .transition(.opacity)
            }

            if let result = model.result {
                FMResultCard(result: result,
                             onRetry: { model.result = nil; onRetry() },
                             onNext: { next in model.result = nil; onNext(next) },
                             onExit: onExit)
            }
        }
        .onDisappear { model.stop() }
    }
}

private struct HUDView: View {
    let levelID: Int
    let time: Double
    let failures: Int
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.45), in: Circle())
            }
            Text("第 \(levelID) 关")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Label(FMHudFormat.time(time), systemImage: "stopwatch")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
            if failures > 0 {
                Label("\(failures)", systemImage: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.red.opacity(0.9))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .background(LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom))
    }
}

enum FMHudFormat {
    static func time(_ value: Double) -> String {
        let minutes = Int(value) / 60
        let seconds = value - Double(minutes * 60)
        return String(format: "%02d:%04.1f", minutes, seconds)
    }
}

private struct FMDialogCard: View {
    let state: FMDialogState
    let skipEnabled: Bool
    let onDismiss: (Bool) -> Void

    @State private var canAdvance = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    if let image = FMGameData.shared.faceImage(state.face) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    FMRichText(raw: state.text)
                        .font(.system(size: 17))
                        .lineSpacing(4)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    if skipEnabled {
                        Button("跳过剧情") { onDismiss(true) }
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    Button(canAdvance ? "继续 ▸" : "…") {
                        if canAdvance { onDismiss(false) }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canAdvance ? Color(red: 0.4, green: 0.8, blue: 1) : .white.opacity(0.3))
                    .disabled(!canAdvance)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.09, blue: 0.15).opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .task(id: state.id) {
            canAdvance = state.minTime <= 0
            guard state.minTime > 0 else { return }
            try? await Task.sleep(nanoseconds: UInt64(state.minTime * 1_000_000_000))
            canAdvance = true
            if state.autoClose { onDismiss(false) }
        }
    }
}

private struct FMResultCard: View {
    let result: FMLevelResult
    let onRetry: () -> Void
    let onNext: (Int) -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("到达月亮")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                Text(String(repeating: "★", count: max(1, result.stars)))
                    .font(.system(size: 34))
                    .foregroundStyle(.yellow)
                Text("用时 \(FMHudFormat.time(result.time))")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 12) {
                    Button("重玩", action: onRetry)
                        .buttonStyle(FMMenuButtonStyle(primary: false))
                    if !result.isLastLevel {
                        Button("下一关") { onNext(result.levelID + 1) }
                            .buttonStyle(FMMenuButtonStyle())
                    } else {
                        Button("返回选关", action: onExit)
                            .buttonStyle(FMMenuButtonStyle())
                    }
                }
                .frame(maxWidth: 320)

                Button("返回选关", action: onExit)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(26)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.16))
            )
            .padding(24)
        }
    }
}
