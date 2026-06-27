//
//  RecipeTests.swift
//  WhiskyKitTests
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
import Testing
import SemanticVersion
@testable import WhiskyKit

/// Covers the recipe engine (M4) and the Steam recipe's declarative metadata
/// (M5–M7), including the new minimum-Wine-version requirement.
@Suite struct RecipeTests {
    @Test func steamRecipeRequiresModernWine() {
        // M4 gap: recipes can declare a minimum Wine version.
        #expect(SteamRecipe().minimumWineVersion == SemanticVersion(11, 0, 0))
    }

    @Test func defaultRecipeHasNoMinimumWineVersion() {
        #expect(StubRecipe().minimumWineVersion == nil)
    }

    @Test func steamLaunchArgumentsMatchPlan() {
        #expect(
            SteamRecipe.launchArguments ==
            "-cef-disable-gpu -cef-disable-gpu-compositing -noverifyfiles"
        )
    }

    @Test func steamRecipeInjectsBothCefDirs() {
        #expect(SteamRecipe.cefDirs == ["cef.win64", "cef.win7x64"])
    }

    @Test func graphicsStackIsFullyOpenSource() {
        #expect(GraphicsStack.allowsProprietaryComponents == false)
        #expect(GraphicsStack.dxvkEnabledByDefault == true)
        #expect(!GraphicsStack.components.isEmpty)
    }

    @Test func driveCBuildsNestedWindowsPath() {
        let bottle = Bottle(bottleUrl: URL(fileURLWithPath: "/tmp/neatwhisky-test-bottle"))
        let url = RecipeTools.driveC(bottle, "Program Files (x86)/Steam/Steam.exe")
        #expect(url.path.hasSuffix("drive_c/Program Files (x86)/Steam/Steam.exe"))
    }
}

/// A minimal recipe used to verify protocol defaults.
private struct StubRecipe: AppRecipe {
    let id = "stub"
    let name = "Stub"
    let summary = "test"
    func detect(in bottle: Bottle) async -> Bool { false }
    func apply(to bottle: Bottle, progress: RecipeProgress?) async throws {}
    func status(in bottle: Bottle) async -> RecipeStatus { .notApplicable }
}
