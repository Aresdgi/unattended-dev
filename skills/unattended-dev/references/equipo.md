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
- **Non-interactive mode, model, write and read-only**: check it in its
  `--help`. Typical forms: `claude -p --model <m> -- "<order>"`,
  `codex exec -m <m> "<order>"`, `opencode run -m <provider/model> "<order>"`.
  Each role gets the flags of what it does, never the ones of another
  role of the same tool: whoever writes (implements, design, and QA when
  it writes the acceptance tests in full mode) needs a mode that can
  edit the project (for example `codex exec -s workspace-write`); QA
  reviewing, a read-only one (`codex exec -s read-only`). A read-only
  sandbox on a role that has to write wastes a whole call. If a worker
  calls an API, its mode also needs network.
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

If the "usual" team is saved and still installed, it is a single
question in the second round of the interview: "the usual (listed)?".
Otherwise, one extra round, one question per role, with options taken
from the inventory and your recommendation first:

1. **Orchestrator**: tool and model.
2. **Implements and fixes**.
3. **Design**, only if there are UI tasks: the same or another one.
4. **QA**: recommend a provider different from the implementer's. Models
   find between 8 and 10 points more bugs in someone else's code than in
   their own.
5. **Autonomy** when the queue finds a gap in the SPEC: **proactive**
   (recommended for unattended runs: it picks the most prudent option,
   records it in `docs/DECISIONES.md` and keeps going; you review the
   decisions afterwards) or **conservative** (it blocks the task and
   leaves the question for you).
6. **Worker launcher**, only if Orca is installed: **CLI** (each worker is
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

In the same question, ask whether to save it as "the usual" in
`~/.config/modo-desatendido/equipo.md`. Its Checks are written there
anyway, even if the team is not saved: they are what lets the next
projects skip the smoke test and the dry run.

```markdown
- Orchestrator: <tool> / <model>
- Implements: <tool> / <model>
- Design: <tool> / <model> or "same as implements"
- QA: <tool> / <model>
- Worker launcher: <cli | orca>
- Autonomy: <proactive | conservative>

## Checks
- Smoke test <YYYY-MM-DD>: <launcher>; implements <tool>/<model>, design <tool>/<model>, QA <tool>/<model>: all OK
- Dry run <YYYY-MM-DD>: <mechanism> <exact flags>: OK
```

A smoke test line counts for 7 days and for that same team; a dry run
line, until the mechanism or its flags change. Replace the old line of
the same kind instead of adding another.

Then turn each role into its real command (`references/lanzadores.md`)
and fill in `ORQUESTADOR.md`.
