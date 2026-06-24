//
//  WhiskyWineSource.swift
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

/// Centralized, mirror-ready configuration for where NeatWhisky fetches its
/// bundled Wine build and the version manifest.
///
/// This replaces the hardcoded `data.getwhisky.app` URLs from upstream Whisky.
/// NeatWhisky ships a modern Wine Staging 11.x build instead of Wine 7.7.
///
/// IMPORTANT: The tarball MUST untar to the application-support folder producing
/// `Libraries/Wine/bin/...` and `Libraries/WhiskyWineVersion.plist`, matching the
/// structure expected by `WhiskyWineInstaller.install(from:)`. Producing and
/// hosting this tarball (Wine 11.x + DXVK + MoltenVK, full open-source stack, no
/// GPTK) is an infrastructure task tracked in `docs/build-plan.md`. The default
/// URLs below point at NeatWhisky's own GitHub release assets.
public enum WhiskyWineSource {
    /// A named download mirror. M9 lets users pick or override these to suit
    /// their network (e.g. official vs. a China-friendly mirror).
    public struct Mirror: Sendable, Equatable {
        public let name: String
        public let librariesTarball: URL
        public let versionPlist: URL

        public init(name: String, librariesTarball: URL, versionPlist: URL) {
            self.name = name
            self.librariesTarball = librariesTarball
            self.versionPlist = versionPlist
        }
    }

    private static let defaultTarballString =
        "https://github.com/shawnsayno/NeatWhisky/releases/latest/download/Libraries.tar.gz"
    private static let defaultVersionPlistString =
        "https://github.com/shawnsayno/NeatWhisky/releases/latest/download/WhiskyWineVersion.plist"

    /// Ordered list of built-in mirrors; the first usable one is the default.
    /// User-selectable overrides and additional (e.g. mainland-China) mirrors
    /// are layered on top of this in M9.
    public static let mirrors: [Mirror] = {
        guard let tar = URL(string: defaultTarballString),
              let plist = URL(string: defaultVersionPlistString) else {
            return []
        }
        return [Mirror(name: "GitHub Releases", librariesTarball: tar, versionPlist: plist)]
    }()

    /// The mirror currently in effect.
    public static var active: Mirror? {
        mirrors.first
    }

    /// URL of the Wine `Libraries` tarball to download and install.
    public static var librariesTarballURL: URL? {
        active?.librariesTarball
    }

    /// URL of the remote version manifest used to decide whether to update.
    public static var versionPlistURL: URL? {
        active?.versionPlist
    }
}
