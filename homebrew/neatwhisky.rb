# NeatWhisky Homebrew Cask (template).
#
# Place this file in a tap repo (e.g. `shawnsayno/homebrew-tap` as
# `Casks/neatwhisky.rb`) so users can install with:
#
#   brew install --cask shawnsayno/tap/neatwhisky
#
# On each release, update `version` and `sha256` (the Release workflow can be
# extended to do this automatically via HOMEBREW_TAP_TOKEN).
cask "neatwhisky" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/shawnsayno/NeatWhisky/releases/download/v#{version}/NeatWhisky-v#{version}.dmg",
      verified: "github.com/shawnsayno/NeatWhisky/"
  name "NeatWhisky"
  desc "One-click Steam on macOS, built on Whisky/Wine (fully open-source stack)"
  homepage "https://github.com/shawnsayno/NeatWhisky"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "NeatWhisky.app"

  zap trash: [
    "~/Library/Application Support/app.neatwhisky",
    "~/Library/Caches/app.neatwhisky",
    "~/Library/Containers/app.neatwhisky",
    "~/Library/Logs/app.neatwhisky",
    "~/Library/Preferences/app.neatwhisky.plist",
  ]
end
