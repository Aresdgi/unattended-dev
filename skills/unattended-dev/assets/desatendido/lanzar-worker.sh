#!/usr/bin/env bash
# unattended-dev v8.7: launches a worker of any tool with a time limit,
# a full log and a warning if it touches files outside its task.
#
# Usage:
#   .desatendido/lanzar-worker.sh <role> <task> [options] -- <worker command...>
#
# Options:
#   --allowed "a.ts b.ts docs/"   Files or folders it may touch (default: none)
#   --readonly "tests/acceptance" Files or folders made read-only while the worker
#                                 runs (write permission is restored afterwards)
#   --timeout <seconds>           Time limit (default 1200 = 20 minutes)
#   --lines <n>                   Lines from the end of the log that are shown (default 30)
#
# Examples (each tool's command is checked with its --help):
#   .desatendido/lanzar-worker.sh implements T01 --allowed "src/dni.ts" --readonly "tests/acceptance" -- \
#       opencode run -m <provider/model> "Implement task T01 of PLAN.md..."
#   .desatendido/lanzar-worker.sh qa smoke -- claude -p --model haiku -- "Reply only: OK <your model>"
#
# Exit: 0 if the worker ended fine and touched nothing outside what is allowed;
#       3 if it touched files that were not allowed (committed or not);
#       124 if it ran out of time; 128+N if it was killed by signal N;
#       any other code, the worker's own.
#
# The protections are those of vigilar-worker.sh (begin before, end after).
# This detects changes after they happen; it does not sandbox the worker.
set -u

role="${1:?missing the role}"; task="${2:?missing the task}"; shift 2
allowed=""; readonly_paths=""; limit=1200; lines=30
while [ $# -gt 0 ]; do
  case "$1" in
    --allowed) allowed="$2"; shift 2;;
    --readonly) readonly_paths="$2"; shift 2;;
    --timeout) limit="$2"; shift 2;;
    --lines) lines="$2"; shift 2;;
    --) shift; break;;
    *) echo "Unknown option: $1 (missing -- before the command?)" >&2; exit 2;;
  esac
done
[ $# -gt 0 ] || { echo "Missing the worker command after --" >&2; exit 2; }

mkdir -p logs
log="logs/${task}-${role}-$(date +%Y%m%d-%H%M%S)-$$.log"

VIGILAR="$(dirname "$0")/vigilar-worker.sh"
[ -x "$VIGILAR" ] || { echo "Missing $VIGILAR" >&2; exit 2; }
"$VIGILAR" begin "$role" "$task" --readonly "$readonly_paths" || exit 2
trap '"$VIGILAR" end "$role" "$task" >/dev/null 2>&1' EXIT

echo "Worker ${role} ${task}: $* " | cut -c1-200
echo "Log: ${log}"

# Portable time limit (macOS has no timeout): perl with an alarm. A worker
# killed by a signal returns 128+signal, never 0.
perl -e '
  my $t = shift; my $pid = fork();
  if ($pid == 0) { setpgrp(0, 0); exec @ARGV or exit 127; }
  local $SIG{ALRM} = sub { kill "TERM", -$pid; sleep 5; kill "KILL", -$pid; exit 124; };
  alarm $t; waitpid($pid, 0); my $s = $?; alarm 0;
  exit(128 + ($s & 127)) if ($s & 127);
  exit($s >> 8);
' "$limit" "$@" > "$log" 2>&1 < /dev/null
code=$?
trap - EXIT
outside=$("$VIGILAR" end "$role" "$task" --allowed "$allowed")

echo "----- last ${lines} lines -----"
tail -n "$lines" "$log"
echo "-----"
[ "$code" = 124 ] && echo "TIMEOUT: the worker went over ${limit} s and was stopped."
[ "$code" -gt 128 ] && [ "$code" != 124 ] && echo "KILLED: the worker was stopped by signal $((code - 128))."
if [ -n "$outside" ]; then
  echo "$outside"
  [ "$code" = 0 ] && code=3
fi
echo "Exit: ${code}"
exit "$code"
