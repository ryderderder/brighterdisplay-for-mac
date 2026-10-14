# Review and release control

The repository maintainer is @ryderderder. Contributors normally submit fork pull requests; the maintainer reviews and decides what lands. Merging code and publishing a tested application are separate decisions.

Included controls: CODEOWNERS requests the maintainer's review; CI uses a pinned checkout action, read-only contents permission, no signing secrets, and no auto-merge or release action. This repository does not include a workflow that installs software on users' Macs.

Branch protection and repository rules are settings, not established by these files. No ruleset is claimed to be enforced merely because this document exists. Until configured, the documented review process relies on the maintainer following it.

Recommended owner-approved settings: require the `core-and-build` check before merging, require conversations to be resolved, prevent force pushes/deletion on main, and restrict release/tag mutation to authorized maintainers. Consider protected release environments once a signing workflow exists. Review cost and access implications before enabling new settings.

For a sole maintainer, requiring the code owner's approval on every PR can block the maintainer's own PRs because authors cannot approve themselves. Practical choices are to require CI with owner-controlled merges, or add a trusted second reviewer before requiring independent approval universally. Do not create an undocumented broad bypass to hide this tradeoff.
