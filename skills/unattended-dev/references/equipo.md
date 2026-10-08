# Team

## 1. Inventory

Before asking, look at what is really there. Offering something that is
not installed is the worst mistake in this phase.

```zsh
for c in claude codex opencode orca gemini tmux; do command -v "$c" >/dev/null && echo "$c"; done
cat ~/.config/modo-desatendido/equipo.md 2>/dev/null
```

For each installed tool:

- **Models**: `opencode models`, `grep -n model ~/.codex/config.toml`,
  `claude --help` (accepts `opus`, `sonnet`, `haiku`), or the `--help` of
  whichever it is.
- **Non-interactive mode, model and read-only**: check it in its
  `--help`. Typical forms: `claude -p --model <m> -- "<order>"`,
  `codex exec -m <m> "<order>"`, `opencode run -m <provider/model> "<order>"`.
- **Orca**: if present, `orca orchestration worker-start --help` says
  which agents it accepts and how the model is passed.
- **Native goal** of the tool that will orchestrate (for example `/goal`
  in Claude Code or Codex): look for it in its help or documentation
  (`codex features list` shows `goals`).
- **Background mode** of that tool (for example `claude --bg`): check it
  in its `--help`. It decides the launcher in phase 4
  (`references/lanzadores.md`).

Show it to the user in a short table: tool, models, whether it can be
launched as a worker, whether it has read-only mode, native goal and
background mode.

## 2. Ask

One round, one question per role, with options taken from the inventory.
First option: the "usual" one if it exists and is still installed;
otherwise your recommendation.

1. **Orchestrator**: tool and model.
2. **Implements and fixes**.
3. **Design**, only if there are UI tasks: the same or another one.
4. **QA**: recommend a provider different from the implementer's. Models
   find between 8 and 10 points more bugs in someone else's code than in
   their own.
5. **Worker launcher**, only if Orca is installed: **CLI** (each worker is
   a command, nothing to watch; works anywhere) or **Orca** (each worker in
   its own tab that you can watch, closed when no longer needed; the
   orchestrator must run in an Orca tab). Without Orca, it is CLI and you
   do not ask.

## 3. Warnings (once, they never block)

- QA with the same model that implements.
- Expensive model implementing mechanical tasks.
- Orchestrator and workers on the same plan or quota: it will run out
  sooner.
- QA without read-only mode: it will be forbidden in writing to touch
  files.

## 4. Save and write

Ask whether to save it as "the usual" in
`~/.config/modo-desatendido/equipo.md`:

```markdown
- Orchestrator: <tool> / <model>
- Implements: <tool> / <model>
- Design: <tool> / <model> or "same as implements"
- QA: <tool> / <model>
- Worker launcher: <cli | orca>
```

Then turn each role into its real command (`references/lanzadores.md`)
and fill in `ORQUESTADOR.md`.
