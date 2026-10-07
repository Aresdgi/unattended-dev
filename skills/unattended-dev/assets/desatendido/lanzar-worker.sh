#!/usr/bin/env bash
# unattended-dev v8.1: launches a worker of any tool with a time limit,
# a full log and a warning if it touches files outside its task.
#
# Usage:
#   .desatendido/lanzar-worker.sh <role> <task> [options] -- <worker command...>
#
# Options:
#   --allowed "a.ts b.ts docs/"   Files or folders it may touch (default: none)
#   --timeout <seconds>           Time limit (default 1200 = 20 minutes)
#   --lines <n>                   Lines from the end of the log that are shown (default 30)
#
# Examples (each tool's command is checked with its --help):
#   .desatendido/lanzar-worker.sh implements T01 --allowed "src/dni.ts tests/acceptance/T01.test.ts" -- \
#       opencode run -m <provider/model> "Implement task T01 of PLAN.md..."
#   .desatendido/lanzar-worker.sh qa smoke -- claude -p --model haiku -- "Reply only: OK <your model>"
#
# Exit: 0 if the worker ended fine and touched nothing outside what is allowed;
#       3 if it touched files that were not allowed; 124 if it ran out of time;
#       any other code, the worker's own.
set -u

role="${1:?missing the role}"; task="${2:?missing the task}"; shift 2
allowed=""; limit=1200; lines=30
while [ $# -gt 0 ]; do
  case "$1" in
    --allowed) allowed="$2"; shift 2;;
    --timeout) limit="$2"; shift 2;;
    --lines) lines="$2"; shift 2;;
    --) shift; break;;
    *) echo "Unknown option: $1 (missing -- before the command?)" >&2; exit 2;;
  esac
done
[ $# -gt 0 ] || { echo "Missing the worker command after --" >&2; exit 2; }

mkdir -p logs
log="logs/${task}-${role}-$(date +%Y%m%d-%H%M%S)-$$.log"

# Snapshot of modified files: path and a hash of their content, to also
# notice changes in files that were already modified before the worker.
snapshot() {
  git status --porcelain --untracked-files=all 2>/dev/null \
    | sed -E 's/^.{3}//; s/^"//; s/"$//; s/.* -> //' | grep -v '^logs/' \
    | while IFS= read -r f; do
        if [ -f "$f" ]; then echo "$f $(git hash-object -- "$f")"; else echo "$f deleted"; fi
      done | sort
}
state_before=$(snapshot)

echo "Worker ${role} ${task}: $* " | cut -c1-200
echo "Log: ${log}"

# Portable time limit (macOS has no timeout): perl with an alarm.
perl -e '
  my $t = shift; my $pid = fork();
  if ($pid == 0) { setpgrp(0, 0); exec @ARGV or exit 127; }
  local $SIG{ALRM} = sub { kill "TERM", -$pid; sleep 5; kill "KILL", -$pid; exit 124; };
  alarm $t; waitpid($pid, 0); alarm 0; exit($? >> 8);
' "$limit" "$@" > "$log" 2>&1 < /dev/null
code=$?

state_after=$(snapshot)
changed=$( (comm -13 <(echo "$state_before") <(echo "$state_after"); comm -23 <(echo "$state_before") <(echo "$state_after")) \
  | sed -E 's/ [^ ]+$//' | sort -u)

outside=""
for f in $changed; do
  ok=0
  for p in $allowed; do
    case "$f" in "$p"|"$p"/*|"${p%/}"/*) ok=1;; esac
  done
  [ "$ok" = 1 ] || outside="$outside $f"
done

echo "----- last ${lines} lines -----"
tail -n "$lines" "$log"
echo "-----"
[ "$code" = 124 ] && echo "TIMEOUT: the worker went over ${limit} s and was stopped."
if [ -n "$outside" ]; then
  echo "OUT OF TASK:$outside"
  [ "$code" = 0 ] && code=3
fi
echo "Exit: ${code}"
exit "$code"
