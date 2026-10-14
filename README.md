# XDRLift

[![CI](https://github.com/ryderderder/XDRLift/actions/workflows/ci.yml/badge.svg)](https://github.com/ryderderder/XDRLift/actions/workflows/ci.yml)

A free, open-source macOS menu-bar app that extends the built-in brightness keys into available XDR headroom. Original Swift/AppKit implementation, MIT licensed. No license keys, paid features, account, telemetry, screen capture, login item, or daemon.

**0.3.0 is an experimental preview.** Desktop brightening and physical brightness keys have been confirmed on one M3 Max MacBook Pro running macOS 27. It has not completed the hardware compatibility and lifecycle test matrix. See [verification and limitations](docs/VERIFICATION.md) before use.

## Download and install

Get the **arm64-PREVIEW.zip** and **SHA256SUMS** from [Releases](https://github.com/ryderderder/XDRLift/releases). The source ZIP is also available there.

1. Verify the download with `shasum -a 256 XDRLift-0.3.0-arm64-PREVIEW.zip` and compare with SHA256SUMS.
2. Unzip and move XDRLift.app into your Applications folder before approving permissions. Open the app; its sun icon appears in the menu bar.
3. Open **Keyboard settings / Set up brightness keys** and grant control access yourself in System Settings. On macOS 27 this is **Privacy & Security → Device Control and Data Access**; earlier versions call it **Accessibility**.
4. Check that the app reports **Access: approved · tap: enabled**, then use Brightness Up and Down.

This preview is **ad-hoc signed, not Developer ID signed or notarized**. macOS may block a downloaded app; only proceed through its normal, user-controlled approval UI if you trust this release. XDRLift never disables Gatekeeper or changes your permissions. Building from source is another option.

If the OS switch is on but the app reports missing/out-of-date access, remove the stale XDRLift entry, add the final installed app again, and enable it. A changed ad-hoc build may require this again. Finish replacing the app before granting access. See [signing and permissions](docs/SIGNING.md).

## Use

Brightness Up continues past normal hardware maximum into extended brightness; Down returns through the same range. **There is no separate boost switch.** Option–Shift uses quarter-size increments. The menu slider works without control-access approval.

The **XDR maximum** field saves a ceiling on relative requested gain, initially **1.50×**. It accepts 1.00–16.00×, always limited by available headroom. A 1.00× cap keeps output in the normal range. Raising the cap does not brighten the screen; lowering it clamps an active request immediately. Held keys cannot accumulate a hidden request above the cap. These values are **not measured nits**.

**Normal / Reset** removes extended output and keeps approved keys ready. **Pause brightness keys** returns control to macOS. Only the cap persists: extended brightness never resumes automatically at launch, wake, or unlock. Quit attempts to restore the owned color table and warns if restoration cannot be verified.

## Requirements and tradeoffs

- Apple silicon MacBook Pro with an eligible built-in XDR display. External and mirrored displays are excluded.
- macOS 13+ is the build deployment target; runtime testing is currently limited to macOS 27 on M3 Max. Compatibility with older releases is unverified.
- Available EDR headroom, a working Metal device, and the optional system brightness adapter. Unsupported configurations fail back to normal operation.
- Control-access approval for physical keys. No Screen Recording permission is required.

The backend combines a tiny EDR Metal surface with gamma scaling derived from a captured baseline. It can increase battery use and heat, clip HDR highlights, and change color accuracy. Reset for color-critical/HDR work. Avoid combining it with other gamma utilities. Thermal protections, display presets, automatic brightness, True Tone, and Night Shift are not changed. Headroom is relative; no optical luminance was measured and no sustained 1,600-nit desktop is promised.

The app attempts restoration on reset, pause, quit, sleep, lock, inactive sessions, display changes, permission loss, serious/critical thermal state, and detected backend errors. Some of these recovery paths still need physical testing. A crash, forced kill, OS fault, or lost display can prevent in-process restoration. See [backend details](docs/BACKENDS.md).

## Build and test

Install Apple's Command Line Tools or Xcode with **Swift 6.4 or newer**, then run on macOS:

```sh
./scripts/test.sh
./scripts/build.sh
open dist/XDRLift.app
```

The build uses one compiler invocation, Swift 5 language mode, a local module cache, and an arm64/macOS 13 deployment target. No package dependencies or network downloads are required. The tested local toolchain is Swift 6.4. CI uses the Xcode 27 runner; older Swift toolchains may hit a type-checking limit in the gamma comparison. Builds are repeatable from source, but not guaranteed byte-identical across SDK/compiler versions.

`./scripts/package.sh` tests, builds, and produces app/source ZIPs plus SHA-256 checksums from an explicit file manifest. It does not install or publish anything. CI tests the dependency-free core and builds/verifies a separate app; it does not manipulate a display or prove physical keyboard behavior.

`./scripts/diagnose.sh` is an optional read-only display diagnostic. Its output is local and should be reviewed before sharing. The development `--smoke-test` option changes display state temporarily: run it only deliberately, with no other instance active. It exercises controller calls, not physical events. Shell-launched permission status may differ from the normally launched GUI.

## Contribute and update

Report bugs and ideas in [Issues](https://github.com/ryderderder/XDRLift/issues). To change code, fork the repository and open a pull request. The maintainer reviews the change and tests before deciding whether to merge; publishing an app release is a separate step. See [CONTRIBUTING.md](CONTRIBUTING.md).

**0.3.0 has no automatic updater.** Updates are manual. A future release is planned to use Sparkle with signed release downloads and user-controlled update settings; ordinary repository commits will not install software. See the [update design](docs/UPDATES.md).

[MIT license](LICENSE) · [Attribution](ATTRIBUTION.md) · [Changelog](CHANGELOG.md) · [Security](SECURITY.md)
