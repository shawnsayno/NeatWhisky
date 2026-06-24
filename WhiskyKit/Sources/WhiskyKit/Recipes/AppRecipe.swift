//
//  AppRecipe.swift
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

/// The health of an ``AppRecipe`` with respect to a bottle.
public enum RecipeStatus: Sendable, Equatable {
    /// The recipe is not relevant to this bottle (e.g. Steam isn't installed).
    case notApplicable
    /// The recipe is relevant but its fixes have not been applied yet.
    case notApplied
    /// All fixes are present and healthy.
    case applied
    /// Fixes were applied but have degraded and need re-applying
    /// (e.g. a Steam update reverted the `steamwebhelper` wrapper).
    case needsRepair(reason: String)
    /// Determining or applying the recipe failed.
    case error(String)
}

/// A single progress update emitted while a recipe runs.
public struct RecipeStep: Sendable, Equatable {
    /// Short title for the current stage (user-facing).
    public let title: String
    /// Optional longer detail line.
    public let detail: String?
    /// Overall progress in `0...1`, or `nil` when indeterminate.
    public let fraction: Double?

    public init(title: String, detail: String? = nil, fraction: Double? = nil) {
        self.title = title
        self.detail = detail
        self.fraction = fraction
    }
}

/// A progress reporter passed into long-running recipe operations.
public typealias RecipeProgress = @Sendable (RecipeStep) -> Void

public enum RecipeError: Error, LocalizedError {
    case resourceMissing(String)
    case stepFailed(String)

    public var errorDescription: String? {
        switch self {
        case .resourceMissing(let name):
            return "Required resource is missing: \(name)"
        case .stepFailed(let message):
            return message
        }
    }
}

/// A per-application fix bundle.
///
/// A recipe knows how to **detect** whether it applies to a bottle, **apply**
/// its fixes idempotently, **repair** fixes that were reverted, and report its
/// **status**. Recipes reuse `Wine.runWineProcess` and ``RecipeTools`` so they
/// stay small and declarative.
public protocol AppRecipe: Sendable {
    /// Stable identifier (e.g. `"steam"`).
    var id: String { get }
    /// User-facing name (e.g. `"Steam"`).
    var name: String { get }
    /// One-line summary of what this recipe fixes.
    var summary: String { get }

    /// Whether this recipe is relevant to the given bottle.
    func detect(in bottle: Bottle) async -> Bool

    /// Apply all fixes to the bottle. Must be idempotent.
    func apply(to bottle: Bottle, progress: RecipeProgress?) async throws

    /// Re-apply fixes that may have been reverted (e.g. by an app update).
    func repair(in bottle: Bottle, progress: RecipeProgress?) async throws

    /// Report the current health of the recipe for the bottle.
    func status(in bottle: Bottle) async -> RecipeStatus
}

public extension AppRecipe {
    /// By default, `repair` simply re-applies the recipe.
    func repair(in bottle: Bottle, progress: RecipeProgress?) async throws {
        try await apply(to: bottle, progress: progress)
    }
}

/// The registry of recipes NeatWhisky ships with.
public enum RecipeRegistry {
    public static let all: [any AppRecipe] = [
        SteamRecipe()
    ]

    /// All recipes that are relevant to the given bottle.
    public static func applicable(to bottle: Bottle) async -> [any AppRecipe] {
        var result: [any AppRecipe] = []
        for recipe in all where await recipe.detect(in: bottle) {
            result.append(recipe)
        }
        return result
    }
}
