# Changelog

## 0.3.1 — BrighterDisplay for Mac preview

- Renamed the app and public project from XDRLift to BrighterDisplay for Mac. Kept `org.xdrlift.app` and the saved-cap preference key. This separately built candidate has no new display-control logic.
- Repeated core/build/signature/package checks; physical acceptance applies to the original 0.3.0 binary and has not been repeated on this renamed binary.

## 0.3.0 — local capped keyboard preview

- One continuous brightness-key range from normal hardware brightness into available XDR headroom, with a menu slider fallback and immediate Normal / Reset.
- Persistent maximum requested gain, initially 1.50×. Caps apply to key repeats, slider transitions, and renderer output. Lowering clamps immediately; raising does not increase brightness.
- Paired brightness-event routing, cancellation of queued commands on reset/cap changes, and fail-closed handling when the event tap stops.
- In-memory brightness-event counters and effective control-access/tap status. Ordinary key text is never recorded.
- Baseline-derived gamma ownership and restoration, capability gating, lifecycle suspension and thermal checks.
- 71 core assertions pass. Live controller restoration and native UI cap behavior were verified. The owner confirmed visible desktop brightening and physical brightness-key operation after refreshing approval for the final build.
- Ad-hoc signed arm64 local preview; not notarized. Full hardware/lifecycle compatibility remains unverified.

0.1.0 and 0.2.0 were local development milestones and were not public releases.
