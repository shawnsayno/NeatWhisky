//
//  SteamSetupWizardView.swift
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

/// The first-run "开箱向导": one tap, then everything (Wine, Rosetta, bottle,
/// Steam download + install, fixes) happens automatically with live progress.
struct SteamSetupWizardView: View {
    @Binding var showWizard: Bool
    @StateObject private var viewModel = SteamSetupViewModel()
    @State private var region: MirrorRegion = DownloadSources.preferredRegion

    var body: some View {
        VStack(spacing: 20) {
            if viewModel.errorMessage != nil {
                errorState
            } else if viewModel.finished {
                successState
            } else if viewModel.isRunning {
                runningState
            } else {
                introState
            }
        }
        .padding(24)
        .frame(width: 480, height: 360)
    }

    // MARK: - Intro

    private var introState: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(.tint)
            Text("一键安装 Steam")
                .font(.title)
                .fontWeight(.bold)
            Text("全程自动：安装运行环境、创建专用容器、下载并静默安装最新 Steam，"
                 + "并自动修复乱码、黑屏与意外退出。无需任何手动配置。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Picker("下载线路", selection: $region) {
                ForEach(MirrorRegion.allCases, id: \.self) { region in
                    Text(region.pretty()).tag(region)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: region) { _, newValue in
                DownloadSources.preferredRegion = newValue
            }

            Spacer()
            HStack {
                Button("取消") { showWizard = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("开始") { viewModel.start(bottleName: "Steam") }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Running

    private var runningState: some View {
        VStack(spacing: 16) {
            Text("正在为你安装 Steam…")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            ProgressView(value: viewModel.fraction, total: 1)
                .progressViewStyle(.linear)
            VStack(spacing: 4) {
                Text(viewModel.currentTitle)
                    .font(.headline)
                if let detail = viewModel.currentDetail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text("首次安装需要下载较多内容，请保持网络畅通，可能需要几分钟。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Success

    private var successState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.green)
            Text("全部就绪！")
                .font(.title)
                .fontWeight(.bold)
            Text("Steam 已安装并完成适配。在左侧选择 “Steam” 容器，点击启动即可开玩。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("完成") { showWizard = false }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Error

    private var errorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.red)
            Text("安装未完成")
                .font(.title)
                .fontWeight(.bold)
            ScrollView {
                Text(viewModel.errorMessage ?? "未知错误")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxHeight: 100)
            Spacer()
            HStack {
                Button("关闭") { showWizard = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("重试") { viewModel.start(bottleName: "Steam") }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    SteamSetupWizardView(showWizard: .constant(true))
}
