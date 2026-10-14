# Changelog

## 0.3.0 — capped keyboard preview

- One continuous brightness-key range from normal hardware brightness into available XDR headroom, with a menu slider fallback and immediate Normal / Reset.
- Persistent maximum requested gain, initially 1.50×. Caps apply to key repeats, slider transitions, and renderer output. Lowering clamps immediately; raising does not increase brightness.
- Paired brightness-event routing, cancellation of queued commands on reset/cap changes, and fail-closed handling when the event tap stops.
- In-memory brightness-event counters and effective control-access/tap status. Ordinary key text is never recorded.
- Baseline-derived gamma ownership and restoration, capability gating, lifecycle suspension and thermal checks.
- 71 core assertions pass. Live controller restoration and native UI cap behavior were verified. The owner confirmed visible desktop brightening and physical brightness-key operation after refreshing approval for the final build.
- Public source, MIT attribution, build/package scripts and CI. Ad-hoc signed arm64 preview; not notarized. Full hardware/lifecycle compatibility remains unverified.

0.1.0 and 0.2.0 were local development milestones and were not public releases.
