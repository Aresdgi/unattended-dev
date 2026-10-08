---
name: unattended-dev
description: Turns a rough idea into a project that builds itself, with whatever team of agents and models the user wants (Claude, Codex, opencode or others, with or without Orca). Asks until the SPEC is clear, plans small tasks, picks the team from what is installed, prepares a minimal base with protected tests and launches the orchestrator in the background. Use it when the user says "I want to build...", "set up the project", "make it build itself", "unattended mode", "overnight mode", "leave it running" or "launch it", or in Spanish "quiero hacer...", "monta el proyecto", "prepáralo para que se haga solo", "modo desatendido", "modo nocturno", "déjalo picando" or "lánzalo", for a new project or a milestone of an existing repo.
---

# unattended-dev v8.9

Always reply to the user in their language.

The user describes what they want. You ask, they confirm once, and from
there everything runs alone: you prepare a minimal base and launch the
queue, and an orchestrator hands out tasks, runs the gate, asks for QA and
records everything. The user is only needed for the questions.

What works is not ceremony, it is four things: small verifiable tasks,
tests written first and protected by a script, QA not done by whoever
implemented (ideally another provider) and state kept in files so work can
resume. Everything else, the minimum.

## Preparation budget

The rule above all others. The preparation, from the first question to
the queue launched, is proportional to the milestone:

| Tasks | Time | Worker calls |
| --- | --- | --- |
| 1 to 3 | 5 minutes | none |
| 4 to 8 | 15 minutes | at most 1 |
| More than 8, or full mode | 30 minutes | as needed |

In every case the user is only there for the questions. A step that does
not fit the budget is dropped for that size, done once per machine
(recorded in `~/.config/modo-desatendido/equipo.md`) or moved to the
queue. The Log (`docs/LOG.md`) gets the time of the first question and
the time the queue was launched.

With 3 tasks or fewer, first say in one line that a normal session does
it sooner (with `/goal` if the tool has it); go on only if the user wants
the skill anyway.

## Modes

| | Fast (default) | Full |
| --- | --- | --- |
| When | 8 tasks or fewer and nothing risky | More than 8 tasks, real data, high risk or the user asks for it |
| Interview | 1 or 2 rounds | As many as needed |
| The user | Answers the questions and confirms once; the rest runs alone | The same |
| Acceptance tests | Written by you, checked against the stubs | Written by QA, checked against a reference implementation |
| Documents | `docs/SPEC.md` (1 or 2 pages) and `PLAN.md` | SPEC, one file per task and one closing note per task |

Propose the mode in the interview, in one line, with the reason.

## Phases

1. **Interview**: `references/entrevista.md`. Note the time of the first
   question. It covers the idea, the limits and edge cases, the team
   (`references/equipo.md`), the autonomy, the hours and the launch.
2. **Confirmation**: one summary (SPEC in a few lines, tasks with their
   files and risk, team, autonomy, hours, launch) and "shall I set it up
   and leave it running?". It is the last question.
3. **Phase zero and launch**, without stopping: `references/fase-cero.md`,
   then `references/lanzadores.md`. The orchestrator always starts in a
   NEW session with a clean context. If the user said they launch it
   themselves, give them `assets/LANZAR.md` filled in instead.
4. **Review**: when the user comes back with the result,
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
| `queue.sh` | The mechanical decisions, in code: next task, dependencies (also on `start`), BLOCKED propagation, removing the skip when a task starts, counting fixes (`fix`), recording default decisions (`decide`), QA verdicts tied to the exact code (`qa`), free Log lines (`note`), files out of the task since it started (`outside`, `restore-outside`), closing a task (`done` / `block`) in one atomic step and recovering a task that was cut off. `done` refuses without its own gate run and the QA PASS the task's risk asks for; `block` and `recover` keep the work in a backup branch and undo even the worker's commits. Every change is committed and logged in `docs/LOG.md` |
| `con-limite.sh` | Time limit for any command, stopping its whole process group (macOS has no `timeout`). Used by `lanzar-worker.sh` and by `bucle.sh` for each round |
| `lanzar-worker.sh` | CLI launcher: run any worker with a time limit, a log, the last 30 lines, tests and `.desatendido/` read-only, and a warning if it touches files outside its task (committed or not). Also the smoke test |
| `vigilar-worker.sh` | The same protections in two steps (`begin` before, `end` after) for workers that start and finish on their own, such as Orca workers |
| `guardia-tests.sh` | Inside the gate: fails if the acceptance tests change in anything other than removing the skip, if someone adds a skip or if the current task has not removed it |
| `bucle.sh` | Keep an orchestrator with no native goal alive, one task per round chosen by `queue.sh`, each round with a time limit |

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
- Without verified acceptance tests and the guard in the gate, there is
  no launch. The smoke test and the launch dry run pass once per machine;
  when they are not recorded and do not fit the budget, the queue checks
  the first worker of each role and you check that the launch started.
- Until the confirmation, if you find a gap in the SPEC, ask. After it,
  in phase zero and in the queue, gaps follow the autonomy the user
  chose: proactive records a prudent default in `docs/DECISIONES.md` and
  keeps going; conservative stops (phase zero) or blocks the task (queue)
  with the question. Either way, nothing is decided silently.

## Existing repo

Same, but the interview only covers the milestone, no skeleton is created,
the tag is `<milestone>-start` and the milestone SPEC goes in
`docs/hitos/<milestone>/` if there is already a general one. If there are
leftovers from old versions (`desatendido.sh`, `DESATENDIDO.md`, a
`bucle.sh` at the root), propose deleting them and wait for the OK.
