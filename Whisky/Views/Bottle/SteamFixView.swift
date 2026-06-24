//
//  SteamFixView.swift
//  NeatWhisky
//
//  This file is part of NeatWhisky, a fork of Whisky.
//
//  NeatWhisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  NeatWhisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with NeatWhisky.
//  If not, see https://www.gnu.org/licenses/.
//

import SwiftUI
import WhiskyKit

/// Bottle-detail section that surfaces the Steam recipe's status and a
/// one-tap "适配 / 重新修复" entry. Hidden when Steam isn't installed.
struct SteamFixView: View {
    @ObservedObject var bottle: Bottle

    @State private var applicable = false
    @State private var status: RecipeStatus = .notApplicable
    @State private var working = false
    @State private var progressTitle = ""
    @State private var fraction: Double = 0

    private let recipe = SteamRecipe()

    var body: some View {
        Group {
            if applicable {
                Section("Steam 适配") {
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                        Text(statusText)
                        Spacer()
                    }
                    if working {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: fraction, total: 1)
                            Text(progressTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            applyFix()
                        } label: {
                            Label(actionTitle, systemImage: "wrench.and.screwdriver")
                        }
                    }
                }
            }
        }
        .task(id: bottle.url) {
            await reload()
        }
    }

    // MARK: - Status presentation

    private var statusText: String {
        switch status {
        case .applied: return "已适配，可直接启动 Steam"
        case .notApplied: return "尚未适配（点击下方按钮一键修复乱码/黑屏/退出）"
        case .needsRepair(let reason): return "需要重新修复：\(reason)"
        case .error(let message): return "状态异常：\(message)"
        case .notApplicable: return ""
        }
    }

    private var statusIcon: String {
        switch status {
        case .applied: return "checkmark.circle.fill"
        case .notApplied: return "wrench.adjustable"
        case .needsRepair: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .notApplicable: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .applied: return .green
        case .notApplied: return .orange
        case .needsRepair: return .orange
        case .error: return .red
        case .notApplicable: return .secondary
        }
    }

    private var actionTitle: String {
        if case .applied = status { return "重新修复" }
        return "一键适配"
    }

    // MARK: - Actions

    private func reload() async {
        let detected = await recipe.detect(in: bottle)
        applicable = detected
        status = detected ? await recipe.status(in: bottle) : .notApplicable
    }

    private func applyFix() {
        guard !working else { return }
        working = true
        fraction = 0
        progressTitle = "准备中…"

        let isRepair: Bool
        if case .needsRepair = status { isRepair = true } else { isRepair = false }

        let progress: @Sendable (RecipeStep) -> Void = { step in
            Task { @MainActor in
                progressTitle = step.title
                if let fraction = step.fraction {
                    self.fraction = fraction
                }
            }
        }

        Task {
            do {
                if isRepair {
                    try await recipe.repair(in: bottle, progress: progress)
                } else {
                    try await recipe.apply(to: bottle, progress: progress)
                }
            } catch {
                progressTitle = error.localizedDescription
            }
            working = false
            await reload()
        }
    }
}
