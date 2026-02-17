---
description: Sync fork with upstream plezy repo and rebase custom features on top
---

# Sync Upstream Plezy

This workflow syncs your fork (`origin`) with the original plezy repo (`upstream`) by rebasing your custom Prowlarr/qBit commits on top of the latest upstream changes.

## Prerequisites
- Remote `upstream` must point to `https://github.com/edde746/plezy.git`
- Remote `origin` must point to `https://github.com/Khaja-s/plezy-prowlarr.git`
- Working tree must be clean (no uncommitted changes)
- Working directory: `d:\Coding\plezy_prowlarr\plezy`

## Steps

1. Ensure working tree is clean
// turbo
```bash
git status
```
If there are uncommitted changes, stash or commit them first: `git stash` or `git add . && git commit -m "WIP"`

// turbo
2. Fetch the latest upstream changes
```bash
git fetch upstream
```

3. Check what new upstream commits exist (optional, for awareness)
// turbo
```bash
git log --oneline main..upstream/main
```

4. Set GIT_EDITOR to avoid the editor blocking the rebase, then rebase your custom commits on top of upstream/main
```bash
$env:GIT_EDITOR="true"; git rebase upstream/main
```

**IMPORTANT: During rebase, git's `--ours` / `--theirs` terminology is INVERTED:**
- `--ours` = the branch you're rebasing ONTO (i.e. upstream/main)
- `--theirs` = YOUR commits being replayed

**If conflicts occur, resolve them one at a time:**
- Run `git diff --name-only --diff-filter=U` to list conflicting files
- Use `Select-String -Path "<file>" -Pattern "<<<<|====|>>>>"` to find conflict markers (regular grep won't work due to Windows line endings)
- Open conflicting files and resolve the `<<<<<<<` / `=======` / `>>>>>>>` markers
- For each conflict, determine: do we keep BOTH sides (merge), or just one?
- Stage resolved files: `git add <file>`
- Continue with: `$env:GIT_EDITOR="true"; git rebase --continue`
- To abort if it's too messy: `git rebase --abort`

5. Force-push your rebased branch to your fork
```bash
git push origin main --force-with-lease
```

6. Verify the final structure looks correct
// turbo
```bash
git log --oneline -n 10
```
Your custom commits should appear at the top, directly above the latest `upstream/main` commit.

## Known Conflict Hotspots

Based on the first sync (2026-02-17), these files are likely to conflict again:

| File | Why | Resolution Strategy |
|------|-----|---------------------|
| `.github/workflows/build.yml` | Your commit `f68f8d9` removed build jobs; upstream keeps adding/updating them. This commit is essentially a no-op now. | Keep upstream's version (`git checkout --ours <file>` during rebase). Your build.yml commit may produce an empty diff — that's fine. |
| `lib/screens/settings/settings_screen.dart` | Your Prowlarr section lives here; upstream adds new settings (e.g., external player, confirm exit) near the same `_loadSettings()` method. | Merge BOTH sides: keep upstream's new settings AND your Prowlarr init lines. |
| `lib/services/settings_service.dart` | Your Prowlarr config keys are declared near upstream's growing list of setting keys. | Merge BOTH sides: keep upstream's new keys AND your Prowlarr keys. The conflict is usually just in the `static const String _key*` declaration block. |

## Custom Commits (as of 2026-02-17)

These are the commits that get replayed on each sync:

1. `Add Prowlarr integration for torrent search` — Adds models, client, search UI, and Prowlarr settings. Touches: `settings_screen.dart`, `settings_service.dart`, and creates new files under `lib/models/`, `lib/screens/downloads/`, `lib/services/`.
2. `Fix Prowlarr UI, add qBittorrent status tab` — Adds qBit tab to downloads, qBit models/client, qBit settings. Touches: `settings_screen.dart`, `settings_service.dart`, and creates new files.
3. `Fix qBit auth: login first and use SID cookie` — Auth fix in qBit client. Touches: `lib/services/qbittorrent_client.dart`.

> **Tip**: Commits 1 and 2 are the most conflict-prone because they touch the same settings files as upstream. Commit 3 rarely conflicts because it only edits a file unique to your fork.

## After Syncing
- Your custom commits will be replayed on top of the latest upstream
- Test the app to make sure nothing broke from the upstream changes
- If upstream adds new settings near yours, expect merge conflicts in `settings_screen.dart` and `settings_service.dart`

## Emergency Rollback
If something goes wrong after pushing:
```bash
git reflog                     # find the commit hash before the rebase
git reset --hard <hash>        # reset to that state
git push origin main --force   # push the rollback
```
