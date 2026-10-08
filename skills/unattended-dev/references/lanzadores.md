# Launchers

## Workers

**CLI with `lanzar-worker.sh` (default, works with any tool):**

```zsh
.desatendido/lanzar-worker.sh <role> <task> --allowed "<task files>" --readonly "<tests folder>" -- <role command> "<order>"
```

- Each role's command is its non-interactive form with the model made
  explicit and the flags of what it does (write or read-only), checked
  with `--help` (see `references/equipo.md`).
- If the command has flags that can swallow the order text (for example,
  file lists), put `--` before the order.
- QA is launched without `--allowed`: any change shows up as OUT OF TASK.
  Also use its tool's read-only mode if it has one.
- Exit codes: 0 fine; 3 touched files that were not allowed; 124 ran out
  of time.

**Orca (each worker in its own tab):** the rules are in
`assets/workers-orca.md`, which goes into `ORQUESTADOR.md`. In short:
follow Orca's own `orchestration` guide (`orca skills get orchestration`)
for every Orca command; wrap each worker with `vigilar-worker.sh begin` /
`end` for the same protections as the CLI; reuse the implementer's tab
for fixes; close tabs only with `worker-release` (never `terminal close`
on a worker), QA right away and the implementer when its task closes; and
finish with `worker-list --run <run_id> --terminal-state reclaimable`
returning none.

Check in its help which agents accept `--model`. If one does not (for
example opencode), its model goes in the project configuration
(`opencode.json` with the exact id). Look at `launch.effective` on each
start.

`orca orchestration` only works from inside a live Orca terminal (it needs
`ORCA_TERMINAL_HANDLE`; outside it fails with `no_active_sender_terminal`).
A session started with `claude --bg`, tmux or nohup is outside Orca. So
with Orca as the worker launcher, the orchestrator starts in an Orca tab
(see "Launch" below). Confirm it in the dry run.

## Smoke test

Once per machine: it is skipped when the Checks of `equipo.md` record one
for the same team in the last 7 days (`references/fase-cero.md` says
when else). With the chosen worker launcher, each role receives:

```text
Reply with a single line only: "OK <exact name of the model you are>". Do not touch any file.
```

If the answer is generic ("OK GPT"), confirm the model in the CLI header
or log. All green before launching; then record it in the Checks.

## Launch

It is decided in the interview, together with the team (the launch and
the hours are part of "the usual"):

1. **In the background** (recommended): nothing for the user to open.
2. **In a visible Orca tab**: only if `orca status` says the app is
   running. Mandatory when the worker launcher is Orca.
3. **The user launches it**: at the end of phase zero, give
   `assets/LANZAR.md` filled in instead of launching.

And the time limit (`<HOURS>`): propose about 30 minutes per task, at
least 2 hours. If the user says "no limit", drop clause (c) from the goal
and use 24 hours for `caffeinate` and the time fuse, only as a safety
net; tell them so in one line.

The orchestrator always starts in a NEW session, in the project folder,
with a clean context. You never orchestrate from the preparation session.

### Before the confirmation

What would stop phase zero later is checked or asked now, while the user
is still there:

- The tools of the team and of the mechanism are installed (`equipo.md`,
  inventory). If tmux is missing, its install goes in the confirmation.
- The orchestrator's folder is trusted. `claude --bg` refuses a folder
  that is not ("Workspace not trusted"): for a new folder, create it and
  ask the user to run `claude` once in it and accept the prompt, now.
  Codex asks "Trust this folder?" when it starts: the OK to accept it
  goes in the confirmation.
- The permission mode of the orchestrator, chosen (below).
- Your own tool: if it asks for permission before each command, phase
  zero stops at the first one. Tell the user to allow them for this
  session (in Claude Code, for example, auto mode) or that they will
  have to stay.

### 1. Choose the mechanism

| Orchestrator | Mechanism |
| --- | --- |
| Claude Code | `claude --bg` with `/goal` |
| Native goal but no background mode (for example Codex) | Detached tmux session; type the `/goal` with `tmux send-keys` |
| No native goal | `.desatendido/bucle.sh` with `nohup` |
| Worker launcher is Orca, or the user picked option 2 | Orca tab with `orca terminal create`; type the `/goal` with `orca terminal send` |

Check before using it:

- **Claude Code**: `claude --help` lists `--bg`, `--model`,
  `--permission-mode` and `-n`. `claude --bg` refuses to start in a
  folder that is not trusted ("Workspace not trusted"); that was settled
  before the confirmation. If it still happens, stop and say it. Without
  `-w` it works in the current folder (no worktree).
