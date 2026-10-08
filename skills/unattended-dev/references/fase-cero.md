# Phase zero

Prepare the minimum for the orchestrator to work alone. Do not implement
any task from the queue and do not create scripts of your own: use the
ones in `.desatendido/` and, if there is a UI, a single screenshot test.

**Fast mode:** do it all in one go and ask for a single approval at the
end, before the commit. **Full mode:** show each step and wait for the OK.

## 0. Before starting

Say in one line the mode and how long you expect it to take (fast: about
15 minutes; full: between 30 and 60). If your tool shows the remaining
quota, look at it: if it is not enough for phase zero, say so before
starting.

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

  The project's git hooks (husky, lint-staged...) run on the commits of
  `queue.sh` that carry code (`done`, `block`, `recover`,
  `restore-outside`); a hook that fails stops the queue with exit 4. Its
  commits that only carry `STATUS.md` or `docs/DECISIONES.md` skip them
  (`--no-verify`).
- `.gitignore` with `logs/`, `AGENT_STOP` and the usual files that would
  otherwise count as out of task or block `queue.sh start`:
  `.DS_Store`, `*.swp`, `*~`, `.vite/`, `__pycache__/`, `coverage/`
- Dev dependencies only unless the SPEC says otherwise. If a version
  breaks something, pin it and note it in `AGENTS.md`.
- With a UI: Playwright installed and a screenshot test on mobile and
  desktop. If `npx playwright screenshot --help` works, use it and the
  test is not needed.

## 2. Documents

- `docs/SPEC.md`, 1 or 2 pages: what it does, inputs and errors (with
  their order if there are several), rules, out of scope and constraints.
- Fast mode: `PLAN.md` from `assets/PLAN.md`. Full mode: also
  `docs/tareas/Txx.md` with the same format per task and
  `docs/cierres/PLANTILLA.md` from `assets/CIERRE.md`.
- `STATUS.md` from `assets/STATUS.md`, with each task's test path in
  the Test column. Check it with `.desatendido/queue.sh next` (it must
  print the first task).
- For each task, `.desatendido/allowed/Txx` with its "Files it may touch"
  from the plan, one path per line (a folder ends in `/`). Its test,
  `STATUS.md` and `docs/DECISIONES.md` need not be listed. `queue.sh`
  measures every task against these lists, as they were when the task
  started: a task without one does not start. A task that needs a
  development dependency must list `package.json` and the lockfile (or
  their equivalents in the stack), here and in the plan.
- For a task whose plan asks for design QA,
  `.desatendido/qa/Txx` with `fidelity technical design`. Without the
  file, `queue.sh done` asks for fidelity and technical.
- Compute the values of the cases with a script, not from memory.

## 2b. Adversarial review of the SPEC

Before writing tests, a role that did not write the SPEC (normally QA,
through the chosen launcher) looks for what it leaves undefined: limits
of each input, empty and zero values, extremes that make a result
infinite, huge or negative, overflow, rounding, inputs that contradict
each other. Each gap comes back with a proposed rule.

Resolve them now, with the user, in **one** round of questions (the
proposals first, marked as recommended). In fast mode this is the only
extra stop before the final approval. Update the SPEC with the answers.
Gaps found here cost minutes; found during the queue they block tasks.

## 3. Acceptance tests

1. They are written by a role that is **not** the implementer (usually
   QA), with `lanzar-worker.sh` and the tests folder as allowed, from the
   cases in `PLAN.md`. One per task, skipped.
2. You verify them:
   - Algorithmic: reference implementation in a temporary folder outside
     the repo; remove the skip locally, check that they pass and leave it
     as it was.
   - UI: check that they fail against the stubs for the right reason.
3. If a test is wrong, the same role that wrote it fixes it.

## 4. Conventions

Short `AGENTS.md`: language, structure, contracts that do not change,
pinned versions, commit format and "Acceptance tests are never touched:
the queue removes the skip and they are read-only while you work". If Claude is on the team:
`ln -s AGENTS.md CLAUDE.md`.

## 5. Orchestrator and team

- `ORQUESTADOR.md` from `assets/ORQUESTADOR.md` (the gate is always
  `.desatendido/gate.sh`), with the real commands for each role (`references/lanzadores.md`). Replace `{WORKERS}` with
  the block of the launcher the user chose: `assets/workers-cli.md` or
  `assets/workers-orca.md`, never the other, and fill in its values.
- **The chosen launcher is kept.** If it cannot be used (for example
  `orca status --json` fails, or `orca skills get orchestration` is
  unknown), stop, tell the user why and let them choose: fix it or switch.
  Never switch on your own; note the decision in the Log of STATUS.md.
- Fill `{LANGUAGE}` with the user's language and `{AUTONOMY}` with the
  autonomy they chose (`references/equipo.md`).
- With Orca: run `orca skills get orchestration` once now, so the commands
  you write match the installed Orca, and fill `{ORCA_AGENTS}` with each
  role's `--agent` and `--model` (opencode takes no `--model`: its model
  goes in `opencode.json`).
- Models pinned in each command, or in the project configuration if the
  launcher does not let you pass them.
- If there is no native goal: `bucle.sh` configured and tested with
  `MAX_ROUNDS=1`.
- **Smoke test** of every role **with the chosen launcher** (with Orca:
  `worker-start`, read the answer with `worker-read`, then
  `worker-release`). Show it in a table: role, launcher, expected model,
  answer. Add two rows for the gate: "acceptance folder excluded in the
  runner configuration", expected "the gate fails"; and "gate run twice
  on a clean tree", expected "`git status` still empty". Each with what
  it did.

## 6. Approval and commit

Summarize in a few lines: files created, gate (with the guard), verified
tests and smoke test. `.desatendido/` (scripts, `gate.sh`, `allowed/` and
`qa/`) goes in the commit. With the user's OK: commit "fase cero", tag
`fase-cero` and push (private repo unless they say otherwise). No `.env`,
keys or logs in the commit.
