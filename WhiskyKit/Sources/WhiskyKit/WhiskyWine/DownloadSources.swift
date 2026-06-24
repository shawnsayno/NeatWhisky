//
//  DownloadSources.swift
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

/// A geographic / preference grouping for a download mirror.
public enum MirrorRegion: String, Sendable, Codable, CaseIterable {
    /// Upstream / global default (GitHub, Steam CDN, …).
    case official
    /// A mainland-China-friendly mirror.
    case china
    /// An additional global mirror.
    case global

    public func pretty() -> String {
        switch self {
        case .official: return "Official / 官方源"
        case .china: return "China Mirror / 国内镜像"
        case .global: return "Global Mirror / 海外镜像"
        }
    }
}

/// A single download endpoint for an asset.
public struct DownloadMirror: Sendable, Equatable {
    public let name: String
    public let region: MirrorRegion
    public let url: URL

    public init(name: String, region: MirrorRegion, url: URL) {
        self.name = name
        self.region = region
        self.url = url
    }
}

/// An asset NeatWhisky may need to fetch over the network.
public enum DownloadAsset: Sendable, CaseIterable {
    /// The bundled Wine `Libraries` tarball (Wine 11.x + DXVK).
    case wineLibraries
    /// The remote Wine version manifest.
    case wineVersionManifest
    /// The latest official Steam client installer (`SteamSetup.exe`).
    case steamInstaller
    /// The `winetricks` script (used for CJK fonts, etc.).
    case winetricks
}

public enum DownloadError: Error {
    case noMirrors
    case allMirrorsFailed(underlying: Error?)
    case badResponse(Int)
}

/// Centralized, mirror-aware download configuration with automatic failover.
///
/// This unifies every network asset NeatWhisky needs (Wine build, Steam
/// installer, winetricks) behind one switchable-mirror abstraction. The default
/// region is `official`; users can prefer a China/global mirror, and downloads
/// transparently fall back to the next mirror on failure.
public enum DownloadSources {
    static let preferredRegionKey = "neatwhisky.preferredMirrorRegion"

    /// The mirror region to try first. Backed by `UserDefaults` so it is
    /// thread-safe and persists across launches (surfaced in settings in M10).
    public static var preferredRegion: MirrorRegion {
        get {
            let raw = UserDefaults.standard.string(forKey: preferredRegionKey) ?? ""
            return MirrorRegion(rawValue: raw) ?? .official
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredRegionKey)
        }
    }

    private static let releaseBase =
        "https://github.com/shawnsayno/NeatWhisky/releases/latest/download"
    private static let winetricksRaw =
        "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"

    /// The full catalog of mirrors for a given asset, in catalog order.
    public static func mirrors(for asset: DownloadAsset) -> [DownloadMirror] {
        switch asset {
        case .wineLibraries:
            return makeMirrors([
                (.official, "GitHub Releases", "\(releaseBase)/Libraries.tar.gz")
            ])
        case .wineVersionManifest:
            return makeMirrors([
                (.official, "GitHub Releases", "\(releaseBase)/WhiskyWineVersion.plist")
            ])
        case .steamInstaller:
            return makeMirrors([
                (.official, "Steam CDN (Fastly)",
                 "https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe"),
                (.global, "Steam CDN (Akamai)",
                 "https://media.steampowered.com/client/installer/SteamSetup.exe"),
                (.china, "Steam CDN (steamstatic)",
                 "https://cdn.steamstatic.com/client/installer/SteamSetup.exe")
            ])
        case .winetricks:
            return makeMirrors([
                (.official, "winetricks (GitHub)", winetricksRaw),
                (.china, "winetricks (ghproxy)", "https://ghproxy.net/\(winetricksRaw)")
            ])
        }
    }

    /// Mirrors ordered so that the user's `preferredRegion` is tried first,
    /// followed by the remaining mirrors in catalog order (failover).
    public static func orderedMirrors(for asset: DownloadAsset) -> [DownloadMirror] {
        let all = mirrors(for: asset)
        let preferred = preferredRegion
        let head = all.filter { $0.region == preferred }
        let tail = all.filter { $0.region != preferred }
        return head + tail
    }

    /// Download an asset, trying each mirror in order until one succeeds.
    /// - Parameter progress: optional `0...1` progress callback.
    /// - Returns: a temporary file URL holding the downloaded data.
    @discardableResult
    public static func download(
        _ asset: DownloadAsset,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let mirrors = orderedMirrors(for: asset)
        guard !mirrors.isEmpty else { throw DownloadError.noMirrors }

        var lastError: Error?
        for mirror in mirrors {
            do {
                return try await Downloader.download(from: mirror.url, progress: progress)
            } catch {
                Logger.wineKit.warning(
                    "Mirror `\(mirror.name)` failed for asset, trying next: \(error.localizedDescription)"
                )
                lastError = error
                continue
            }
        }
        throw DownloadError.allMirrorsFailed(underlying: lastError)
    }

    private static func makeMirrors(
        _ specs: [(MirrorRegion, String, String)]
    ) -> [DownloadMirror] {
        specs.compactMap { region, name, urlString in
            guard let url = URL(string: urlString) else { return nil }
            return DownloadMirror(name: name, region: region, url: url)
        }
    }
}

/// A small `URLSessionDownloadDelegate` that bridges a download task to
/// async/await, reporting progress and surfacing HTTP errors.
private final class Downloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<URL, Error>?
    private let progress: (@Sendable (Double) -> Void)?
    private let destination: URL

    private init(progress: (@Sendable (Double) -> Void)?) {
        self.progress = progress
        self.destination = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        super.init()
    }

    static func download(
        from url: URL, progress: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        let delegate = Downloader(progress: progress)
        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            continuation?.resume(throwing: DownloadError.badResponse(http.statusCode))
            continuation = nil
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            continuation?.resume(returning: destination)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
