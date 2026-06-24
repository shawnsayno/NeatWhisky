//
//  GraphicsStack.swift
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

/// Describes the graphics translation stack NeatWhisky ships.
///
/// NeatWhisky deliberately uses a **fully open-source** stack so the whole app
/// can be freely redistributed under GPL-3.0:
///
/// - **Wine** translates the Windows API.
/// - **DXVK** translates Direct3D 9/10/11 → Vulkan (enabled by default).
/// - **MoltenVK** translates Vulkan → Apple Metal (bundled with Wine).
///
/// It explicitly does **not** bundle Apple's Game Porting Toolkit (GPTK) or any
/// CrossOver components, which carry redistribution restrictions.
public enum GraphicsStack {
    /// Whether DXVK is enabled by default for newly created bottles.
    public static let dxvkEnabledByDefault = true

    /// Whether the build is allowed to bundle non-open-source components.
    /// Always `false` for NeatWhisky.
    public static let allowsProprietaryComponents = false

    public static let components = [
        "Wine (WineHQ / Wine Staging)",
        "DXVK (Direct3D → Vulkan)",
        "MoltenVK (Vulkan → Metal)"
    ]
}
