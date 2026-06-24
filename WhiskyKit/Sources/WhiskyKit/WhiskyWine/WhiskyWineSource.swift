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

/// Convenience accessors for the bundled-Wine download endpoints.
///
/// This is a thin facade over the unified, mirror-aware ``DownloadSources``
/// (see M9). NeatWhisky ships a modern Wine Staging 11.x build instead of
/// Whisky's frozen Wine 7.7; the underlying mirrors are defined in
/// ``DownloadSources``.
///
/// IMPORTANT: The tarball MUST untar to the application-support folder producing
/// `Libraries/Wine/bin/...` and `Libraries/WhiskyWineVersion.plist`, matching the
/// structure expected by `WhiskyWineInstaller.install(from:)`.
public enum WhiskyWineSource {
    /// URL of the Wine `Libraries` tarball to download and install.
    public static var librariesTarballURL: URL? {
        DownloadSources.orderedMirrors(for: .wineLibraries).first?.url
    }

    /// URL of the remote version manifest used to decide whether to update.
    public static var versionPlistURL: URL? {
        DownloadSources.orderedMirrors(for: .wineVersionManifest).first?.url
    }
}
