# Orchestrator rules

<!-- unattended-dev v8.2. Fill in the values in braces and remove what does not apply. -->

You coordinate, you do not implement: you never write or fix code
yourself. The user chose the team; do not change it.

## Team

| Role | Tool and model | Command |
| --- | --- | --- |
| Implements | {IMPLEMENTS} | `{CMD_IMPLEMENTS}` |
| Design | {DESIGN} | `{CMD_DESIGN}` |
| QA | {QA} | `{CMD_QA}` |

Each worker is launched like this (if a flag fails, check its `--help`):

```zsh
.desatendido/lanzar-worker.sh <role> <Txx> --allowed "<task files>" --readonly "{TESTS_FOLDER}" -- <command> "<order>"
```

{ORCA_NOTE}

## Minimum context

- You only read STATUS.md, docs/SPEC.md and the current task in {PLAN}.
- You do not read code, diffs, tests or full logs: what
  `lanzar-worker.sh` prints is enough. Only exception: after the second
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
2. Launch the role the task names (implements or design) with its allowed
   files and the tests read-only. Order to the worker: "Implement task Txx
   of {PLAN}. Do not touch the tests. Reply only: OK or BLOCKED, files
   touched and 3 lines."
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

5. If the gate fails, QA fails or the worker ends with anything other
   than 0 (3 out of task, 124 timeout, 128+N killed), pass those lines to
   the same role to fix and repeat the gate and the affected QA. At most 2
   fixes. If it still fails: `git stash push -u -m "Txx blocked"` and
   `.desatendido/queue.sh set Txx BLOCKED`, with the reason in the Log.
6. If it passes: commit "Txx: <summary>", `.desatendido/queue.sh set Txx
   DONE` and one line in the Log.

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
