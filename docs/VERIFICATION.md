# 0.3.1 preview verification

BrighterDisplay for Mac 0.3.1 is the first downloadable public preview. It renames the original XDRLift 0.3.0 application. The rename changes display strings, bundle/executable names and version metadata; core gamma, brightness-range and event-routing logic is unchanged. The stable bundle identifier `org.xdrlift.app` and `xdrMaximumGain` preference key remain to preserve app identity and saved cap continuity where macOS permits.

## Evidence inherited from XDRLift 0.3.0

The original build was accepted on an Apple M3 Max MacBook Pro, macOS 27.0 (26A5406e), with Swift 6.4. Its executable SHA-256 was `a5cdaa2ae4d46b4e36179bfd62959869300e8cd62c2f76d7e305e106b6e116f2`. This is provenance for the earlier build, **not the renamed release's hash**; use the release SHA256SUMS for downloads.

- 71 core assertions plus rejection scenarios: baseline ownership, non-compounding scaling, exact/clipped read-back, reset retries, cap changes, saturation and immediate down, fine steps, event filtering, paired releases, stale-command cancellation and overlapping suspension reasons.
- Bounded live controller calls: normal-to-extended and reverse transitions, repeated commands during preparation, cancellation, simulated lock/unlock without resuming extension, restoration of starting hardware brightness and both captured display tables.
- Native UI: continuous slider, reset, active cap reduction, cap raising without brightness increase and cap persistence across relaunch.
- Owner observation: desktop visibly brightens; physical brightness keys work after removing a stale macOS approval and approving that final installed build. This is owner acceptance, not an instrumented full physical-key matrix. No post-approval counter snapshot is claimed.
- Built-in display eligible and attached external SDR display excluded.

## Renamed 0.3.1 candidate

Core tests, compilation, bundle metadata, signature verification and package-content checks are repeated for the renamed candidate. CI builds it separately. It has not replaced the accepted installed 0.3.0 app. **Physical-key acceptance and native UI acceptance have not been repeated on the renamed binary.** A changed ad-hoc code hash can require a fresh control-access approval even with the same bundle identifier.

## Still unverified on physical hardware

- Renamed-binary installation/approval and physical key behavior; full hold/repeat/fine-step/boundary matrix and permission revocation while active.
- Actual sleep, display sleep, lock, unlock, session switching and wake recovery.
- Spaces/fullscreen transitions; display attach/detach and mirroring.
- Other gamma/color utilities, changing headroom, thermal stress, injected hardware failures and crash recovery.
- A clean install on another Mac, other macOS versions, and the downloaded-app Gatekeeper flow.

CI validates core logic and compilation; it cannot certify panel behavior or luminance. Gamma read-back verifies transactions. No nits were measured. This remains a prerelease with incomplete hardware acceptance.
