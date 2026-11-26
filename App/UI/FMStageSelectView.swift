//
//  FMStageSelectView.swift
//  60 关的选关界面，解锁关系来自 dependency.json。
//

import SwiftUI

struct FMStageSelectView: View {
    let onSelect: (Int) -> Void
    let onBack: () -> Void

    private let ids: [Int] = FMGameData.shared.levelIDs

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(ids, id: \.self) { id in
                        stageButton(id)
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.04, green: 0.05, blue: 0.10).ignoresSafeArea())
            .navigationTitle("关卡选择")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { onBack() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(FMProgressStore.shared.totalStars) ★")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.yellow)
                }
            }
        }
    }

    private func stageButton(_ id: Int) -> some View {
        let unlocked = FMProgressStore.shared.unlockedLevels().contains(id)
        let stars = FMProgressStore.shared.stars(id)
        return Button {
            if unlocked { onSelect(id) }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(unlocked ? Color(red: 0.10, green: 0.28, blue: 0.48) : Color.white.opacity(0.08))
                        .frame(height: 64)
                    if unlocked {
                        Text("\(id)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if FMProgressStore.shared.isPassed(id) {
                            VStack {
                                Spacer()
                                Text("★\(max(1, stars))")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                    .padding(.bottom, 4)
                            }
                        }
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}
