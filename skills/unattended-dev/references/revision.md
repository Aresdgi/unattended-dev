# Review after the session

Do it with the user when they come back with the result. {TAG} is
`fase-cero` or `<milestone>-start`.

## Checks

1. Queue state: `.desatendido/queue.sh summary`
2. Acceptance tests intact, with the tests of every DONE task:

   ```zsh
   .desatendido/guardia-tests.sh {TAG} <tests-folder> $(.desatendido/queue.sh tests)
   ```

3. Gate run by the user: `npm run gate` (or the project's one).
4. Manual test: 3 to 5 calls or screens with a known result, taken from
   the SPEC. Write the exact command.
5. Did the orchestrator read code? Have the user search the session for
   reads of `src/` or of the tests (`claude attach <id>`, `tmux attach`
   or the log, depending on the launcher).
6. Leftovers: background sessions (`claude agents`), tmux sessions
   (`tmux ls`), terminals left open in Orca or elsewhere, hung processes
   and `caffeinate` (`kill $(cat logs/caffeinate.pid)` if it is still
   alive). Close them. If there was an external loop, check
   `logs/bucle-*.log` and delete `AGENT_STOP` if it was left behind. If a
   worker exited with 3 (OUT OF TASK) or 124 (TIMEOUT), look at its log.
7. BLOCKED tasks: `git stash list`. Read the reason in STATUS.md and
   propose whether to fix the task, the SPEC or the tests (supervised).
8. If everything is fine: `git push`.

## Results table

| Metric | Result |
| --- | --- |
| DONE / BLOCKED tasks | |
| Duration | |
| QA FAILs and fixes | |
| Acceptance tests intact (guard) | |
| Phase zero time and quota | |
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
