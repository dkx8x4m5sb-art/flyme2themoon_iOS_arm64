//
//  FMMenuView.swift
//  主菜单：原版 splash 图 + 三个入口。
//

import SwiftUI
import UIKit

struct FMMenuView: View {
    let onPlay: () -> Void
    let onSelectLevel: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            if let image = UIImage(contentsOfFile: FMGameData.shared.url("art/splash.png").path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.18),
                                        Color(red: 0.10, green: 0.28, blue: 0.42)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 6) {
                    Text("飞向月球")
                        .font(.system(size: 46, weight: .heavy, design: .serif))
                        .foregroundStyle(.white)
                    Text("FLY ME 2 THE MOON")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()

                VStack(spacing: 14) {
                    Button(action: onPlay) {
                        Text("继续冒险")
                    }
                    .buttonStyle(FMMenuButtonStyle())

                    Button(action: onSelectLevel) {
                        Text("关卡选择")
                    }
                    .buttonStyle(FMMenuButtonStyle(primary: false))

                    Button(action: onSettings) {
                        Text("设置")
                    }
                    .buttonStyle(FMMenuButtonStyle(primary: false))
                }
                .frame(maxWidth: 260)

                Spacer().frame(height: 60)

                Text("64 位 arm64 重制 · 素材来自原版")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 24)
            }
        }
    }
}

struct FMMenuButtonStyle: ButtonStyle {
    var primary: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(primary ? .white : Color.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(primary ? Color(red: 0.10, green: 0.45, blue: 0.80) : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
