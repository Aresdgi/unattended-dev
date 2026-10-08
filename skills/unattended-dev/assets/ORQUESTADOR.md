# Orchestrator rules

<!-- unattended-dev v8.5. Fill in the values in braces and remove what does not apply. {WORKERS} is replaced by assets/workers-cli.md or assets/workers-orca.md, whichever launcher the user chose, never the other. -->

You coordinate, you do not implement: you never write or fix code
yourself. The user chose the team; do not change it.

## Team

| Role | Tool and model | Command |
| --- | --- | --- |
| Implements | {IMPLEMENTS} | `{CMD_IMPLEMENTS}` |
| Design | {DESIGN} | `{CMD_DESIGN}` |
| QA | {QA} | `{CMD_QA}` |

Worker launcher: **{LAUNCHER}**, chosen by the user. Use only that one.

{WORKERS}

## Minimum context

- You only read STATUS.md, docs/SPEC.md and the current task in {PLAN}.
- You do not read code, diffs, tests or full logs: the worker's short
  report and the launcher's summary are enough. Only exception: after the second
  failed fix of a task, you may read the failing test and the function it
  tests (nothing else) to decide between BLOCKED and a clearer order.
- Never edit the STATUS.md table by hand: use `.desatendido/queue.sh`.

## On start

Run `.desatendido/queue.sh recover`: any task left IN PROGRESS was cut
off, so its changes go to a stash and it goes back to PENDING. Note it in
the Log.

## For each task

One at a time. `.desatendido/queue.sh next` says which one (it already
respects dependencies and marks as BLOCKED what depends on a BLOCKED
task). Exit 1 means the queue is finished; exit 2, nothing can start.

1. `.desatendido/queue.sh start Txx`: marks it IN PROGRESS and removes the
   skip from its test.
2. Launch the role the task names (implements or design) as "Workers"
   says, with its allowed files and the tests read-only. Order to the
   worker: "Implement task Txx of {PLAN}. Do not touch the tests. Reply
   only: OK or BLOCKED, files touched and 3 lines."
3. Gate, with the guard watching the tests that `queue.sh tests` lists
   (this task and the DONE ones):
   `{GATE_WITH_TASKS}`
   Print only the exit code and, if it fails, the last 20 lines.
4. Read-only QA with the QA role, one per type. Answer: PASS or FAIL and
   at most 5 lines. FAIL by default if there is no evidence.

   | QA | When | What it checks |
   | --- | --- | --- |
   | Fidelity | Always | Does what the task and the SPEC ask, nothing invented or left out{SOURCES} |
   | Technical | Always | Bugs, edge cases, security, dead code |
   | Design | If it touches the UI | Mobile and desktop screenshots with `{SCREENSHOTS}`, empty and error states, accessibility |

5. If the gate fails, QA fails or the worker **failed** (as "Workers"
   defines it: out of task, timeout, killed or a failed report), pass
   those lines to the same role to fix and repeat the gate and the affected QA. At most 2
   fixes. If it still fails: `.desatendido/queue.sh block Txx "<reason>"`
   (it stashes the task's work and commits BLOCKED in one step).
6. If it passes: `.desatendido/queue.sh done Txx "<summary>"` (it marks
   DONE and commits the work and the state together).

Never commit, stash or edit STATUS.md yourself: `queue.sh` does it so the
state and the work can never drift apart. If a `queue.sh` command fails
with exit 4, stop and report it: something in git needs a human. If
`queue.sh start` refuses because the tree has changes that are not from
the queue, do not commit or stash them: stop and report which files.

## Surprises

- If a worker asks something, answer with the SPEC and the task. If you
  cannot, BLOCKED and move on.
- A task that depends on a BLOCKED one is BLOCKED too (`queue.sh next`
  does it).

## Never

- Change the SPEC, the plan or the acceptance tests. If they are wrong:
  BLOCKED and the reason in one line.
- Install runtime dependencies, push, publish, deploy or anything
  irreversible.

## Report

- On each turn or round: the line `.desatendido/queue.sh summary` prints.
- At the end: run the gate with every DONE task and print the full
  output.
