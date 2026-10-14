# Automatic-update design

Status: proposed for a subsequent release. **0.3.1 contains no updater, feed, update key, background network checks, or automatic installation.** The original accepted XDRLift 0.3.0 installation remains unchanged during this work. The first updater-enabled build will require a manual installation.

Use the established [Sparkle 2 framework](https://sparkle-project.org/documentation/) instead of a custom downloader that replaces executables. Pin the framework version and verify its official distribution and license before integration. Embed the public Ed25519 key in the app, serve a stable HTTPS appcast, and publish versioned signed archives as GitHub release assets. Consider signed feeds and validation before extraction with the selected Sparkle version. A checksum alone is not publisher authentication.

Two trust checks have different purposes:

- Sparkle's Ed25519 signature proves that an update archive was authorized by the holder of the corresponding private key. The public key is embedded in the app; private material must remain outside source, release assets and untrusted CI.
- Apple code signing identifies the application to macOS. Developer ID signing/notarization improves downloaded-app distribution and stable update identity. It does not grant Accessibility access. Ad-hoc signed updates can be authenticated by Sparkle while still requiring the user to refresh macOS control access.

Sparkle is free and does not require purchasing Developer ID to research or implement archive authentication. Apple's Developer Program currently costs US$99/year or local currency where available; do not enroll or incur a charge without approval. An ad-hoc update channel needs explicit reapproval guidance and upgrade tests. Do not promise seamless permissions or silently install such updates.

## Intended user behavior

Provide Check for Updates plus a user-controlled automatic-check setting. Keep unattended installation off initially; ask separately before enabling it. Do not send a system profile or telemetry. Explain that checking contacts the release/feed host. Use a stable channel by default and make preview participation explicit.

Before installing, stop accepting brightness commands, cancel queued changes, restore owned gamma, and verify restoration. Abort/defer installation if restoration fails. Relaunch at normal brightness, preserve the saved cap, and verify permissions/tap before rearming. Never grant permissions or resume extended brightness on behalf of the user.

## Release workflow

1. Run read-only CI on commits and pull requests. Do not publish binaries or appcasts from ordinary commits or untrusted pull-request code.
2. Select an explicit version after review and successful CI. Build in isolation and complete the hardware acceptance matrix.
3. Sign the app appropriately, notarize if available, then package the final bytes. Sign that immutable archive using Sparkle's approved key handling. Do not modify bytes after signing.
4. Test upgrades, rejected tampered archives, wrong-key signatures, unavailable feeds, rollback/downgrade handling, unsupported OS versions, interrupted downloads, installation cancellation, gamma reset failures, cap persistence, and control-access continuity on real hardware.
5. Publish the versioned release assets, verify public downloads and their signatures, then promote the HTTPS appcast. Releases and feed promotion remain maintainer actions, separate from merge.

GitHub Pages could host the appcast; no Pages deployment or persistent access has been enabled. No credential-bearing release workflow is active. Existing CI has read-only repository permissions and no release secrets.

## Decisions before activation

The maintainer must approve creating and storing an Ed25519 signing key and decide its custody/backup strategy. Reuse an authorized Developer ID identity if available, or explicitly choose an ad-hoc channel with reapproval limitations. Any new Apple credentials, enrollment, CI secrets, protected environment or Pages access must be approved at the point of setup. Do not put placeholder keys in a shipping app or publish an unsigned appcast as update-ready.

References: [Sparkle setup](https://sparkle-project.org/documentation/), [publishing](https://sparkle-project.org/documentation/publishing/), [customization](https://sparkle-project.org/documentation/customization/), [Apple enrollment](https://developer.apple.com/programs/enroll/).
