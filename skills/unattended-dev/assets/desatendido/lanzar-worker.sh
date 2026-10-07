#!/usr/bin/env bash
# unattended-dev v8.2: launches a worker of any tool with a time limit,
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
head_before=$(git rev-parse -q --verify HEAD 2>/dev/null || echo none)

restore_perms() { for p in $readonly_paths; do [ -e "$p" ] && chmod -R u+w "$p"; done; }
for p in $readonly_paths; do [ -e "$p" ] && chmod -R a-w "$p"; done
trap restore_perms EXIT

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
restore_perms

state_after=$(snapshot)
changed=$( (comm -13 <(echo "$state_before") <(echo "$state_after"); comm -23 <(echo "$state_before") <(echo "$state_after")) \
  | sed -E 's/ [^ ]+$//'
  # Files changed by commits the worker made, which git status no longer shows.
  head_after=$(git rev-parse -q --verify HEAD 2>/dev/null || echo none)
  if [ "$head_before" != "$head_after" ]; then
    if [ "$head_before" = none ]; then git ls-tree -r --name-only HEAD
    else git diff --name-only "$head_before" "$head_after"; fi
  fi )
changed=$(echo "$changed" | grep -v '^logs/' | grep -v '^$' | sort -u)

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
[ "$code" -gt 128 ] && [ "$code" != 124 ] && echo "KILLED: the worker was stopped by signal $((code - 128))."
if [ -n "$outside" ]; then
  echo "OUT OF TASK:$outside"
  [ "$code" = 0 ] && code=3
fi
echo "Exit: ${code}"
exit "$code"
