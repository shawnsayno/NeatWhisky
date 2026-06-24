//
//  SteamRecipe.swift
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
import os.log

/// Fixes that make Steam usable under modern Wine on Apple Silicon:
///
/// - **M5 — garbled text (乱码):** installs CJK fonts via `winetricks cjkfonts`.
/// - **M6 — black window + close/restart loop:** replaces `steamwebhelper.exe`
///   with a wrapper that forces CEF into `--disable-gpu --single-process` and
///   confines the real process to a Job Object so it dies with Steam.
/// - **M7 — launch arguments + locale:** writes `-cef-disable-gpu
///   -cef-disable-gpu-compositing -noverifyfiles` (the last flag stops Steam
///   from reverting the wrapper) and a sensible locale into `ProgramSettings`.
public struct SteamRecipe: AppRecipe {
    public let id = "steam"
    public let name = "Steam"
    public let summary = "Fix Steam garbled text, black window and the close/restart loop."

    // MARK: - Constants

    static let steamRoot = "Program Files (x86)/Steam"
    static let steamExeSubpath = "Program Files (x86)/Steam/Steam.exe"
    static let cefBase = "Program Files (x86)/Steam/bin/cef"
    static let cefDirs = ["cef.win64", "cef.win7x64"]
    static let webHelper = "steamwebhelper.exe"
    static let webHelperOrig = "steamwebhelper_orig.exe"
    static let launchArguments = "-cef-disable-gpu -cef-disable-gpu-compositing -noverifyfiles"

    public init() {}

    // MARK: - AppRecipe

    public func detect(in bottle: Bottle) async -> Bool {
        let exe = RecipeTools.driveC(bottle, Self.steamExeSubpath)
        return FileManager.default.fileExists(atPath: exe.path(percentEncoded: false))
    }

    public func status(in bottle: Bottle) async -> RecipeStatus {
        guard await detect(in: bottle) else { return .notApplicable }

        let wrapper = wrapperResourceURL()
        let cefTargets = existingCefDirs(in: bottle)

        // If Steam reverted any injected wrapper, we need repair.
        if let wrapper = wrapper {
            for dir in cefTargets {
                let helper = dir.appending(path: Self.webHelper)
                let orig = dir.appending(path: Self.webHelperOrig)
                let helperExists = FileManager.default.fileExists(atPath: helper.path(percentEncoded: false))
                let origExists = FileManager.default.fileExists(atPath: orig.path(percentEncoded: false))
                if origExists, helperExists, !filesEqualSize(helper, wrapper) {
                    return .needsRepair(reason: "Steam reverted the steamwebhelper wrapper")
                }
            }
        }

        let wrapperApplied = !cefTargets.isEmpty && cefTargets.allSatisfy { dir in
            FileManager.default.fileExists(atPath: dir.appending(path: Self.webHelperOrig).path(percentEncoded: false))
        }
        let fontsApplied = winetricksContains("cjkfonts", bottle: bottle)
        let argsApplied = currentLaunchArguments(bottle: bottle)?.contains("-cef-disable-gpu") == true

        if wrapperApplied && fontsApplied && argsApplied {
            return .applied
        }
        return .notApplied
    }

    public func apply(to bottle: Bottle, progress: RecipeProgress?) async throws {
        guard await detect(in: bottle) else {
            throw RecipeError.stepFailed("Steam is not installed in this bottle")
        }

        // M7 — launch arguments + locale (write first so -noverifyfiles is in
        // place before the wrapper is injected).
        progress?(RecipeStep(title: "Configuring Steam launch options", fraction: 0.1))
        try RecipeTools.setProgramSettings(
            bottle: bottle, exeDriveCSubpath: Self.steamExeSubpath,
            arguments: Self.launchArguments, locale: Self.preferredLocale()
        )

        // M6 — steamwebhelper wrapper (black window + restart loop).
        progress?(RecipeStep(title: "Installing steamwebhelper wrapper", fraction: 0.3))
        try injectWrapper(in: bottle)

        // M5 — CJK fonts (garbled text).
        progress?(RecipeStep(title: "Installing CJK fonts (winetricks cjkfonts)", fraction: 0.5))
        if !winetricksContains("cjkfonts", bottle: bottle) {
            do {
                try await RecipeTools.winetricks(["cjkfonts"], bottle: bottle, progress: progress)
            } catch {
                // Fonts are best-effort; fall back to registry substitution below.
                Logger.wineKit.warning("winetricks cjkfonts failed: \(error.localizedDescription)")
            }
        }
        try await configureFontFallback(bottle: bottle)

        progress?(RecipeStep(title: "Steam fixes applied", fraction: 1.0))
    }

    public func prelaunchHeal(in bottle: Bottle) async throws {
        guard await detect(in: bottle) else { return }
        // Re-assert launch options and re-inject the wrapper. Both are fast,
        // local, idempotent operations. `injectWrapper` no-ops if Steam's CEF
        // hasn't been downloaded yet, and refreshes the backup if Steam reverted
        // our wrapper since the last launch.
        try RecipeTools.setProgramSettings(
            bottle: bottle, exeDriveCSubpath: Self.steamExeSubpath,
            arguments: Self.launchArguments, locale: Self.preferredLocale()
        )
        try injectWrapper(in: bottle)
    }