- **Permission mode**: the orchestrator runs shell commands with nobody
  watching, so a mode that asks for permission leaves it stuck. Offer the
  modes from `claude --help` (`auto` or `bypassPermissions`; for Codex,
  `-a never` with a sandbox that lets the workers reach the network) and
  let the user choose in the interview. Never `manual`, `acceptEdits` or
  `plan`.
- **tmux**: `command -v tmux`. If it is missing, install it
  (`brew install tmux`) only with the OK of the confirmation; without it,
  `bucle.sh` or an Orca tab.
- **Codex**: `codex -m <model> -a never -s danger-full-access` (its header
  then says "permissions: YOLO mode"). With `workspace-write` there is no
  network, so workers that call an API fail. In a folder Codex has not
  seen yet it stops at "Trust this folder?": with the OK of the
  confirmation, `tmux send-keys -t "ud-<project>" Enter` (the choice is saved in
  `~/.codex/config.toml`). It is ready when the screen shows "Ask Codex to
  do anything"; after the goal it shows "Goal active" and, at the end,
  "Goal achieved".
- **Your own permissions**: if you run under a safety classifier (for
  example Claude Code in `auto` mode), starting an orchestrator with no
  sandbox or approvals may be blocked. Do not work around it: stop, and
  leave the exact command for the user to run when they are back (in
  `LANZAR.md` and in your last message; in Claude Code, with the `!`
  prefix).
- **Orca as worker launcher**: if `orca terminal create` cannot open the
  tab (app closed, error), warn and propose the CLI worker launcher
  (`lanzar-worker.sh`), which does not depend on Orca. Update
  `ORQUESTADOR.md` if they accept.

### 2. Keep the Mac awake

Always with `caffeinate`, for the whole run:

- `bucle.sh`: wrap it, `nohup caffeinate -ims .desatendido/bucle.sh`. It
  is released when the loop ends.
- `claude --bg`, tmux or an Orca tab: the session stays open after the
  goal is met, so bound it by time:

  ```zsh
  mkdir -p logs && nohup caffeinate -ims -t $(( <HOURS> * 3600 + 1800 )) >/dev/null 2>&1 & echo $! > logs/caffeinate.pid
  ```

And a **time fuse** that stops the session even if its goal never ends
(a goal that cannot be met keeps the orchestrator turning, awake and
spending quota, until someone stops it). Right after the launch, with the
stop command of the mechanism (`claude stop <id>`, `tmux kill-session -t
"ud-<project>"`, `orca terminal close --terminal <handle>`):

```zsh
nohup sh -c 'sleep $(( <HOURS> * 3600 + 1800 )); <stop command>' >/dev/null 2>&1 & echo $! > logs/fuse.pid
```

`bucle.sh` needs no fuse: it cuts every round at `ROUND_TIMEOUT` seconds
(1 hour by default) or at the time left of `MAX_HOURS`, whichever comes
first, puts that round's task back to PENDING and stops. A task cut off
by the fuse goes back to PENDING on the next launch (`queue.sh recover`).

`-s` only works on AC power. Tell the user to keep the Mac plugged in:
on battery with the lid closed it will sleep anyway.

### 3. Dry run

Once per mechanism and machine: it is skipped when the Checks of
`equipo.md` record one for the same mechanism with the same flags, or
when the budget has no worker call left (`references/fase-cero.md`).
Then check after the real launch that it started (section 4).

Otherwise, before the real launch, the same mechanism with exactly the
same flags and a trivial goal that tests the whole chain: the launched
orchestrator starts one test worker with the chosen worker launcher and
releases it.

Trivial goal (replace the command with the real QA command from
`ORQUESTADOR.md`):

```text
Run once: .desatendido/lanzar-worker.sh qa dry-run --timeout 300 -- <QA command> "Reply with a single line only: OK <your model>. Do not touch any file."
Then print "DRY RUN <exit code> <last line of the worker>". The goal is met once that line is printed.
```

With Orca as the worker launcher, instead: `orca orchestration
run-current --json` (it must not fail), `worker-start --spec` with the
same order, `worker-read` and `worker-release`, then print `DRY RUN` and
the result.

Without a native goal, run the orchestrator command with that text as its
prompt, under `nohup`, instead of `bucle.sh`.

Check that it **starts and ends**: `claude agents --json` shows the
session with `"state": "done"`, or `tmux capture-pane -p` / `orca terminal
read` / the log shows the `DRY RUN` line with exit 0 (Codex also shows
"Goal achieved"). Then clean up
(`claude stop <id>` and `claude rm <id>`, `tmux kill-session`, `orca
terminal close`) and delete `logs/*dry-run*`. Record it in the Checks.
If it fails, fix it before the real launch; do not launch with a dry run
that did not pass, and if you cannot fix it, stop and say it.

