//
//  FMSettingsView.swift
//  静音、重置进度、版本信息。
//

import SwiftUI

struct FMSettingsView: View {
    let onClose: () -> Void

    @AppStorage("fm.muted") private var muted = false
    @State private var confirmReset = false
    @State private var resetDone = false

    var body: some View {
        NavigationStack {
            Form {
                Section("声音") {
                    Toggle("静音", isOn: $muted)
                        .onChange(of: muted) { value in
                            FMAudioEngine.shared.setMuted(value)
                        }
                }

                Section("进度") {
                    LabeledContent("已通关", value: "\(FMProgressStore.shared.passedCount) / \(FMGameData.shared.levelIDs.count)")
                    LabeledContent("星星", value: "\(FMProgressStore.shared.totalStars)")
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text("重置全部进度")
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: "1.7.0 (arm64 重制)")
                    LabeledContent("引擎", value: "SpriteKit + Lua 5.1.5")
                    Text("素材与关卡脚本来自原版《Fly Me 2 the Moon》，版权归 miHoYo 所有，仅用于本机备份与自用。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { onClose() }
                }
            }
            .alert("重置全部进度？", isPresented: $confirmReset) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    FMProgressStore.shared.resetAll()
                    resetDone = true
                }
            } message: {
                Text("通关记录、星级和剧情标记都会被清空，无法恢复。")
            }
            .alert("已重置", isPresented: $resetDone) {
                Button("好", role: .cancel) {}
            }
        }
    }
}
