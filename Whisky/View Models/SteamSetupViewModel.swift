//
//  SteamSetupViewModel.swift
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

import Foundation
import SwiftUI
import WhiskyKit

/// Drives the one-click Steam onboarding wizard, bridging the headless
/// ``SteamBootstrapper`` to SwiftUI state on the main actor.
@MainActor
final class SteamSetupViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var finished = false
    @Published var currentTitle = ""
    @Published var currentDetail: String?
    @Published var fraction: Double = 0
    @Published var errorMessage: String?
    @Published var createdBottleURL: URL?

    func start(bottleName: String) {
        guard !isRunning else { return }
        isRunning = true
        finished = false
        errorMessage = nil
        fraction = 0
        currentTitle = "准备中…"
        currentDetail = nil

        let progress: @Sendable (RecipeStep) -> Void = { [weak self] step in
            Task { @MainActor in
                guard let self else { return }
                self.currentTitle = step.title
                self.currentDetail = step.detail
                if let fraction = step.fraction {
                    self.fraction = fraction
                }
            }
        }

        Task {
            do {
                let bottle = try await SteamBootstrapper().run(bottleName: bottleName, progress: progress)
                self.createdBottleURL = bottle.url
                self.fraction = 1
                self.isRunning = false
                self.finished = true
                BottleVM.shared.loadBottles()
            } catch {
                self.isRunning = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
