# Release process

A commit is not a release. Ordinary CI never publishes a binary or promotes an update feed.

1. Review the complete source diff, license provenance, tracked file list and Git history. Exclude private material and unrelated files. Keep `.release-files` explicit and current.
2. Run `./scripts/test.sh`, `./scripts/build.sh`, and require successful CI for the intended commit. Inspect the app signature and version.
3. Complete and record the relevant hardware checks in VERIFICATION.md. Do not substitute controller calls for physical keys or luminance measurement. If shipping a preview with known gaps, state them prominently and mark it a prerelease.
4. Run `./scripts/package.sh`. This produces allowlisted source and app ZIPs plus SHA256SUMS under dist. It does not install or publish.
5. For an already accepted frozen app, use `./scripts/package.sh --existing-app /path/to/XDRLift.app --expected-sha EXECUTABLE_SHA256`. This tests the core and verifies the existing bundle without rebuilding or re-signing it. The caller must establish that its source and metadata match the release; the SHA check alone cannot establish provenance.
6. Inspect both archives. Verify the app contains only its executable, Info.plist and code-signature resources for this dependency-free version. Verify the source ZIP matches the manifest. Confirm no preferences, logs, machine paths, credentials or unrelated files are included.
7. Create a versioned GitHub prerelease/release for the reviewed commit. Upload the app ZIP, source ZIP and SHA256SUMS. Download the public assets and verify all hashes and the extracted bundle signature. Do not replace assets silently; issue a new version when code changes.
8. Keep the installed acceptance-test app unchanged until the user chooses to upgrade. For ad-hoc updates, explain possible control-access reapproval. Automatic-update promotion requires the separate design and tests in UPDATES.md.

The 0.3.0 preview uses the frozen executable identified in VERIFICATION.md. Documentation and repository hygiene were prepared after acceptance without changing its app bytes. CI builds are verification candidates, not the hardware-accepted release asset.
