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
4. Commit `unattended-dev X.Y.Z: <summary>` on a branch, wait for CI, then
   fast-forward `main`.
5. Tag and release, with the changelog entry as the notes (English, then
   Spanish under a `<details>`):

   ```zsh
   git tag -a vX.Y.Z -m "unattended-dev X.Y.Z" && git push origin vX.Y.Z
   gh release create vX.Y.Z --title "X.Y.Z: <summary>" --notes-file notes.md --latest
   ```

## Style

- READMEs and changelog in English and Spanish, always both.
- Commands for the user in zsh (macOS). No em-dashes.
- Diagrams as SVG in `.github/assets`, not Mermaid (it shows as raw code
  in the GitHub mobile app).
