# Phase zero

Prepare the minimum for the orchestrator to work alone. Do not implement
any task from the queue and do not create scripts of your own: use the
ones in `.desatendido/`.

It starts after the confirmation and runs without stopping until the
queue is launched (`references/lanzadores.md`). The user may have left.

## 0. Without stopping

- **No more questions.** A doubt about the SPEC or the plan follows the
  autonomy the user chose. Proactive: take the most prudent option, write
  it in the SPEC marked "(default)" and add a line to
  `docs/DECISIONES.md` (`- <date> <time> phase zero: <the rule>`), the
  same file the queue uses. Conservative: stop and leave the question.
- **What needs a person stops, and you say it**, never decided by
  default: a missing tool, the orchestrator's folder not trusted, a red
  smoke test, a dry run that fails, a launch that your own permissions
  block. Leave `LANZAR.md` filled in with what is left to do, and the
  reason in your last message.
- **The budget** (`SKILL.md`) counts from the first question. Look at the
  time at each step. If it goes over, add a line to the Log and say it in
  the final summary; if the user wrote to you since the confirmation, ask
  whether to go on or do it by hand.

What each size runs here:

| Step | 1 to 3 tasks | 4 to 8 tasks | More than 8, or full mode |
| --- | --- | --- | --- |
| Acceptance tests | Written by you | Written by you | Written by QA (worker calls) |
| Verification | Fail against the stubs for the right reason | The same | Reference implementation |
| Smoke test of each role | Recorded on this machine, or the queue checks the first worker of each role | The same | Here, unless recorded |
| Launch dry run | Recorded, or you check that the launch started | Recorded, or here (the one worker call) | Here, unless recorded |
| Gate checks (section 1) | Here | Here | Here |

"Recorded" means a line in the Checks of
`~/.config/modo-desatendido/equipo.md` (`references/equipo.md`): a smoke
test of the same team in the last 7 days, or a dry run of the same
mechanism with the same flags.

## 1. Skeleton and gate

- Minimal structure for the stack. The functions or screens in the queue
  exist as stubs with their signatures.
- Copy `assets/desatendido/` to `.desatendido/` and make the scripts
  executable.
- The gate, in `.desatendido/gate.sh` (executable): it starts with the
  guard and goes on with typecheck, tests and build. `queue.sh done` runs
  it itself before closing a task. It runs the acceptance tests of
  `queue.sh tests` by name, so a change in the runner configuration
  cannot leave them out, and it must fail if it runs no acceptance test
  while `queue.sh tests` lists some.
  For example:

  ```bash
  #!/usr/bin/env bash
  set -e
  tests=$(.desatendido/queue.sh tests)
  .desatendido/guardia-tests.sh fase-cero tests/acceptance $tests
  npm run typecheck
  if [ -n "$tests" ]; then npx vitest run $tests; fi  # vitest fails if it finds none of them
  npm test && npm run build
  ```

  With a UI the acceptance step is `npx playwright test $tests` (it fails
  with "No tests found" too).

  Check it once: exclude the acceptance folder in the runner configuration
  for a moment (for example `exclude` in `vitest.config.ts`), run the
  acceptance step of the gate on one test by name (`npx vitest run
  tests/acceptance/T01.test.ts`), see that it fails because it runs no
  test, and undo the exclusion.

  The gate must not change files either: `queue.sh done` refuses (exit
  7) when it does, and puts them back. Check it: on a clean tree, run
  `.desatendido/gate.sh` twice and `git status --porcelain` must still
  print nothing. If not, add to `.gitignore` what it generates (`dist/`,
  `coverage/`, `*.tsbuildinfo`, screenshots...) or take the `--fix` and
  `--write` flags out of the gate. Otherwise every `done` exits with 7
  and the whole queue stops.

  The project's git hooks (husky, lint-staged...) run only on the commit
  of `queue.sh done`; a hook that fails stops it with exit 4. Every other
  commit of `queue.sh` runs none of them: they only carry its
  own files, or they put the tree back (`block`, `recover`,
  `restore-outside`), and a failing hook must not leave the queue stuck.
- `.gitignore` with `logs/`, `AGENT_STOP` and the usual files that would
  otherwise count as out of task or block `queue.sh start`:
  `.DS_Store`, `*.swp`, `*~`, `.vite/`, `__pycache__/`, `coverage/`, `test-results/`, `playwright-report/`, and `LANZAR.md`, which you fill in after the launch
- Dev dependencies only unless the SPEC says otherwise. If a version
  breaks something, pin it and note it in `AGENTS.md`.
- With a UI: Playwright installed, and its configuration starts the
  server itself (`webServer`): `con-limite.sh` stops whatever a worker
  leaves running in the background, so a server started by hand is gone
  by the time the gate runs. For the design QA screenshots,
  `npx playwright screenshot` if its `--help` works; if not, one
  screenshot test outside the acceptance folder.

## 2. Documents

- `docs/SPEC.md`, 1 or 2 pages: what it does, inputs and errors (with
  their order if there are several), rules, out of scope and constraints.
- Fast mode: `PLAN.md` from `assets/PLAN.md`. Full mode: also
  `docs/tareas/Txx.md` with the same format per task and
  `docs/cierres/PLANTILLA.md` from `assets/CIERRE.md`.