    public func repair(in bottle: Bottle, progress: RecipeProgress?) async throws {
        progress?(RecipeStep(title: "Re-applying Steam fixes", fraction: 0.2))
        // Re-assert launch options, then re-inject the wrapper (the part Steam
        // updates tend to revert).
        try RecipeTools.setProgramSettings(
            bottle: bottle, exeDriveCSubpath: Self.steamExeSubpath,
            arguments: Self.launchArguments, locale: Self.preferredLocale()
        )
        try injectWrapper(in: bottle)
        progress?(RecipeStep(title: "Steam fixes repaired", fraction: 1.0))
    }

    // MARK: - M6: wrapper injection

    /// Inject the wrapper into every present CEF directory.
    /// - Returns: `true` if at least one directory was wrapped. Returns `false`
    ///   (without throwing) when no CEF directory exists yet — Steam only
    ///   downloads `bin/cef` during its first-launch self-update, so injection
    ///   is deferred to the self-heal / pre-launch step in that case.
    @discardableResult
    private func injectWrapper(in bottle: Bottle) throws -> Bool {
        guard let wrapper = wrapperResourceURL() else {
            throw RecipeError.resourceMissing("steamwebhelper_wrapper.exe")
        }
        let fileManager = FileManager.default
        let cefTargets = existingCefDirs(in: bottle)
        guard !cefTargets.isEmpty else {
            Logger.wineKit.info("Steam CEF not present yet; wrapper injection deferred to first launch")
            return false
        }

        for dir in cefTargets {
            let helper = dir.appending(path: Self.webHelper)
            let orig = dir.appending(path: Self.webHelperOrig)
            let helperPath = helper.path(percentEncoded: false)
            let origPath = orig.path(percentEncoded: false)

            guard fileManager.fileExists(atPath: helperPath) else { continue }

            // Back up the real binary the first time, or refresh the backup if
            // Steam restored the original over our wrapper.
            if !fileManager.fileExists(atPath: origPath) {
                try fileManager.copyItem(at: helper, to: orig)
            } else if !filesEqualSize(helper, wrapper) {
                try fileManager.removeItem(at: orig)
                try fileManager.copyItem(at: helper, to: orig)
            }

            // Install the wrapper as steamwebhelper.exe.
            try fileManager.removeItem(at: helper)
            try fileManager.copyItem(at: wrapper, to: helper)
        }
        return true
    }

    private func existingCefDirs(in bottle: Bottle) -> [URL] {
        let base = RecipeTools.driveC(bottle, Self.cefBase)
        return Self.cefDirs
            .map { base.appending(path: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    private func wrapperResourceURL() -> URL? {
        Bundle.module.url(
            forResource: "steamwebhelper_wrapper", withExtension: "exe", subdirectory: "SteamFix"
        )
    }

    private func filesEqualSize(_ lhs: URL, _ rhs: URL) -> Bool {
        let fileManager = FileManager.default
        let lhsSize = (try? fileManager.attributesOfItem(atPath: lhs.path(percentEncoded: false))[.size]) as? Int
        let rhsSize = (try? fileManager.attributesOfItem(atPath: rhs.path(percentEncoded: false))[.size]) as? Int
        return lhsSize != nil && lhsSize == rhsSize
    }

    // MARK: - M5: font helpers

    /// Whether winetricks has recorded the given verb for this bottle.
    private func winetricksContains(_ verb: String, bottle: Bottle) -> Bool {
        let log = bottle.url.appending(path: "winetricks.log")
        guard let contents = try? String(contentsOf: log, encoding: .utf8) else { return false }
        return contents.split(whereSeparator: \.isNewline).contains { $0.trimmingCharacters(in: .whitespaces) == verb }
    }

    /// Register font substitutions so Western UI font names fall back to a
    /// CJK-capable face. Acts as a safety net alongside `winetricks cjkfonts`.
    private func configureFontFallback(bottle: Bottle) async throws {
        let substitutesKey = #"HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes"#
        let cjkFace = "SimSun"
        for face in ["MS Shell Dlg", "MS Shell Dlg 2", "Tahoma", "Segoe UI", "Arial"] {
            try await RecipeTools.setRegistryValue(
                bottle: bottle, key: substitutesKey, name: face, data: cjkFace, type: .string
            )
        }
    }

    private func currentLaunchArguments(bottle: Bottle) -> String? {
        let exeURL = RecipeTools.driveC(bottle, Self.steamExeSubpath)
        let settingsURL = bottle.url
            .appending(path: "Program Settings")
            .appending(path: exeURL.lastPathComponent)
            .appendingPathExtension("plist")
        guard FileManager.default.fileExists(atPath: settingsURL.path(percentEncoded: false)),
              let settings = try? ProgramSettings.decode(from: settingsURL) else { return nil }
        return settings.arguments
    }

    // MARK: - Locale

    /// Pick a launch locale matching the user's primary language for CJK users
    /// (improves rendering + Steam UI language); otherwise inherit the system.
    static func preferredLocale() -> Locales {
        let primary = Locale.preferredLanguages.first?.lowercased() ?? ""
        if primary.hasPrefix("zh-hant") || primary.hasPrefix("zh-tw") || primary.hasPrefix("zh-hk") {
            return .chineseTraditional
        }
        if primary.hasPrefix("zh") {
            return .chineseSimplified
        }
        if primary.hasPrefix("ja") {
            return .japanese
        }
        if primary.hasPrefix("ko") {
            return .korean
        }
        return .auto
    }
}
