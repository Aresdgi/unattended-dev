#!/usr/bin/env bash
# unattended-dev v8.1: external loop for orchestrators with no native goal.
# Relaunches the orchestrator, one task per round, with a clean context.
#
# Usage: .desatendido/bucle.sh   (from the project root)
# Stop at the end of the current round: touch AGENT_STOP
set -u

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

PROMPT='You are the orchestrator. Read ORQUESTADOR.md, STATUS.md and docs/SPEC.md.
Do ONLY the next PENDING task whose dependencies are DONE, following
ORQUESTADOR.md from start to end (including the commit or the stash), and
finish. If there is no task left that can be done, write one line
"QUEUE DONE" and finish.'

mkdir -p logs
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

trap 'log "INTERRUPTED: the terminal was closed (HUP)"; exit 129' HUP
trap 'log "INTERRUPTED: terminated from outside (TERM)"; exit 143' TERM
trap 'log "INTERRUPTED: Ctrl+C"; exit 130' INT

[ -f ORQUESTADOR.md ] && [ -f STATUS.md ] || { log "WILL NOT START: ORQUESTADOR.md or STATUS.md is missing"; exit 1; }
case "${ORCHESTRATOR_CMD[*]}" in *"{ORCHESTRATOR_CMD}"*) log "WILL NOT START: fill in ORCHESTRATOR_CMD"; exit 1;; esac

start=$(date +%s)
for ((r = 1; r <= MAX_ROUNDS; r++)); do
  [ -f AGENT_STOP ] && { log "STOPPED: AGENT_STOP exists"; exit 0; }
  grep -q "| PENDING |" STATUS.md || { log "QUEUE DONE: no PENDING tasks left"; exit 0; }
  if (( $(date +%s) - start > MAX_HOURS * 3600 )); then
    log "STOPPED: reached the maximum of $MAX_HOURS hours"; exit 0
  fi

  before=$(git rev-parse HEAD 2>/dev/null; git stash list | wc -l)
  log "ROUND $r"
  "${ORCHESTRATOR_CMD[@]}" "$PROMPT" 2>&1 | tee -a "$LOG" | tee logs/.last-round
  after=$(git rev-parse HEAD 2>/dev/null; git stash list | wc -l)

  grep -q "QUEUE DONE" logs/.last-round && { log "QUEUE DONE according to the orchestrator"; exit 0; }
  if [ "$before" = "$after" ]; then
    log "STOPPED: round $r made no commit and no stash. Check the log."
    exit 1
  fi
done
log "STOPPED: reached the maximum of $MAX_ROUNDS rounds"