- While writing the plan, check that the **tests do not step on each
  other**: an acceptance test checks only the behaviour of its task,
  never the whole output of the program if a later task will change it
  (with protected tests, that later task could never pass). If two tasks
  touch the same output, split them: a pure function and its test per
  task, and the integration in the last one.
- `STATUS.md` from `assets/STATUS.md`, with each task's test path in
  the Test column. Check it with `.desatendido/queue.sh next` (it must
  print the first task).
- `docs/LOG.md`, the Log `queue.sh` writes in, starting with the time of
  the first question: `# Log`, a blank line, then
  `- <date> <time> note: preparation started (first question)`.
- For each task, `.desatendido/allowed/Txx` with its "Files it may touch"
  from the plan, one path per line (a folder ends in `/`). Its test,
  `STATUS.md`, `docs/LOG.md` and `docs/DECISIONES.md` need not be listed.
  `queue.sh` measures every task against these lists, as they were when
  the task started: a task without one does not start. A task that needs a
  development dependency must list `package.json` and the lockfile (or
  their equivalents in the stack), here and in the plan.
- For each task, `.desatendido/qa/Txx` with the QA its risk asks for:
  `combined` (low risk) or `fidelity technical` (high risk), plus
  `design` if it touches the UI. `queue.sh done` checks it.
- The cases of each task as `assets/PLAN.md` says (by its inputs and
  states, not a fixed number), with the values computed by a script, not
  from memory.

## 3. Acceptance tests

1. One per task, skipped, from the cases in `PLAN.md`. With a UI, a
   Playwright test with assertions on the states the SPEC gives each
   screen (empty, error, result, disabled), not a screenshot: the
   screenshot is for the design QA.
2. Who writes them is never the implementer:
   - Fast mode: you. This session prepares and never implements.
   - Full mode: the QA role, with `lanzar-worker.sh`, the tests folder as
     allowed and its tool's **write** mode (`references/equipo.md`).
3. Verify them:
   - Fast mode: remove the skip locally, run them and see each one fail
     against the stubs for the right reason (the stub's "not
     implemented" or a wrong value; never an import error, a typo or a
     missing fixture). Put the skip back. A task that is algorithmically
     delicate gets a reference implementation only if it fits the budget;
     if not, mark it high risk.
   - Full mode: reference implementation in a temporary folder outside
     the repo; remove the skip locally, check that they pass and leave it
     as it was.
4. If a test is wrong, whoever wrote it fixes it.

## 4. Conventions

Short `AGENTS.md`: language, structure, contracts that do not change,
pinned versions, commit format and "Acceptance tests are never touched:
the queue removes the skip and they are read-only while you work". If
Claude is on the team: `ln -s AGENTS.md CLAUDE.md`.

## 5. Orchestrator and team

- `ORQUESTADOR.md` from `assets/ORQUESTADOR.md` (the gate is always
  `.desatendido/gate.sh`), with the real commands for each role
  (`references/lanzadores.md`). Replace `{WORKERS}` with the block of the
  launcher the user chose: `assets/workers-cli.md` or
  `assets/workers-orca.md`, never the other, and fill in its values.
- **The chosen launcher is kept.** If it cannot be used (for example
  `orca status --json` fails, or `orca skills get orchestration` is
  unknown), stop and say why: the user chooses whether to fix it or
  switch. Never switch on your own.
- Fill `{LANGUAGE}` with the user's language and `{AUTONOMY}` with the
  autonomy they chose (`references/equipo.md`).
- With Orca: run `orca skills get orchestration` once now, so the commands
  you write match the installed Orca, and fill `{ORCA_AGENTS}` with each
  role's `--agent` and `--model` (opencode takes no `--model`: its model
  goes in `opencode.json`).
- Models pinned in each command, or in the project configuration if the
  launcher does not let you pass them.
- If there is no native goal: `bucle.sh` configured (its `MAX_ROUNDS=1`
  test is a worker call: only if the budget has it, otherwise the first
  round is the test).
- **Smoke test** of every role **with the chosen launcher**, only where
  the table in section 0 says (with Orca: `worker-start`, read the answer
  with `worker-read`, then `worker-release`). Record it in the Checks of
  `equipo.md` with the date. When it is not run, the section "First
  worker of each role" of `ORQUESTADOR.md` stays: the orchestrator checks
  the model of the first worker of each role in the queue. When it ran or
  is recorded, remove that section.

## 6. Commit and launch

No approval here: the user gave it in the confirmation. `.desatendido/`
(scripts, `gate.sh`, `allowed/` and `qa/`) and `docs/LOG.md` go in the
commit. Commit "fase cero", tag `fase-cero` and push only if the user
said so in the confirmation (private repo unless they said otherwise).
No `.env`, keys or logs in the commit.

Then `references/lanzadores.md`. Right before the real launch, with the
counts:

```zsh
.desatendido/queue.sh note "preparation: queue launched at $(date +%H:%M), <minutes> minutes since the first question, <n> worker calls"
```

## 7. Final summary

The user reads it when they are back, so it stands alone: files created,
the gate checks ("acceptance folder excluded": the gate fails;
"gate run twice on a clean tree": `git status` still empty), tests
verified and how, smoke test and
dry run (run now, recorded on `<date>` or left to the queue), time used
against the budget, worker calls, decisions taken in phase zero, and how
to watch and stop the queue (`references/lanzadores.md`, "Tell the
user").
