<p align="center">
  <b>English</b> · <a href="CHANGELOG.es.md">Español</a>
</p>

# Changelog

Every version of unattended-dev, from the very first one. Versions from
8.1.1 on are public, each with its
[GitHub Release](https://github.com/Aresdgi/unattended-dev/releases).
Earlier ones lived in a private repo, under other names: `modo-nocturno`
(1 and 2) and `modo-desatendido` (3 to 8.1.0).

## [8.9.0] - 2026-10-08

A preparation that runs alone. You answer the questions and confirm once;
phase zero and the launch run without stopping, so you can leave right
after that "yes", and the preparation has a time budget that fits the
size of the milestone.

### Added
- A preparation budget, from the first question to the queue running:
  5 minutes and no worker calls for 1 to 3 tasks, 15 minutes and at most
  one for 4 to 8, 30 minutes for more or in full mode. What does not fit
  is done once per machine or moved to the queue. The Log records when
  the preparation started and when the queue was launched.
- With 3 tasks or fewer, the skill first tells you that a normal session
  (with `/goal` if your tool has it) does it sooner.
- A risk per task in `PLAN.md`. Low risk gets one combined QA review;
  high risk gets fidelity and technical apart, and `queue.sh done` no
  longer accepts a single combined review for it.
- The smoke test and the launch dry run are recorded in
  `~/.config/modo-desatendido/equipo.md` with their date and run once
  per machine. Without a recent one, the orchestrator checks the model of
  the first worker of each role and the launch is checked to have
  started.
- The README says where the skill pays off and where it does not.

### Changed
- One confirmation at the end of the interview is the last question. The
  edge cases a separate adversarial review used to look for, the team,
  the hours and how to launch are asked in the interview. After the
  confirmation, a doubt follows the autonomy you chose (proactive writes
  a prudent rule in `docs/DECISIONES.md`) and only what really needs you
  stops phase zero: a missing tool, an untrusted folder, a failed smoke
  test or dry run.
- In fast mode the acceptance tests are written by whoever prepares and
  checked to fail against the stubs for the right reason; QA writing
  them and the reference implementation stay for full mode. Fast mode
  now covers up to 8 tasks.
- The Log moves from `STATUS.md` to `docs/LOG.md`, with the same
  protection: a worker that edits it is out of task. An old Log in
  `STATUS.md` is moved there by itself.
- The orchestrator runs the gate before the QA, so no review is spent on
  code that is going to change, and from the first failure it may read
  the task's diff and the failing test to give a concrete fix order.
- The cases of each task follow what it has (one invalid case per error,
  the limits of each input, one valid case per rule, or each state of a
  screen) instead of a fixed 6 and 6.
- With a UI, each acceptance test is a Playwright test with assertions on
  the states of the SPEC, and Playwright starts the server itself.
- Each role gets the flags of what it does: write mode for whoever
  writes, read-only for QA reviewing.
- An acceptance test only checks its own task, never an output a later
  task will change.
- `block`, `recover` and `restore-outside` run none of the project's git
  hooks (the other commits of `queue.sh` neither, not even the
  `prepare-commit-msg` or `reference-transaction` that `--no-verify`
  leaves), so a failing hook can
  no longer leave the queue stuck while it puts a task back. `done` still
  runs them.

### Fixed
- `queue.sh` reads the Log as it last committed it, so a worker that
  overwrites `docs/LOG.md` (a common name) cannot hide where its task
  started: `block` and `restore-outside` still put the code back.
- A Log line that cannot be written makes the step fail instead of
  reporting it as recorded.
- `LANZAR.md`, written after the launch, could make the first
  `queue.sh start` refuse because of a dirty tree. It is in `.gitignore`
  now.

## [8.8.0] - 2026-10-08

Locks. The rules that keep broken or tampered work out of DONE are now
enforced by `queue.sh`, not left to the orchestrator: if a worker or the
orchestrator gets it wrong, the command refuses with a clear exit code.

### Added
- `queue.sh qa <task> <type> PASS|FAIL "<summary>"` records a QA verdict
  for the exact code it reviewed.
- `queue.sh outside <task>` lists the files a task changed since it
  started (committed or not) that it may not touch, and
  `queue.sh restore-outside <task>` puts them back, with a copy in a
  backup branch.
- `con-limite.sh`: a time limit for any command that stops its whole
  process group, including what the command leaves running in the
  background when it ends. `lanzar-worker.sh` and `bucle.sh` use it.
- Phase zero leaves the gate in `.desatendido/gate.sh` and the files each
  task may touch in `.desatendido/allowed/Txx` (plus `.desatendido/qa/Txx`
  for tasks that need design QA).

### Changed
- `queue.sh done` checks before closing: nothing outside the task (exit
  6), the gate passes and changes no file, staged content or commit, run
  by `done` itself (exit 7),
  and there is a QA PASS of each type for the code as it is now (exit 8).
  If it refuses, the task stays IN PROGRESS and the tree is as it was:
  whatever the gate changed is put back. So the DONE commit is always the
  code the QA saw. If the gate switches branch, `done` stops with 4
  without moving any reference.
- While a task is IN PROGRESS, `STATUS.md` and `docs/DECISIONES.md` must
  be exactly as `queue.sh` left them. Otherwise `fix`, `decide`, `note`,
  `qa` and `set` refuse (exit 6) instead of committing someone else's
  change, and `recover` rebuilds the table even if a worker emptied or
  deleted it.
- `queue.sh start` refuses if a dependency is not DONE, if another task is
  IN PROGRESS or if the task has no allowed list.
- `block` and `recover` keep the task's work in a
  `queue/backup/<task>-<date>` branch instead of a stash, and put every
  file the task touched back as it was when it started, including what
  the worker committed. The history is not rewritten.
- `bucle.sh` cuts each round at `ROUND_TIMEOUT` (1 hour by default) or at
  the time left of `MAX_HOURS`; the task goes back to PENDING and the
  loop stops with 124.
- The gate runs the acceptance tests by name and has to fail if it runs
  none, and it must not change files. Phase zero checks both: it excludes
  the acceptance folder for a moment, and it runs the gate twice on a
  clean tree with `git status` still empty.
- `queue.sh set` writes itself in the Log and only takes PENDING and
  BLOCKED: DONE always goes through `done`, IN PROGRESS through `start`.
- The commits of `queue.sh` that only carry `STATUS.md` or
  `docs/DECISIONES.md` skip the project's git hooks; `done`, `block`,
  `recover` and `restore-outside`, which carry code, run them.
- Phase zero puts `.DS_Store`, editor swap files (`*.swp`, `*~`),
  `.vite/`, `__pycache__/` and `coverage/` in `.gitignore`, so they never
  count as out of task, and a task that needs a development dependency
  lists `package.json` and the lockfile among its files.
- The orchestrator follows the locks: it records every QA verdict with
  `queue.sh qa`, puts back the files of a worker that went out of its
  task (`restore-outside`) before the fix, and no longer runs the gate
  before `done`, which runs it. Exits 6 and 7 of `done` take the fix
  path; with 8 it repeats the QA it names.
- While a worker runs, `lanzar-worker.sh` and `vigilar-worker.sh` make
  `.desatendido/` read-only too, so a worker cannot change the scripts
  that judge its work.

### Fixed
- A change out of task (for example `package.json` with a test script
  that is just `exit 0`) survived a fix and went into the DONE commit,
  because the second worker was measured against the tree the first one
  had already changed. Each task is now measured against the commit it
  started from.
- `block` and `recover` only stashed uncommitted changes: commits made by
  a worker stayed in, broken code included.
- `done` closed a task without the gate or the QA having run.
- `start` started a task whose dependency was still PENDING.
- A hung round of `bucle.sh` was never cut off, and `lanzadores.md` said
  `MAX_HOURS` bounded it.
- After a session cut off between `vigilar-worker.sh begin` and `end`, the
  tests stayed read-only and `recover` failed. It now gives write
  permission back first.
- 353 tests.

### Known limitations
- If the gate itself runs a `queue.sh` command that commits (for example
  `queue.sh note`), `done` puts back HEAD and `STATUS.md` but not the
  queue's trusted state, and the next queue commands refuse with 6. A
  gate should only call `queue.sh tests`.
- With `STATUS_FILE` or `DECISIONS_FILE` set to a path with spaces,
  `recover` cannot put those files back. Phase zero always uses
  `STATUS.md` and `docs/DECISIONES.md`.
- Switching to another existing branch in the same worktree during a
  task: `recover` applies the queue state of the branch the task started
  on and puts the task's files back as they were at its start, on the
  new branch (everything is kept in a backup branch first).
- The locks catch mistakes, not deliberate sabotage: a worker that gives
  itself write permission on `.desatendido/` and edits `queue.sh`, moves
  `refs/worktree/queue-state` with `git update-ref` or rewrites the
  history with `git reset --hard` can get around them.

## [8.7.2] - 2026-10-08

Queue notes in the Log.

From the third real run (an expense splitter CLI, Orca launcher): 7 of 7
tasks DONE in 36 minutes, one decision taken on its own, fixes within the
limit and the goal closed by itself.

### Fixed
- Orca mode asked the orchestrator to write the Run id and any model
  mismatch in the Log, but it may never edit STATUS.md and `queue.sh` had
  no command for it. New `queue.sh note "<text>"` adds a free line to the
  Log and commits only STATUS.md.
- 132 tests.

## [8.7.1] - 2026-10-08

From the second real run, with Orca as the worker launcher: all 5 tasks
DONE, every QA PASS, no decisions needed.

### Fixed
- Orca mode checked that it runs inside an Orca terminal with
  `caller.orcaSessionId` from `orca status --json`, which Orca 1.4.221
  does not show. It now checks `$ORCA_TERMINAL_HANDLE`, like the launch
  reference already did.
- Worker tabs Orca keeps as the user's (`user_takeover`) are listed in the
  final report, so you know which ones to close.

## [8.7.0] - 2026-10-08

A goal that always ends. In a real run the queue finished (3 DONE, 2
BLOCKED, gate green) but the session kept turning for over twenty turns:
the `/goal` asked for the work to have been done "following
ORQUESTADOR.md" and after reading "nothing else", and after one slip that
could never be true again.

### Fixed
- The `/goal` asks only for an end state: `queue.sh summary` shows 0
  PENDING and the gate passes, or the orchestrator had to stop and said
  why, or the hours are up. How the work was done is not part of it.
- The orchestrator reports its own slips once in the final report and
  never reverts finished work or waits for an answer to make up for them.
- The first prompt and the dry run no longer say "nothing else".

### Added
- A time fuse that stops the session at the end of the chosen hours even
  if its goal never ends. With "no limit" it stays at 24 hours as a
  safety net.
- The time limit is asked in the launch question (about 30 minutes per
  task by default), and the orchestrator prints the time when it starts.
- Tests that the goal is the same in both templates and only asks for an
  end state. 124 tests.

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

[8.9.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.9.0
[8.8.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.8.0
[8.7.2]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.7.2
[8.7.1]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.7.1
[8.7.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.7.0
[8.6.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.6.0
[8.5.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.5.0
[8.4.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.4.0
[8.3.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.3.0
[8.2.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.2.0
[8.1.1]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.1.1
