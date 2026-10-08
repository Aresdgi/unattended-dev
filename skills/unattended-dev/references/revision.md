# Review after the session

Do it with the user when they come back with the result. {TAG} is
`fase-cero` or `<milestone>-start`.

## Checks

1. **What was decided without the user, first**: go through
   `docs/DECISIONES.md` with them, one by one, the ones of phase zero
   ("phase zero") and those of the queue. For each one they reject,
   propose how to undo it (the commit is in git) and add the right rule
   to the SPEC. Then whatever else phase zero did on its own: steps it
   skipped or left to the queue (smoke test, dry run) and, if it went
   over its budget, by how much (the "preparation" lines of
   `docs/LOG.md`).
2. Queue state: `.desatendido/queue.sh summary`, and the Log in
   `docs/LOG.md`.
3. Acceptance tests intact, with the tests of every DONE task:

   ```zsh
   .desatendido/guardia-tests.sh {TAG} <tests-folder> $(.desatendido/queue.sh tests)
   ```

4. Gate run by the user: `npm run gate` (or the project's one).
5. Manual test: 3 to 5 calls or screens with a known result, taken from
   the SPEC. Write the exact command.
6. Did the orchestrator read code or break a rule? Its final report
   lists the slips it noticed; also have the user search the session for
   reads of `src/` or of the tests while no task was failing (after a
   failure it may read the diff and the failing test), and for any edit
   of code (`claude attach <id>`, `tmux attach`
   or the log, depending on the launcher). If it kept answering "goal not
   met" after the queue finished, its goal was not the one in
   `references/lanzadores.md`.
7. Leftovers: background sessions (`claude agents`), tmux sessions
   (`tmux ls`), terminals left open in Orca or elsewhere, hung processes
   `caffeinate` and the time fuse (`kill $(cat logs/caffeinate.pid
   logs/fuse.pid)` if they are still alive). Close them. If there was an external loop, check
   `logs/bucle-*.log` and delete `AGENT_STOP` if it was left behind. If a
   worker exited with 3 (OUT OF TASK) or 124 (TIMEOUT), look at its log.
8. BLOCKED tasks: their work is in a backup branch, named in `docs/LOG.md`
   (`git branch --list 'queue/backup/*'`, then `git diff <task start>
   queue/backup/<Txx>-<date>`). Read the reason in the Log and propose
   whether to fix the task, the SPEC or the tests (supervised). Once
   nobody needs a backup branch, it can be deleted with `git branch -D`.
   To send a task back to the queue: `.desatendido/queue.sh set Txx
   PENDING`. `set` only takes PENDING and BLOCKED: DONE always goes
   through `queue.sh done` (allowed files, gate and QA). If the user
   finishes a task by hand, supervised, they edit its row in STATUS.md
   to DONE and commit it themselves.
9. **Launcher**: the one in `ORQUESTADOR.md` must be the one the user
   chose. With Orca, `orca orchestration worker-list --run <run_id>
   --terminal-state reclaimable --json` returns none, and no worker tabs
   are left open in Orca.
10. If everything is fine: `git push`.

## Results table

| Metric | Result |
| --- | --- |
| DONE / BLOCKED tasks | |
| Duration | |
| QA FAILs and fixes | |
| Acceptance tests intact (guard) | |
| Preparation: minutes (budget) and worker calls, from `docs/LOG.md` | |
| Time the user was needed | |
| Mode (fast or full) | |
| Launcher (claude --bg, tmux, loop, Orca tab) | |
| Final gate | |
| Manual test | |
| Team (orchestrator / implements / design / QA) | |
| Usage of each plan (before / after) | |
| Orchestrator tokens, if the tool reports them | |

## How to read it

- Full queue, intact tests and low usage: the system works for projects
  of this kind.
- If the orchestrator drifted (read code, touched tests, left tasks half
  done), note in which task it started. For the next queue of that size,
  split it into shorter milestones.
- Many QA FAILs on the same task usually mean a badly specified task, not
  a bad worker: review the SPEC before repeating.
