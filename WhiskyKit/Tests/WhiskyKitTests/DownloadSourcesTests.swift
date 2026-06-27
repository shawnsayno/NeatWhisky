//
//  DownloadSourcesTests.swift
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
@testable import WhiskyKit

/// Covers the M9 mirror-aware download layer, especially the failover ordering
/// and the China mirrors added for the large Wine assets.
///
/// Uses the `Testing` framework (bundled with swift.org / Xcode toolchains) so
/// `swift test` runs without a full Xcode install (which XCTest would require on
/// macOS).
@Suite struct DownloadSourcesTests {
    private static let regionKey = "neatwhisky.preferredMirrorRegion"

    private func withPreferredRegion(_ region: MirrorRegion, _ body: () -> Void) {
        let saved = UserDefaults.standard.string(forKey: Self.regionKey)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: Self.regionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.regionKey)
            }
        }
        DownloadSources.preferredRegion = region
        body()
    }

    @Test func everyAssetHasAtLeastOneMirror() {
        for asset in DownloadAsset.allCases {
            #expect(!DownloadSources.mirrors(for: asset).isEmpty, "\(asset) has no mirror")
        }
    }

    @Test func wineLibrariesHasOfficialAndChinaMirror() {
        let regions = DownloadSources.mirrors(for: .wineLibraries).map(\.region)
        #expect(regions.contains(.official))
        #expect(regions.contains(.china)) // Wine tarball needs a China mirror (M9 gap)
    }

    @Test func wineVersionManifestHasChinaMirror() {
        let regions = DownloadSources.mirrors(for: .wineVersionManifest).map(\.region)
        #expect(regions.contains(.china))
    }

    @Test func allMirrorURLsAreHTTPS() {
        for asset in DownloadAsset.allCases {
            for mirror in DownloadSources.mirrors(for: asset) {
                #expect(mirror.url.scheme == "https", "\(mirror.name) must be https")
            }
        }
    }

    @Test func orderedMirrorsPutsPreferredRegionFirst() {
        withPreferredRegion(.china) {
            let ordered = DownloadSources.orderedMirrors(for: .steamInstaller)
            #expect(ordered.first?.region == .china)
            // Failover keeps every mirror, just reordered.
            #expect(
                Set(ordered.map(\.url)) ==
                Set(DownloadSources.mirrors(for: .steamInstaller).map(\.url))
            )
        }
    }

    @Test func orderedMirrorsFallsBackWhenPreferredRegionAbsent() {
        // wineLibraries has no `.global` mirror; ordering must still be complete.
        withPreferredRegion(.global) {
            let all = DownloadSources.mirrors(for: .wineLibraries)
            let ordered = DownloadSources.orderedMirrors(for: .wineLibraries)
            #expect(ordered.count == all.count)
            #expect(ordered.first != nil)
        }
    }
}
