#!/usr/bin/env bash
# unattended-dev v8.6: external loop for orchestrators with no native goal.
# Relaunches the orchestrator, one task per round, with a clean context.
# Which task comes next is decided by queue.sh, not by the model.
#
# Usage: .desatendido/bucle.sh   (from the project root)
# Stop at the end of the current round: touch AGENT_STOP
set -u
QUEUE="$(dirname "$0")/queue.sh"

# Filled in by phase zero with the non-interactive form of the chosen
# orchestrator. The prompt arrives as the last argument. Examples (check
# them with --help):
#   ORCHESTRATOR_CMD=(claude -p --model opus)
#   ORCHESTRATOR_CMD=(codex exec -m <model>)
#   ORCHESTRATOR_CMD=(opencode run -m <provider/model>)
ORCHESTRATOR_CMD=({ORCHESTRATOR_CMD})

MAX_ROUNDS="${MAX_ROUNDS:-30}"
MAX_HOURS="${MAX_HOURS:-4}"
LOG="logs/bucle-$(date +%Y%m%d-%H%M).log"

mkdir -p logs
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

trap 'log "INTERRUPTED: the terminal was closed (HUP)"; exit 129' HUP
trap 'log "INTERRUPTED: terminated from outside (TERM)"; exit 143' TERM
trap 'log "INTERRUPTED: Ctrl+C"; exit 130' INT

[ -f ORQUESTADOR.md ] && [ -f STATUS.md ] || { log "WILL NOT START: ORQUESTADOR.md or STATUS.md is missing"; exit 1; }
[ -x "$QUEUE" ] || { log "WILL NOT START: $QUEUE is missing or not executable"; exit 1; }
case "${ORCHESTRATOR_CMD[*]}" in *"{ORCHESTRATOR_CMD}"*) log "WILL NOT START: fill in ORCHESTRATOR_CMD"; exit 1;; esac

# A task left IN PROGRESS was cut off by a previous session: save its
# changes and put it back to PENDING before anything else. If that fails
# (a stash that cannot be made), stop: going on would mix two tasks.
"$QUEUE" recover > logs/.recover 2>&1; recover_status=$?
cat logs/.recover | tee -a "$LOG"
[ "$recover_status" = 0 ] || { log "STOPPED: queue.sh recover failed (exit $recover_status)"; exit 1; }

start=$(date +%s)
for ((r = 1; r <= MAX_ROUNDS; r++)); do
  [ -f AGENT_STOP ] && { log "STOPPED: AGENT_STOP exists"; exit 0; }
  if (( $(date +%s) - start > MAX_HOURS * 3600 )); then
    log "STOPPED: reached the maximum of $MAX_HOURS hours"; exit 0
  fi

  if [ -n "$(git status --porcelain --untracked-files=all 2>/dev/null)" ]; then
    log "STOPPED: the working tree has changes that are not from the queue. Commit or stash them, or run the queue in its own worktree."
    git status --short | head -n 10 | tee -a "$LOG"
    exit 1
  fi

  task=$("$QUEUE" next 2>>"$LOG"); status=$?
  case "$status" in
    0) ;;
    1) log "QUEUE DONE: $("$QUEUE" summary)"; exit 0 ;;
    2) log "STOPPED: tasks left but none can start. $("$QUEUE" summary)"; exit 1 ;;
    *) log "STOPPED: queue.sh failed (exit $status)"; exit 1 ;;
  esac

  log "ROUND $r: $task"
  prompt="You are the orchestrator. Read ORQUESTADOR.md, STATUS.md and docs/SPEC.md.
Do ONLY task $task, following ORQUESTADOR.md from start to end: start it with
$QUEUE start $task and close it with $QUEUE done $task \"<summary>\" or
$QUEUE block $task \"<reason>\". Then finish."
  "${ORCHESTRATOR_CMD[@]}" "$prompt" 2>&1 | tee -a "$LOG"

  case "$("$QUEUE" state "$task")" in
    DONE|BLOCKED) log "$task finished. $("$QUEUE" summary)" ;;
    *) log "STOPPED: round $r ended without $task being DONE or BLOCKED. Check the log."; exit 1 ;;
  esac
done
log "STOPPED: reached the maximum of $MAX_ROUNDS rounds"
