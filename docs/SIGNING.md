# Signing and control-access approval

The 0.3.0 preview uses `codesign --sign -`: an ad-hoc signature without a signing certificate or Team Identifier. It is not notarized. Its bundle signature can be valid while macOS still refuses a previously saved control-access grant.

Ad-hoc identity is tied to a particular build's code hash. Keeping the app name, bundle identifier and installation path does not keep that hash stable. During testing, a stale saved approval failed to match a newer executable even though the OS switch appeared on. Removing the stale entry and approving the final installed app restored physical-key operation.

Install the final app before granting access. If XDRLift reports missing or out-of-date access, remove its stale entry in System Settings, add the installed app again, and enable it yourself. On macOS 27 the pane is Privacy & Security → Device Control and Data Access; on earlier systems it is called Accessibility. Confirm the normally launched GUI reports access approved and tap enabled. A shell-launched helper's trust status is not authoritative for GUI key access.

For future builds, a stable Developer ID signing identity and compatible designated requirement are the normal route to recognizing updates from the same developer. This does not itself grant control access or guarantee that every subsystem retains a grant; test an actual upgrade. Never use identifier-only requirements, TCC edits/resets, transplanted signatures, private entitlements, or weakened OS protections to avoid approval.

Sparkle's archive-signing key is a separate trust mechanism. It authenticates update downloads; it does not replace Apple code identity or make an ad-hoc app retain privacy grants. See [the update design](UPDATES.md).

Read-only checks for any local candidate:

```sh
codesign --verify --strict /path/to/XDRLift.app
codesign -d -r- /path/to/XDRLift.app
codesign -dv --verbose=4 /path/to/XDRLift.app
shasum -a 256 /path/to/XDRLift.app/Contents/MacOS/XDRLift
```

References: [Apple Code Signing Requirement Language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html), [Apple TN2206](https://developer.apple.com/library/archive/technotes/tn2206/_index.html), [Inside Code Signing Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
