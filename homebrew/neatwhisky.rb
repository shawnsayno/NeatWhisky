# NeatWhisky Homebrew Cask (template).
#
# Place this file in a tap repo (e.g. `shawnsayno/homebrew-tap` as
# `Casks/neatwhisky.rb`) so users can install with:
#
#   brew install --cask shawnsayno/tap/neatwhisky
#
# On each release the Release workflow updates `version` and `sha256`
# automatically when the `HOMEBREW_TAP_TOKEN` secret (and optional
# `HOMEBREW_TAP_REPO` variable) are configured. The values below are the
# initial template/placeholders.
cask "neatwhisky" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/shawnsayno/NeatWhisky/releases/download/v#{version}/NeatWhisky-v#{version}.dmg",
      verified: "github.com/shawnsayno/NeatWhisky/"
  name "NeatWhisky"
  desc "One-click Steam, built on Whisky/Wine (fully open-source graphics stack)"
  homepage "https://github.com/shawnsayno/NeatWhisky"

  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "NeatWhisky.app"

  # Release DMG is unsigned/unnotarized for now (Developer ID signing is
  # deferred). Homebrew quarantines cask artifacts, which makes Gatekeeper kill
  # the app on first launch; strip it post-install so `brew install --cask`
  # launches without --no-quarantine (which Homebrew is deprecating).
  postflight do
    system_command "/usr/bin/xattr",
                   args:         ["-dr", "com.apple.quarantine", "/Applications/NeatWhisky.app"],
                   must_succeed: false
  end

  zap trash: [
    "~/Library/Application Support/app.neatwhisky",
    "~/Library/Caches/app.neatwhisky",
    "~/Library/Containers/app.neatwhisky",
    "~/Library/Logs/app.neatwhisky",
    "~/Library/Preferences/app.neatwhisky.plist",
  ]
end
