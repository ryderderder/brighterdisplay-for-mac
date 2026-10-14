# Contributing

Bugs and feature ideas belong in Issues. Include the app version, macOS version, Mac/display model, expected behavior and reproducible steps. Separate what you observed from controller tests or assumptions. Remove personal paths and unrelated data before sharing diagnostics.

For a code change:

1. Fork the repository and make a focused branch.
2. Keep changes original and compatible with MIT; document any reused material and preserve required notices.
3. Run `./scripts/test.sh` and `./scripts/build.sh` on macOS. Add meaningful core tests for changed safety/interaction behavior. Do not run display-changing tests on an unattended machine.
4. Open a pull request explaining the problem, resulting behavior, validation and remaining hardware limitations.
5. The maintainer reviews the code and CI, requests changes if needed, and decides whether to merge. Contributions do not merge automatically. A public binary release is a separate maintainer decision after verification.

Only the cap persists. Preserve baseline ownership, immediate reset, cap enforcement and safe fallback. No paid gates, telemetry, captures, privilege escalation, security bypass or automatic login agent. Never change a user's permissions, signing setup, or working installation as part of a test without authorization.

CI runs core tests and a build with read-only access. It does not certify physical key delivery, lifecycle recovery or measured brightness. Keep those claims explicit. See [verification](docs/VERIFICATION.md) and [release process](docs/RELEASING.md).

The project names its maintainer in CODEOWNERS to request reviews. CODEOWNERS and this document are not branch protection: see [governance](docs/GOVERNANCE.md) for actual versus recommended controls.
