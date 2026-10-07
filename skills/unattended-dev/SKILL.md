---
name: unattended-dev
description: Turns a rough idea into a project that builds itself, with whatever team of agents and models the user wants (Claude, Codex, opencode or others, with or without Orca). Asks until the SPEC is clear, plans small tasks, picks the team from what is installed, prepares a minimal base with protected tests and launches the orchestrator in the background. Use it when the user says "I want to build...", "set up the project", "make it build itself", "unattended mode", "overnight mode", "leave it running" or "launch it", or in Spanish "quiero hacer...", "monta el proyecto", "prepáralo para que se haga solo", "modo desatendido", "modo nocturno", "déjalo picando" or "lánzalo", for a new project or a milestone of an existing repo.
---

# unattended-dev v8.2

Always reply to the user in their language.

The user describes what they want. You understand it, plan it, prepare a
minimal base and launch it. From then on, an orchestrator works alone: it
hands out tasks, runs the gate, asks for QA and records everything.

What works is not ceremony, it is four things: small verifiable tasks,
tests written first and protected by a script, QA not done by whoever
implemented (ideally another provider) and state kept in files so work can
resume. Everything else, the minimum.

## Modes

| | Fast (default) | Full |
| --- | --- | --- |
| When | 6 tasks or fewer and nothing risky | Large project, real data, high risk or the user asks for it |
| Interview | 1 or 2 rounds | As many as needed |
| Approvals | One, at the end of the preparation | At the end of each phase |
| Documents | `docs/SPEC.md` (1 or 2 pages) and `PLAN.md` | SPEC, one file per task and one closing note per task |

Propose the mode when the interview ends, in one line, with the reason.

## Phases

1. **Interview**: `references/entrevista.md`. End with a summary and "shall
   I set it up like this?".
2. **Plan and team**: small tasks with closed file lists; then inventory
   and team with `references/equipo.md`.
3. **Phase zero**: `references/fase-cero.md`. In fast mode, plan, team and
   phase zero run back to back and are approved together at the end.
4. **Launch**: ask "shall I launch it?". With a yes, launch the
   orchestrator yourself in the background, in a NEW session with a clean
   context, after a dry run (`references/lanzadores.md`). With a no, give
   the user `assets/LANZAR.md` filled in.
5. **Review**: when the user comes back with the result,
   `references/revision.md`.

## Freedom of team

- Each role (orchestrator, implementer, design, QA) is taken by the tool
  and model the user picks, even if it is inefficient. Warn once with the
  reason and do what they say.
- There is no team written in the skill. The "usual" one is the one the
  user saved in `~/.config/modo-desatendido/equipo.md`.
- Never offer anything you have not seen installed.

## Included tools

Copy `assets/desatendido/` to `.desatendido/` at the project root. Use
these scripts; do not build others for the same job.

| Script | What for |
| --- | --- |
| `queue.sh` | The mechanical decisions, in code: next task, dependencies, BLOCKED propagation, removing the skip when a task starts, recovering a task that was cut off |
| `lanzar-worker.sh` | Launch any worker with a time limit, a log, the last 30 lines, tests read-only, and a warning if it touches files outside its task (committed or not). Also the smoke test |
| `guardia-tests.sh` | Inside the gate: fails if the acceptance tests change in anything other than removing the skip, if someone adds a skip or if the current task has not removed it |
| `bucle.sh` | Keep an orchestrator with no native goal alive, one task per round chosen by `queue.sh` |

These scripts detect problems after they happen and take the mechanical
decisions out of the model. They are not a sandbox: say so if the user
asks how safe it is.

## Compatibility

- Works in any agent that reads SKILL.md. If your tool has questions with
  options, use them; if not, numbered options in text.
- Commands of other tools are checked with their `--help`. Never from
  memory.
- The project conventions file is `AGENTS.md`; `CLAUDE.md`, if needed, is
  a link to it.

## Safety rules

They do not depend on the team or the mode:

- Nothing irreversible in the queue: real data, deletions, deployments,
  publishing or push. That is done supervised.
- Without verified acceptance tests, the guard in the gate, a green smoke
  test and a passed launch dry run, there is no launch.
- If you find a gap in the SPEC, ask. Do not fill it in silently.

## Existing repo

Same, but the interview only covers the milestone, no skeleton is created,
the tag is `<milestone>-start` and the milestone SPEC goes in
`docs/hitos/<milestone>/` if there is already a general one. If there are
leftovers from old versions (`desatendido.sh`, `DESATENDIDO.md`, a
`bucle.sh` at the root), propose deleting them and wait for the OK.
