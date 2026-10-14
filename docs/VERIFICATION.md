# 0.3.0 verification record

The release app is the same frozen build accepted on an Apple M3 Max MacBook Pro, macOS 27.0 (26A5406e), built with Swift 6.4. Its executable SHA-256 is:

```
a5cdaa2ae4d46b4e36179bfd62959869300e8cd62c2f76d7e305e106b6e116f2
```

## Completed

- 71 core assertions plus rejection scenarios: baseline ownership, non-compounding scaling, exact/clipped read-back, reset retries, cap changes, saturation and immediate down, fine steps, brightness-event filtering, paired release routing, stale-command cancellation, overlapping suspension reasons.
- Bounded live controller calls: normal-to-extended and reverse transitions, repeated commands during preparation, cancellation, simulated lock/unlock without resuming extension, and restoration of starting hardware brightness and both captured display tables.
- Native UI: continuous slider, reset, active cap reduction, cap raising without brightness increase, cap persistence across relaunch.
- Owner observation: desktop visibly brightens; physical brightness keys work after removing a stale macOS approval and approving the final installed build. This is owner acceptance, not an instrumented full physical-key test matrix. No post-approval counter snapshot is claimed.
- Built-in display eligible; the attached external SDR display excluded. Ad-hoc bundle signature verifies.

## Still unverified on physical hardware

- Full hold/repeat/fine-step/boundary matrix and permission revocation while active.
- Actual sleep, display sleep, lock, unlock, session switching and wake recovery.
- Spaces and fullscreen transitions; display attach/detach and mirroring.
- Other gamma/color utilities, changing headroom and thermal stress, injected hardware failures and crash recovery.
- A clean install on another Mac and other supported macOS versions.
- Downloaded-app Gatekeeper and approval flow on a clean machine.

CI validates core logic and compilation. It cannot certify panel behavior or luminance. Gamma read-back is transaction verification, not an optical measurement. No nits have been measured. The release remains a prerelease until its broader test matrix is complete.
