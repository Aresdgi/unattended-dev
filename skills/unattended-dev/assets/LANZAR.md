# How to launch the queue

<!-- unattended-dev v8.5. Fill in everything. If you launched it yourself, fill in "Launched for you" and delete "Launch it yourself"; if not, the other way round. -->

**Before:** note the quota left on each tool of the team and the time. If
one of them is not enough for the queue, wait for it to renew or switch
accounts before starting. {CONTINUE_NOTE}

Keep the Mac plugged in: `caffeinate` keeps it awake, but on battery with
the lid closed it will sleep anyway.

## Launched for you

- **Mechanism:** {MECHANISM} (dry run passed at {DRY_RUN_TIME})
- **Session:** {SESSION_ID}
- **Watch it:** `{WATCH_CMD}`
- **Stop it:** `{STOP_CMD}`
- **Keep-awake:** `caffeinate` until {CAFFEINATE_UNTIL}; stop it early with `kill $(cat logs/caffeinate.pid)`

## Launch it yourself

### A. With a native goal ({TOOL})

1. New {TOOL} session in {PROJECT}, model {MODEL}, with permissions to
   work without asking for approval.
2. Paste this and read the answer:

```text
You are the orchestrator. Read ORQUESTADOR.md, STATUS.md and docs/SPEC.md,
nothing else. Tell me in 5 lines how you are going to work and the exact
commands you will use, and wait.
```

3. If it fits, launch:

```text
{GOAL_COMMAND} Every task in STATUS.md is DONE or BLOCKED following
ORQUESTADOR.md, and your last turn printed the full gate output ending
without errors. If you have been at it for {HOURS} hours, stop and leave
STATUS.md up to date.
```

### B. With the external loop

```zsh
cd {PROJECT} && mkdir -p logs && MAX_HOURS={HOURS} caffeinate -ims .desatendido/bucle.sh
```

To stop at the end of the current round: `touch AGENT_STOP`.

## While it works

Do not write to it, and do not edit files in the project folder: the queue
refuses to start a task while the tree has changes that are not its own.
If you want to keep working on the repo, do it in a worktree of your own
(`git worktree add ../{PROJECT}-mine`). Check that the first worker uses
the expected model.
To follow progress:

```zsh
cd {PROJECT} && git log --oneline -10 && grep -E "PENDING|IN PROGRESS|DONE|BLOCKED" STATUS.md
```

If it gets cut off (quota, laptop asleep...), launch it again the same way:
the orchestrator resumes whatever was left IN PROGRESS.

## When it finishes

Go back to the session where you prepared it and say "review the session".
