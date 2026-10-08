# Maintaining unattended-dev

Notes for whoever changes this repo (person or agent). They are not part
of the skill: users never load this file.

## Every new version

1. Bump the version in `.claude-plugin/plugin.json`, the version badge of
   both READMEs and the `unattended-dev vX.Y` header of the files that
   carry one (`grep -rn "unattended-dev v" skills/`).
2. Add the entry at the top of `CHANGELOG.md` and `CHANGELOG.es.md`, with
   the date and Added / Changed / Fixed / Removed, plus its link at the
   bottom of each file. Write what changes for the user, not how.
3. `bash tests/run.sh` passes. CI also checks that the version has its
   entry in both changelogs and matches both READMEs.
4. Commit `unattended-dev X.Y.Z: <summary>` (exactly that prefix) on a
   branch, wait for CI, then fast-forward `main`.
5. Nothing else: once CI passes on `main`, its `release` job creates the
   tag and the GitHub Release for every changelog version that has none,
   on the commit `unattended-dev X.Y.Z: ...`, with the changelog entry as
   notes (`.github/scripts/release_notes.py`). The version in
   `plugin.json` is marked latest.

## Style

- READMEs and changelog in English and Spanish, always both.
- Commands for the user in zsh (macOS). No em-dashes.
- Diagrams as SVG in `.github/assets`, not Mermaid (it shows as raw code
  in the GitHub mobile app).
