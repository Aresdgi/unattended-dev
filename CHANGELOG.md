<p align="center">
  <b>English</b> · <a href="CHANGELOG.es.md">Español</a>
</p>

# Changelog

Every version of unattended-dev, from the very first one. Versions from
8.1.1 on are public, each with its
[GitHub Release](https://github.com/Aresdgi/unattended-dev/releases).
Earlier ones lived in a private repo, under other names: `modo-nocturno`
(1 and 2) and `modo-desatendido` (3 to 8.1.0).

## [8.6.0] - 2026-10-08

Proactive autonomy and what the first real run taught. In that run (a pace
calculator, Codex orchestrating) 4 of 5 tasks blocked on one gap in the
SPEC, the Log stayed empty, one task got 3 fixes with a limit of 2 and the
final report came in English.

### Added
- **Autonomy**, chosen in the team round. *Proactive* (recommended): on a
  gap in the SPEC the orchestrator writes down the most prudent rule with
  `queue.sh decide` in `docs/DECISIONES.md` and keeps going. *Conservative*:
  it blocks the task with the question. Answers that change the product or
  can't be undone are always left to you.
- `queue.sh fix` counts fixes and says when none are left (a decision earns
  one more).
- The interview asks for the limits of every input (minimum, maximum,
  units, error).
- Phase zero adds an adversarial review of the SPEC by another role before
  writing the tests, so gaps are settled with you in one round.

### Changed
- `queue.sh` writes every Log line itself: start, fix, decision, DONE,
  BLOCKED (with the dependency that caused it) and interruptions.
- The orchestrator reports in your language and ends with the decisions it
  took and the open questions. The review starts with the decisions.
- 119 tests.

## [8.5.0] - 2026-10-08

A real Orca mode.

### Fixed
- Choosing Orca as the worker launcher was ignored: the orchestrator
  template hard-coded `lanzar-worker.sh`, so workers ran through the CLI
  without telling you.

### Added
- Orca mode follows Orca's own orchestration guide: one tab per worker so
  you can watch them, fixes reuse the implementer's tab, and tabs are
  closed with `worker-release` as soon as they are not needed (nothing
  reclaimable is left at the end).
- `vigilar-worker.sh`: the worker protections (read-only tests, files
  outside the task) in two steps, for workers that start and finish on
  their own. `lanzar-worker.sh` uses it too.

### Changed
- The orchestrator template gets only the worker block you chose (CLI or
  Orca). Phase zero keeps that choice, stops and asks if it can't be used,
  and runs the smoke test with it. The review checks it.
- 92 tests.

## [8.4.0] - 2026-10-07

The queue only commits its own work.

### Changed
- `queue.sh start` refuses to start a task while the working tree has
  changes that are not from the queue, and names them, so closing a task
  can never sweep in unrelated files.
- `bucle.sh` checks the same before every round and stops with a clear
  message.
- Docs: don't edit the project folder while the queue runs; use a worktree
  of your own. Per-task diagram in the README, as SVG so it shows on
  mobile.
- 83 tests.

## [8.3.0] - 2026-10-07

Queue state committed, atomic close.

### Fixed
- A stash could bring back an old state: a blocked T02 put a finished T01
  back IN PROGRESS. Every state change is now committed.
- `recover` ignored a failed `git stash`, and `bucle.sh` lost its exit code
  in a pipe. Both now stop with exit 4 and mark nothing.

### Added
- `queue.sh done` and `queue.sh block` close a task in one step (state and
  work commit, or stash and BLOCKED). The orchestrator never commits,
  stashes or edits `STATUS.md` itself.
- 76 tests.

## [8.2.0] - 2026-10-07

Fixes from an external review, tests and CI.

### Added
- `queue.sh`: the queue decisions in code instead of in the model: next
  task, dependencies, BLOCKED propagation, unskipping the task's test on
  start and recovering tasks cut off.
- `tests/run.sh` with 53 cases, run in CI on Linux and macOS.

### Fixed
- `bucle.sh` stopped when only an interrupted task was left.
- `lanzar-worker.sh` missed forbidden files changed inside commits, and
  returned 0 for a worker killed by a signal (now 128+N). New `--readonly`
  for the tests.
- `guardia-tests.sh` accepted deleting an assertion together with its
  skip, and used `\b`, which macOS sed doesn't support.

### Changed
- README: experimental status, honest wording about the tests, Testing
  section.

## [8.1.1] - 2026-10-07

First public version.

### Added
- Its own repo, installable as a Claude Code plugin from its own
  marketplace and with `npx skills` for Codex, opencode and others.
- READMEs in English and Spanish, including how to install it by asking
  your agent.
- Launching Codex in tmux, tested: no-sandbox mode, the "Trust this
  folder?" prompt and the goal's states.

## 8.1.0 - 2026-10-07

### Changed
- Renamed to **unattended-dev**. The skill is written in English and
  still talks to you in your language.
- Automatic launch: the skill starts the orchestrator itself in a new,
  clean session (`claude --bg`, tmux or an Orca tab) after a dry run,
  instead of handing you a prompt to paste.

## 8.0 - 2026-10-07

### Added
- **Quick mode** (default for 6 tasks or fewer with nothing risky): one or
  two interview rounds, a single approval, a short `docs/SPEC.md` and a
  `PLAN.md`. The full mode stays for big or risky projects.
- Bundled scripts: `lanzar-worker.sh` (runs one worker with a time limit
  and checks it only touched its files) and `guardia-tests.sh` (the
  acceptance tests can't be edited, deleted or skipped).

### Changed
- Less ceremony overall: one file per task and the inventory reference are
  gone. The usual team is saved outside the project.

## 7.0 - 2026-10-07

### Changed
- **Any tool, any model.** Every role (orchestrator, implementer, design,
  QA) is whatever you choose: Claude Code, Codex, opencode, Command Code or
  others, with or without Orca. It warns once if a choice looks
  inefficient and then does what you say.
- An inventory of what is installed first; it never offers a tool it
  hasn't seen.
- `AGENTS.md` is the conventions file, `CLAUDE.md` a link to it.

### Added
- `bucle.sh`, a fresh orchestrator per round for tools without a native
  goal, and a reference for each launcher.
- A smoke test of the whole team before launching.

## 6.1 - 2026-10-07

### Changed
- The team is chosen during the plan, and your usual team is remembered.

## 6.0 - 2026-10-07

From a script that walks a queue to a skill that prepares the whole
project.

### Added
- Five phases: **interview** until the SPEC has no gaps, **plan** (tasks
  small enough for one worker, risky ones kept out), **phase zero**
  (skeleton, gate, acceptance tests written first and verified),
  **launch** and **review**.
- One orchestrator session with `/goal` runs the whole queue, delegating
  to cheap workers. QA by another provider (Codex) by default.

### Removed
- `desatendido.sh`, `DESATENDIDO.md` and the fuse files of versions 1 to 5.

## 5 - 2026-10-04

### Fixed
- After a real incident: an orchestrator closed the terminal running the
  loop while cleaning up, killing the whole session. Now it only closes
  the terminals of workers it started itself.
- Gate commands run in a subshell, so one that changes folder can't break
  the rest.
- Interruptions (closed terminal, kill, Ctrl+C) are written to the log.

## 4 - 2026-10-04

### Added
- QA by Claude Sonnet workers, never by whoever built the code, checking
  that the launched model is the expected one.
- Three QA types: technical (always), fidelity (when there are sources of
  truth) and design (when the task touches the interface; no screenshots,
  no PASS). QA only reports; fixes go back to a worker.

## 3 - 2026-10-03

### Changed
- Renamed to **modo-desatendido** (unattended mode, at any time of day, not
  only at night).
- Plan by talking: you describe what you want, Claude proposes the queue
  split into clear tasks, decisions you must take, risky work and quick
  fixes, and writes it after your OK.
- Kept in a private repo of skills, linked into `~/.claude/skills`.

## 2 - 2026-10-03

### Added
- Phase zero for brand-new projects: specs, stack, skeleton and gate with
  you present before any unattended work.
- More startup checks: no commits, unfilled placeholders, no gate. The
  gate runs before starting.

## 1 - 2026-10-03

First version, as **modo-nocturno** (night mode).

- `noche.sh` walks a queue in `STATUS.md`, launching a fresh Claude
  orchestrator per task in an Orca tab, with opencode workers.
- Fuses: `AGENT_STOP` (you ask it to stop), `AGENT_BLOCKED` (a decision
  needs you) and `AGENT_FAILED` (repeated failures).
- A closing note per task and a morning report that checks the commits it
  cites.
- Startup checks: jq, Orca, running inside an Orca terminal, opencode
  permissions, fuses and an empty queue.

[8.6.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.6.0
[8.5.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.5.0
[8.4.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.4.0
[8.3.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.3.0
[8.2.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.2.0
[8.1.1]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.1.1