### 4. Real launch

Right before it, the Log line with the launch time
(`references/fase-cero.md`, section 6). After it, do not leave changes in
the project folder: `queue.sh start` refuses to start a task while the
tree has changes that are not its own (`LANZAR.md` is in `.gitignore`).

The goal, with the values filled in:

```text
/goal You are the orchestrator: work as ORQUESTADOR.md says. The goal is met as soon as one of these is true: (a) `.desatendido/queue.sh summary` prints 0 PENDING and your last turn printed the full gate output ending without errors; (b) ORQUESTADOR.md told you to stop and report, and you did; (c) <HOURS> hours have passed since your first turn and STATUS.md is up to date. Only that end state counts. Mistakes in how you got there go in your final report once; they are never a reason to keep going, to redo finished work or to wait for an answer.
```

**Claude Code:**

```zsh
cd <project> && claude --bg -n "ud-<project>" --model <model> --permission-mode <mode> "<goal>"
```

It prints the session id. Watch: `claude agents`, `claude attach <id>`
(Left arrow goes back, Ctrl+Z drops to the shell, it keeps running),
`claude logs <id>`. Stop: `claude stop <id>`.

**tmux (native goal without background mode):**

```zsh
tmux new-session -d -s "ud-<project>" -x 200 -y 50 -c <project> "<interactive orchestrator command with model and permissions>"
# accept "Trust this folder?" if it shows up (with the user's OK), then wait for
# the input prompt (Codex: "Ask Codex to do anything") in: tmux capture-pane -p -t "ud-<project>"
tmux send-keys -t "ud-<project>" -l "<goal>"
tmux send-keys -t "ud-<project>" Enter
```

Send the text and the Enter separately, as above. Check with
`capture-pane` that the goal was accepted ("Goal active"). Watch: `tmux attach -t "ud-<project>"` (Ctrl+B then D to leave
it running) or `tmux capture-pane -p -t "ud-<project>" | tail -40`. Stop:
`tmux kill-session -t "ud-<project>"`.

**No native goal:**

```zsh
cd <project> && mkdir -p logs && MAX_HOURS=<HOURS> nohup caffeinate -ims .desatendido/bucle.sh > logs/bucle-nohup.out 2>&1 & echo $! > logs/bucle.pid
```

Watch: `tail -f logs/bucle-*.log`. Stop at the end of the current round:
`touch AGENT_STOP`; right now: `kill $(cat logs/bucle.pid)` (the
orchestrator call in progress may still finish its turn).

**Check that it started**, always, and above all when there was no dry
run: the session is alive (`claude agents`, `tmux capture-pane` with
"Goal active", the tab in Orca or `logs/bucle-*.log`) and, within 10
minutes, `docs/LOG.md` has a `started` line. If not, stop it, run the dry
run and launch again; if that fails too, stop and say it.

**Orca tab:**

```zsh
orca terminal create --worktree path:<project> --title "ud orchestrator" --command "<interactive orchestrator command>" --focus --json
orca terminal send --terminal <handle> --text "<goal>" --enter --json
```

Without a native goal, `--command "MAX_HOURS=<HOURS> .desatendido/bucle.sh"`
and nothing to send. Watch: the tab in Orca, or `orca terminal read
--terminal <handle>`. Stop: `orca terminal close --terminal <handle>`.

### 5. Tell the user

The user may not be there: this goes in your last message, with the
summary of phase zero (`references/fase-cero.md`). In a few lines:
mechanism, session id or name, how to watch it, how to stop it
(including `kill $(cat logs/caffeinate.pid)` if there is one), when the
time fuse fires (cancel: `kill $(cat logs/fuse.pid)`) and "when you are
back, come to this session and say: review the session". Write the same
into the "Launched for you" block of `LANZAR.md`.

## Keeping the orchestrator alive

1. **Native goal** if the tool has one (`/goal` or similar). Use the
   goal above as it is. Its condition must be an end state that can be
   checked by reading the conversation (the orchestrator prints the
   summary and the gate output), never how the work was done: "following
   the rules" or "read nothing else" can no longer be met after one slip,
   and the goal then loops forever. Every stop that `ORQUESTADOR.md` asks
   for must also meet it. If the tool allows a token budget, set it.
2. **Continue when the quota renews**, if the tool has it (in Claude
   Code, the option to continue automatically when the limit is hit).
   Check it in its configuration.
3. **`bucle.sh`** if there is no native goal: fill in `ORCHESTRATOR_CMD`
   with the orchestrator's non-interactive form and test it with
   `MAX_ROUNDS=1`.
