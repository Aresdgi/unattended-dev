# Orchestrator rules

<!-- unattended-dev v8.1. Fill in the values in braces and remove what does not apply. -->

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
.desatendido/lanzar-worker.sh <role> <Txx> --allowed "<task files>" -- <command> "<order>"
```

{ORCA_NOTE}

## Minimum context

- You only read STATUS.md, docs/SPEC.md and the current task in {PLAN}.
- You never read code, diffs, tests or full logs: what
  `lanzar-worker.sh` prints is enough.
- Keep the format of the STATUS.md table.

## On start

If a task is IN PROGRESS, a previous session was cut off: save its
changes with `git stash push -u -m "Txx interrupted"`, mark it PENDING and
note it in the Log.

## For each task

One at a time, in order and respecting dependencies.

1. Mark it IN PROGRESS.
2. Launch the role the task names (implements or design) with its allowed
   files. Order to the worker: "Implement task Txx of {PLAN}. Remove the
   skip of its test and nothing else in the tests. Reply only: OK or
   BLOCKED, files touched and 3 lines."
3. Gate, with the guard watching the tests of this task and of the DONE
   ones:
   `{GATE_WITH_TASKS}`
   Print only the exit code and, if it fails, the last 20 lines.
4. Read-only QA with the QA role, one per type. Answer: PASS or FAIL and
   at most 5 lines. FAIL by default if there is no evidence.

   | QA | When | What it checks |
   | --- | --- | --- |
   | Fidelity | Always | Does what the task and the SPEC ask, nothing invented or left out{SOURCES} |
   | Technical | Always | Bugs, edge cases, security, dead code |
   | Design | If it touches the UI | Mobile and desktop screenshots with `{SCREENSHOTS}`, empty and error states, accessibility |

5. If the gate fails, QA fails or the worker touches something outside
   (exit 3), pass those lines to the same role to fix and repeat the gate
   and the affected QA. At most 2 fixes. If it still fails: BLOCKED with
   the reason, and `git stash push -u -m "Txx blocked"`.
6. If it passes: commit "Txx: <summary>", DONE and one line in the Log.

## Surprises

- If a worker asks something, answer with the SPEC and the task. If you
  cannot, BLOCKED and move on.
- A task that depends on a BLOCKED one is BLOCKED too.

## Never

- Change the SPEC, the plan or the acceptance tests. If they are wrong:
  BLOCKED and the reason in one line.
- Install runtime dependencies, push, publish, deploy or anything
  irreversible.

## Report

- On each turn or round: "Progress: X DONE, Y BLOCKED, Z PENDING".
- At the end: run the gate with every DONE task and print the full
  output.
