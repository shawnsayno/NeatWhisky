//
//  SteamBootstrapper.swift
//  WhiskyKit
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
import SemanticVersion
import os.log

public enum BootstrapError: Error, LocalizedError {
    case unsupportedOS(String)
    case wineUnavailable
    case rosettaFailed
    case steamInstallFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOS(let detail):
            return "Unsupported macOS version: \(detail)"
        case .wineUnavailable:
            return "Wine is not installed and could not be downloaded."
        case .rosettaFailed:
            return "Rosetta 2 installation failed."
        case .steamInstallFailed(let detail):
            return "Steam installation failed: \(detail)"
        }
    }
}

/// One-click, zero-to-playable setup for Steam.
///
/// Orchestrates the whole "beginner" path: verify the system, ensure Wine and
/// Rosetta 2 are present, create a dedicated Steam bottle, download and silently
/// install the latest official Steam, and apply the Steam fixes — reporting
/// progress throughout and rolling back the bottle on failure.
///
/// The actual progress UI ("开箱向导") is wired on top of this in M10; this type
/// holds the orchestration and is fully usable headlessly.
public struct SteamBootstrapper {
    public init() {}

    /// Run the full bootstrap. Returns the created (and configured) bottle.
    @discardableResult
    public func run(
        bottleName: String = "Steam",
        progress: RecipeProgress? = nil
    ) async throws -> Bottle {
        try preflight(progress: progress)
        try await ensureWine(progress: progress)
        try await ensureRosetta(progress: progress)

        let bottle = try await createBottle(named: bottleName, progress: progress)
        do {
            try await installSteam(into: bottle, progress: progress)
            try await applyFixes(to: bottle, progress: progress)
        } catch {
            Logger.wineKit.error("Bootstrap failed, rolling back bottle: \(error.localizedDescription)")
            rollback(bottle)
            throw error
        }

        progress?(RecipeStep(title: "All set — launch Steam from NeatWhisky", fraction: 1.0))
        return bottle
    }

    // MARK: - Stages

    private func preflight(progress: RecipeProgress?) throws {
        progress?(RecipeStep(title: "Checking your Mac", fraction: 0.02))
        let version = ProcessInfo.processInfo.operatingSystemVersion
        guard version.majorVersion >= 14 else {
            throw BootstrapError.unsupportedOS(
                "\(version.majorVersion).\(version.minorVersion) (macOS 14 Sonoma or newer required)"
            )
        }
    }

    private func ensureWine(progress: RecipeProgress?) async throws {
        guard !WhiskyWineInstaller.isWhiskyWineInstalled() else { return }
        progress?(RecipeStep(title: "Downloading Wine", fraction: 0.05))
        let tarball = try await DownloadSources.download(.wineLibraries) { fraction in
            progress?(RecipeStep(
                title: "Downloading Wine", detail: "\(Int(fraction * 100))%",
                fraction: 0.05 + fraction * 0.1
            ))
        }
        progress?(RecipeStep(title: "Installing Wine", fraction: 0.16))
        WhiskyWineInstaller.install(from: tarball)
        guard WhiskyWineInstaller.isWhiskyWineInstalled() else {
            throw BootstrapError.wineUnavailable
        }
    }

    private func ensureRosetta(progress: RecipeProgress?) async throws {
        guard Self.isAppleSilicon, !Rosetta2.isRosettaInstalled else { return }
        progress?(RecipeStep(title: "Installing Rosetta 2", fraction: 0.18))
        let installed = try await Rosetta2.installRosetta()
        guard installed else { throw BootstrapError.rosettaFailed }
    }

    private func createBottle(named bottleName: String, progress: RecipeProgress?) async throws -> Bottle {
        progress?(RecipeStep(title: "Creating Steam bottle", fraction: 0.22))
        let newBottleDir = BottleData.defaultBottleDir.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: newBottleDir, withIntermediateDirectories: true)

        let bottle = Bottle(bottleUrl: newBottleDir, inFlight: true)
        bottle.settings.name = bottleName
        bottle.settings.windowsVersion = .win10
        bottle.settings.dxvk = GraphicsStack.dxvkEnabledByDefault

        // First wine command initializes the prefix.
        try await Wine.runWine(["wineboot", "--init"], bottle: bottle)
        try await Wine.changeWinVersion(bottle: bottle, win: .win10)
        let wineVer = try await Wine.wineVersion()
        bottle.settings.wineVersion = SemanticVersion(wineVer) ?? BottleWineConfig.defaultWineVersion

        // Register the bottle so it shows up in the library.
        var bottleData = BottleData()
        bottleData.paths.append(newBottleDir)
        return bottle
    }

    private func installSteam(into bottle: Bottle, progress: RecipeProgress?) async throws {
        progress?(RecipeStep(title: "Downloading Steam", fraction: 0.5))
        let installer = try await DownloadSources.download(.steamInstaller) { fraction in
            progress?(RecipeStep(
                title: "Downloading Steam", detail: "\(Int(fraction * 100))%",
                fraction: 0.5 + fraction * 0.15
            ))
        }

        let destination = RecipeTools.driveC(bottle, "SteamSetup.exe")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: installer, to: destination)

        progress?(RecipeStep(title: "Installing Steam (silent)", fraction: 0.68))
        try await Wine.runWine(
            ["start", "/wait", "/unix", destination.path(percentEncoded: false), "/S"],
            bottle: bottle
        )

        let steamExe = RecipeTools.driveC(bottle, SteamRecipe.steamExeSubpath)
        guard fileManager.fileExists(atPath: steamExe.path(percentEncoded: false)) else {
            throw BootstrapError.steamInstallFailed("Steam.exe was not created by the installer")
        }
        try? fileManager.removeItem(at: destination)
    }

    private func applyFixes(to bottle: Bottle, progress: RecipeProgress?) async throws {
        progress?(RecipeStep(title: "Applying Steam fixes", fraction: 0.8))
        try await SteamRecipe().apply(to: bottle) { step in
            // Map the recipe's 0...1 progress into the bootstrap's 0.8...0.98 band.
            let mapped = step.fraction.map { 0.8 + $0 * 0.18 }
            progress?(RecipeStep(title: step.title, detail: step.detail, fraction: mapped))
        }
    }

    private func rollback(_ bottle: Bottle) {
        try? FileManager.default.removeItem(at: bottle.url)
        var bottleData = BottleData()
        bottleData.paths.removeAll { $0 == bottle.url }
    }

    // MARK: - Helpers

    /// Whether this Mac uses Apple Silicon (and therefore needs Rosetta 2).
    static let isAppleSilicon: Bool = {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return result == 0 && value == 1
    }()
}
