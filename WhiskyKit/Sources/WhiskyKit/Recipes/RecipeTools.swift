//
//  RecipeTools.swift
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

/// Shared building blocks for ``AppRecipe`` implementations.
///
/// These wrap the lower-level `Wine` API and the filesystem so individual
/// recipes can be written declaratively (run winetricks verbs, set registry
/// values, drop files into the prefix, configure a program's launch arguments).
public enum RecipeTools {
    // MARK: - Paths

    /// Resolve a path inside a bottle's `C:` drive (`drive_c`).
    public static func driveC(_ bottle: Bottle, _ subpath: String) -> URL {
        var url = bottle.url.appending(path: "drive_c")
        for component in subpath.split(separator: "/") {
            url = url.appending(path: String(component))
        }
        return url
    }

    // MARK: - Registry

    /// Add or update a single registry value in the bottle.
    public static func setRegistryValue(
        bottle: Bottle, key: String, name: String, data: String,
        type: RecipeRegistryType = .string
    ) async throws {
        try await Wine.runWine(
            ["reg", "add", key, "-v", name, "-t", type.rawValue, "-d", data, "-f"],
            bottle: bottle
        )
    }

    // MARK: - Files

    /// Copy a bundled/resource file into a destination inside the bottle.
    /// Overwrites any existing file at the destination.
    public static func installFile(from source: URL, toDriveCSubpath subpath: String, bottle: Bottle) throws {
        let destination = driveC(bottle, subpath)
        let parent = destination.deletingLastPathComponent()
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: parent.path(percentEncoded: false)) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    // MARK: - Program settings (launch arguments / locale)

    /// Write launch arguments and/or locale for a program (an `.exe` relative to
    /// the bottle's `C:` drive) into its `ProgramSettings` plist. Existing
    /// settings are preserved unless explicitly overridden.
    public static func setProgramSettings(
        bottle: Bottle, exeDriveCSubpath: String,
        arguments: String? = nil, locale: Locales? = nil
    ) throws {
        let exeURL = driveC(bottle, exeDriveCSubpath)
        let settingsFolder = bottle.url.appending(path: "Program Settings")
        let settingsURL = settingsFolder
            .appending(path: exeURL.lastPathComponent)
            .appendingPathExtension("plist")

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: settingsFolder.path(percentEncoded: false)) {
            try fileManager.createDirectory(at: settingsFolder, withIntermediateDirectories: true)
        }

        var settings = try ProgramSettings.decode(from: settingsURL)
        if let arguments = arguments {
            settings.arguments = arguments
        }
        if let locale = locale {
            settings.locale = locale
        }
        try settings.encode(to: settingsURL)
    }

    // MARK: - winetricks

    /// Run one or more `winetricks` verbs against the bottle, unattended.
    ///
    /// The `winetricks` script is downloaded once (with mirror failover) and
    /// cached, then executed with the bundled Wine on `PATH` and the bottle as
    /// `WINEPREFIX`.
    public static func winetricks(
        _ verbs: [String], bottle: Bottle, progress: RecipeProgress? = nil
    ) async throws {
        progress?(RecipeStep(title: "Preparing winetricks", detail: verbs.joined(separator: " ")))
        let script = try await ensureWinetricks()

        var environment = ProcessInfo.processInfo.environment
        environment["WINE"] = Wine.wineBinary.path
        environment["WINEPREFIX"] = bottle.url.path(percentEncoded: false)
        environment["WINEDEBUG"] = "-all"
        environment["W_OPT_UNATTENDED"] = "1"
        let binPath = WhiskyWineInstaller.binFolder.path
        environment["PATH"] = binPath + ":" + (environment["PATH"] ?? "/usr/bin:/bin")

        progress?(RecipeStep(title: "Running winetricks", detail: verbs.joined(separator: " ")))
        let result = try await runProcess(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [script.path(percentEncoded: false)] + verbs,
            environment: environment
        )

        guard result.exitCode == 0 else {
            throw RecipeError.stepFailed("winetricks \(verbs.joined(separator: " ")) failed (exit \(result.exitCode))")
        }
    }

    /// Download (and cache) the `winetricks` script, returning its on-disk URL.
    static func ensureWinetricks() async throws -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: Bundle.whiskyBundleIdentifier)
        let scriptURL = cacheDir.appending(path: "winetricks")

        if FileManager.default.fileExists(atPath: scriptURL.path(percentEncoded: false)) {
            return scriptURL
        }

        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let downloaded = try await DownloadSources.download(.winetricks)
        if FileManager.default.fileExists(atPath: scriptURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: scriptURL)
        }
        try FileManager.default.moveItem(at: downloaded, to: scriptURL)
        // Make it executable (it is run via bash, but keep the bit consistent).
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: scriptURL.path(percentEncoded: false))
        return scriptURL
    }

    // MARK: - Generic process runner

    struct ProcessResult: Sendable {
        let exitCode: Int32
        let output: String
    }

    /// Run an executable to completion, capturing combined stdout/stderr.
    static func runProcess(
        executable: URL, arguments: [String], environment: [String: String]
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        return try await withCheckedThrowingContinuation { continuation in
            let collected = OutputCollector()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    collected.append(data)
                }
            }
            process.terminationHandler = { process in
                pipe.fileHandleForReading.readabilityHandler = nil
                let trailing = pipe.fileHandleForReading.readDataToEndOfFile()
                if !trailing.isEmpty { collected.append(trailing) }
                continuation.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    output: collected.string()
                ))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Registry value types usable from recipes.
public enum RecipeRegistryType: String, Sendable {
    case binary = "REG_BINARY"
    case dword = "REG_DWORD"
    case qword = "REG_QWORD"
    case string = "REG_SZ"
}

/// Thread-safe accumulator for streamed process output.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock(); defer { lock.unlock() }
        data.append(chunk)
    }

    func string() -> String {
        lock.lock(); defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
