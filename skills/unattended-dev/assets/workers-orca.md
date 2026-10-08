## Workers: Orca

<!-- unattended-dev v8.7. Phase zero pastes this block into ORQUESTADOR.md, in place of {WORKERS}, when the worker launcher is Orca. -->

Each worker runs in its own Orca tab, so the user can watch it, and its
tab is closed as soon as it is no longer needed. Never use
`lanzar-worker.sh` or a non-Orca subagent in this mode.

### Before the first task

1. Load Orca's own guide and follow it for every Orca command: resolve
   the executable as its `orchestration` skill says (below, `ORCA`) and
   run `ORCA skills get orchestration`. This file only adds the queue
   rules on top of it.
2. You have to be running inside an Orca terminal: `echo
   "$ORCA_TERMINAL_HANDLE"` must not be empty (Orca sets it in every
   terminal it opens; `orca status` does not say it in every version). If
   it is empty, **stop and report it**; never switch to another launcher
   on your own.
3. Bind one Run for the whole queue: `ORCA orchestration run-current
   --json`, or `ORCA orchestration run-create --objective "unattended
   queue of {PROJECT}" --json` if there is none. Record its id:
   `.desatendido/queue.sh note "Orca run <run_id>"`.

### For each worker

1. `.desatendido/vigilar-worker.sh begin <role> <Txx> --readonly "{TESTS_FOLDER}"`
2. Start it:

   ```zsh
   ORCA orchestration worker-start --spec "<spec>" --task-title "<Txx> <role>" --worktree current --agent <agent> [--model <model>] --json
   ```

   - The spec follows Orca's task-spec contract and is built from
     {PLAN}: **Target** (the task's files), **Change** (the task),
     **Constraints** (SPEC rules; never touch the tests), **Ownership**
     (only the allowed files; QA edits nothing), **Observable acceptance**
     (the task's acceptance test and the gate). It ends with: "When you
     finish, send worker_done as your preamble says, with OK or BLOCKED,
     the files you touched and 3 lines."
   - Agents and models: {ORCA_AGENTS}. Compare `launch.requested` with
     `launch.effective`; if they differ, record it with `.desatendido/queue.sh
     note "<Txx> <role>: asked <x>, got <y>"`.
   - If `worker-start` exits non-zero, do not relaunch: follow Orca's
     recovery reference.
3. Wait: `ORCA orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 1200000 --json`.
   Answer questions with `ORCA orchestration reply`, using the SPEC and
   the task. A timeout is a checkpoint, not a failure: inspect as Orca's
   guide says and never stop a worker without the positive proof it
   requires. Process every message before `--ack`.
4. When its `worker_done` arrives:
   `.desatendido/vigilar-worker.sh end <role> <Txx> --allowed "<task files>"`
   (QA: no `--allowed`). Exit 3 is OUT OF TASK: the worker **failed**,
   whatever it reported. `--outcome failed` is a failure too.

### Fixes reuse the implementer's tab

A fix goes to the same terminal, so no new tab opens:

```zsh
ORCA orchestration worker-start --spec "<fix spec>" --task-title "<Txx> fix <n>" --terminal <implementer_handle> --worktree current --json
```

Wrap it with `vigilar-worker.sh begin` / `end` like any worker.

### Closing tabs

- **QA workers**: `ORCA orchestration worker-release --dispatch <id> --json`
  right after their `worker_done` is processed.
- **Implementer or design worker**: keep its tab while the task may need
  fixes; release its latest Dispatch right after `queue.sh done` or
  `queue.sh block`.
- Only `worker-release`, and only for Dispatches you started. Never
  `terminal close` on a worker, never your own tab, never a tab you did
  not open. Orca keeps the tabs it considers the user's (for example
  `user_takeover`, after someone typed in one); that is correct. List
  them in the final report so the user closes them.
- Before the final report: `ORCA orchestration worker-list --run <run_id>
  --terminal-state reclaimable --json` must return none. Release what it
  lists, then report how many tabs were opened and released.
