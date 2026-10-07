#!/usr/bin/env bash
# unattended-dev v8.2: deterministic queue state. The orchestrator and
# bucle.sh call this instead of deciding by reading the table themselves.
#
# Reads and writes the queue table in STATUS.md (or $STATUS_FILE):
#   | Task | Title | Depends on | Test | State |
#   | T01  | ...   | none       | tests/acceptance/T01.test.ts | PENDING |
# States: PENDING, IN PROGRESS, DONE, BLOCKED. "Depends on" is "none" or a
# comma-separated list of task ids.
#
# Usage (from the project root):
#   queue.sh next          Print the next PENDING task whose dependencies are
#                          all DONE. Marks as BLOCKED any PENDING task that
#                          depends on a BLOCKED one. Exit 0 found, 1 queue
#                          finished, 2 tasks left but none can start.
#   queue.sh recover       Every IN PROGRESS task was cut off: stash pending
#                          changes as "<task> interrupted" and set it PENDING.
#   queue.sh start <task>  Set it IN PROGRESS and remove the skip from its
#                          test, so the worker never has to touch tests.
#   queue.sh set <task> <PENDING|IN PROGRESS|DONE|BLOCKED>
#   queue.sh tests         Print the tests of IN PROGRESS and DONE tasks (for
#                          guardia-tests.sh: they must have no skip).
#   queue.sh state <task>  Print the state of one task.
#   queue.sh summary       One line: "Progress: X DONE, Y BLOCKED, Z PENDING".
set -u
STATUS="${STATUS_FILE:-STATUS.md}"
case "${1:-}" in next|recover|start|set|state|tests|summary) ;; *) sed -n "2,28p" "$0"; exit 3;; esac
[ -f "$STATUS" ] || { echo "queue: $STATUS not found" >&2; exit 3; }

# Rows of the queue table as "id<TAB>deps<TAB>test<TAB>state".
rows() {
  awk -F'|' '
    NF >= 7 && $2 ~ /^[[:space:]]*[A-Za-z]*[0-9]+[[:space:]]*$/ {
      for (i = 2; i <= 6; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i) }
      print $2 "\t" $4 "\t" $5 "\t" $6
    }' "$STATUS"
}

state_of() { rows | awk -F'\t' -v t="$1" '$1 == t { print $4 }'; }

set_state() {
  local task="$1" new="$2" tmp
  case "$new" in PENDING|"IN PROGRESS"|DONE|BLOCKED) ;; *) echo "queue: invalid state: $new" >&2; return 3;; esac
  [ -n "$(state_of "$task")" ] || { echo "queue: unknown task: $task" >&2; return 3; }
  tmp=$(mktemp)
  awk -F'|' -v OFS='|' -v t="$task" -v s="$new" '
    NF >= 7 { id = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
              if (id == t) { $6 = " " s " " } }
    { print }' "$STATUS" > "$tmp" && cat "$tmp" > "$STATUS"
  rm -f "$tmp"
}

# Remove skip marks from one test file (same marks guardia-tests.sh knows).
unskip() {
  local f="$1" tmp
  [ -f "$f" ] || { echo "queue: test not found: $f" >&2; return 3; }
  tmp=$(mktemp)
  sed -E \
    -e '/^[[:space:]]*@pytest\.mark\.skip(\(.*\))?[[:space:]]*$/d' \
    -e 's/(t\.Skip|this\.skip)\([^)]*\)[[:space:]]*;?[[:space:]]*//g' \
    -e 's/\.skip\(/(/g' \
    -e 's/(^|[^A-Za-z0-9_])x(it|describe|test)\(/\1\2(/g' \
    "$f" > "$tmp" && cat "$tmp" > "$f"
  rm -f "$tmp"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  next)
    # Propagate BLOCKED to PENDING tasks that depend on a BLOCKED task.
    changed=1
    while [ "$changed" = 1 ]; do
      changed=0
      blocked=$(rows | awk -F'\t' '$4 == "BLOCKED" { print $1 }')
      for t in $(rows | awk -F'\t' '$4 == "PENDING" { print $1 }'); do
        deps=$(rows | awk -F'\t' -v t="$t" '$1 == t { print $2 }' | tr ',' ' ')
        for d in $deps; do
          if echo "$blocked" | grep -qx "$d"; then
            set_state "$t" BLOCKED; echo "queue: $t BLOCKED because $d is BLOCKED" >&2; changed=1; break
          fi
        done
      done
    done
    for t in $(rows | awk -F'\t' '$4 == "PENDING" { print $1 }'); do
      deps=$(rows | awk -F'\t' -v t="$t" '$1 == t { print $2 }' | tr ',' ' ')
      ready=1
      for d in $deps; do
        [ "$d" = none ] && continue
        [ "$(state_of "$d")" = DONE ] || { ready=0; break; }
      done
      [ "$ready" = 1 ] && { echo "$t"; exit 0; }
    done
    if rows | awk -F'\t' '$4 == "PENDING" || $4 == "IN PROGRESS"' | grep -q .; then
      echo "queue: tasks left but none can start (check dependencies or IN PROGRESS)" >&2; exit 2
    fi
    exit 1 ;;
  recover)
    for t in $(rows | awk -F'\t' '$4 == "IN PROGRESS" { print $1 }'); do
      if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        git stash push -u -q -m "$t interrupted" && echo "queue: $t interrupted, changes saved in stash \"$t interrupted\""
      fi
      set_state "$t" PENDING && echo "queue: $t back to PENDING"
    done ;;
  start)
    task="${1:?queue start <task>}"
    [ "$(state_of "$task")" = PENDING ] || { echo "queue: $task is not PENDING" >&2; exit 3; }
    test_file=$(rows | awk -F'\t' -v t="$task" '$1 == t { print $3 }')
    set_state "$task" "IN PROGRESS"
    if [ -n "$test_file" ] && [ "$test_file" != none ]; then unskip "$test_file" || exit 3; echo "$test_file"; fi ;;
  set)
    set_state "${1:?queue set <task> <state>}" "${*:2}" ;;
  state)
    s=$(state_of "${1:?queue state <task>}"); [ -n "$s" ] || { echo "queue: unknown task: $1" >&2; exit 3; }; echo "$s" ;;
  tests)
    rows | awk -F'\t' '($4 == "IN PROGRESS" || $4 == "DONE") && $3 != "" && $3 != "none" { print $3 }' ;;
  summary)
    rows | awk -F'\t' '{ n[$4]++ } END { printf "Progress: %d DONE, %d BLOCKED, %d PENDING\n", n["DONE"], n["BLOCKED"], n["PENDING"] + n["IN PROGRESS"] }' ;;
  *)
    sed -n "2,27p" "$0"; exit 3 ;;
esac
