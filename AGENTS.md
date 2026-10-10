# Patch Debug Flow

- Intent: keep `deploy` as a patch-only branch. Source analysis / patch generation use a **source tree** that is never the `deploy` working tree itself.
- Do not edit magpie source code directly on the `deploy` patch branch.
- Place deploy-ready patch files in `./patches` and update `./patches/series`.
- Do not store local-only agent docs or non-deploy artifacts in `./patches`.
- Do not write tests or run unit tests for this repo; only run syntax validation such as `gofmt -e` / `go vet` on patched files in the source tree.

## Source tree

Paths are relative to **this repository root** (the towry/magpie checkout).

Patches target **this fork's `origin/main`** (`towry/magpie` `main`). That is the same baseline CI uses.

CI (`.github/workflows/check-patches.yml`) checks out the patch branch, detaches to `origin/main`, restores `patches/` + `scripts/`, then runs `scripts/apply.sh` on that tree. Rebase and apply against that SHA only.

| Role | Path | Notes |
|------|------|--------|
| **Canonical** | `../magpie-main` | Detached worktree of **this repo's** `origin/main`. Create with `git fetch origin main && git worktree add --detach ../magpie-main origin/main`. |
| **Legacy compat** | `./magpie-main` | Gitignored in-repo worktree. Use only if it already exists and is this repo's `origin/main`. |
| Forbidden | `../magpie-upstream` or any `yetone/magpie` clone used as the apply baseline | Not the patch baseline. Ignore it even if present. |

Resolve:

1. `git fetch origin main` and record `git rev-parse origin/main`.
2. If `../magpie-main` exists and is this repo's `origin/main` → use it.
3. Else if `./magpie-main` exists and is this repo's `origin/main` → use it.
4. Else create the sibling worktree: `git worktree add --detach ../magpie-main origin/main`.
5. Say which path and which `origin/main` SHA you used.

Hard rules:

- **Never clone `yetone/magpie` as the patch baseline.** These patches are not against latest upstream unless `origin/main` has already been fast-forwarded to it.
- **Never use `../magpie-upstream`** as the source tree, even if an old orb left it there.
- Do not create `./magpie-main` unless a sibling worktree is impossible.
- Never commit or push from the source worktree. It is read-only analysis / apply scratch.
- Deploy patches land only under `./patches` on this repo (`deploy` branch).
- Done when deploy patches are updated in `./patches`.
