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
- A gate command that starts with the guard and goes on with typecheck,
  tests and build. For example:
  `.desatendido/guardia-tests.sh fase-cero tests/acceptance && npm run typecheck && npm test && npm run build`
- `.gitignore` with `logs/` and `AGENT_STOP`.
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
- `STATUS.md` from `assets/STATUS.md`.
- Compute the values of the cases with a script, not from memory.

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
pinned versions, commit format and "Acceptance tests are not touched
except to remove the skip of your task". If Claude is on the team:
`ln -s AGENTS.md CLAUDE.md`.

## 5. Orchestrator and team

- `ORQUESTADOR.md` from `assets/ORQUESTADOR.md`, with the real commands
  for each role (`references/lanzadores.md`).
- Models pinned in each command, or in the project configuration if the
  launcher does not let you pass them.
- If there is no native goal: `bucle.sh` configured and tested with
  `MAX_ROUNDS=1`.
- **Smoke test** of every role. Show it in a table: role, expected model,
  answer.

## 6. Approval and commit

Summarize in a few lines: files created, gate (with the guard), verified
tests and smoke test. With the user's OK: commit "fase cero", tag
`fase-cero` and push (private repo unless they say otherwise). No `.env`,
keys or logs in the commit.
