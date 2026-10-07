#!/usr/bin/env bash
# unattended-dev v8.4: deterministic queue state. The orchestrator and
# bucle.sh call this instead of deciding by reading the table themselves.
#
# Reads and writes the queue table in STATUS.md (or $STATUS_FILE):
#   | Task | Title | Depends on | Test | State |
#   | T01  | ...   | none       | tests/acceptance/T01.test.ts | PENDING |
# States: PENDING, IN PROGRESS, DONE, BLOCKED. "Depends on" is "none" or a
# comma-separated list of task ids.
#
# Every state change is committed at once, so a stash or a crash can never
# bring back an old state. Closing a task is one atomic command.
#
# Usage (from the project root):
#   queue.sh next                 Print the next PENDING task whose dependencies
#                                 are all DONE (BLOCKED spreads to the tasks that
#                                 depend on it). Exit 0 found, 1 queue finished,
#                                 2 tasks left but none can start.
#   queue.sh start <task>         IN PROGRESS (committed) and remove the skip from
#                                 its test (not committed: it is part of the task).
#                                 Refuses if the working tree has other changes, so
#                                 done and block only ever take this task's work.
#   queue.sh done <task> <msg>    DONE and commit everything as "<task>: <msg>".
#   queue.sh block <task> <why>   Stash the task's changes, then BLOCKED (committed).
#   queue.sh recover              Every IN PROGRESS task was cut off: stash its
#                                 changes as "<task> interrupted", then PENDING.
#   queue.sh set <task> <state>   Low level: change and commit one state.
#   queue.sh state <task>         Print the state of one task.
#   queue.sh tests                Tests of IN PROGRESS and DONE tasks (for
#                                 guardia-tests.sh: they must have no skip).
#   queue.sh summary              "Progress: X DONE, Y BLOCKED, Z PENDING".
#
# Exit 3: wrong usage or state. Exit 4: a git step failed; nothing was marked.
set -u
STATUS="${STATUS_FILE:-STATUS.md}"
case "${1:-}" in next|start|done|block|recover|set|state|tests|summary) ;; *) sed -n "2,31p" "$0"; exit 3;; esac
[ -f "$STATUS" ] || { echo "queue: $STATUS not found" >&2; exit 3; }
git rev-parse -q --verify HEAD >/dev/null 2>&1 || { echo "queue: needs a git repo with at least one commit" >&2; exit 3; }

# Rows of the queue table as "id<TAB>deps<TAB>test<TAB>state".
rows() {
  awk -F'|' '
    NF >= 7 && $2 ~ /^[[:space:]]*[A-Za-z]*[0-9]+[[:space:]]*$/ {
      for (i = 2; i <= 6; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i) }
      print $2 "\t" $4 "\t" $5 "\t" $6
    }' "$STATUS"
}

state_of() { rows | awk -F'\t' -v t="$1" '$1 == t { print $4 }'; }

write_state() { # change the state in the file only
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

commit_status() { # commit STATUS.md alone, if it changed
  git diff --quiet HEAD -- "$STATUS" 2>/dev/null && return 0
  git add -- "$STATUS" && git commit -q -m "$1" -- "$STATUS" \
    || { echo "queue: could not commit $STATUS" >&2; return 4; }
}

set_state() { # change the state and commit it; on failure, put it back
  local task="$1" new="$2" old
  old=$(state_of "$task")
  write_state "$task" "$new" || return $?
  commit_status "queue: $task $new" || { write_state "$task" "$old"; git checkout -q HEAD -- "$STATUS" 2>/dev/null; return 4; }
}

stash_work() { # stash everything except STATUS.md; fail loudly
  local msg="$1"
  commit_status "queue: save $STATUS before stash" || return 4
  [ -z "$(git status --porcelain 2>/dev/null)" ] && return 0
  git stash push -u -q -m "$msg" || { echo "queue: git stash failed; nothing was marked" >&2; return 4; }
  [ -z "$(git status --porcelain 2>/dev/null)" ] || { echo "queue: changes left after stash; nothing was marked" >&2; return 4; }
  echo "queue: changes saved in stash \"$msg\""
}

unskip() { # remove skip marks from one test file (the marks guardia-tests.sh knows)
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

need_clean_tree() { # nothing but the queue may have changes when a task starts
  local dirty
  dirty=$(git status --porcelain --untracked-files=all 2>/dev/null)
  [ -z "$dirty" ] && return 0
  echo "queue: the working tree has changes that are not part of $1:" >&2
  echo "$dirty" | head -n 10 | sed 's/^/  /' >&2
  echo "queue: commit or stash them first, or run the queue in its own worktree (git worktree add)." >&2
  exit 3
}

need_state() { # need_state <task> <state>
  local s; s=$(state_of "$1")
  [ -n "$s" ] || { echo "queue: unknown task: $1" >&2; exit 3; }
  [ "$s" = "$2" ] || { echo "queue: $1 is $s, not $2" >&2; exit 3; }
}

cmd="$1"; shift
case "$cmd" in
  next)
    changed=1
    while [ "$changed" = 1 ]; do
      changed=0
      blocked=$(rows | awk -F'\t' '$4 == "BLOCKED" { print $1 }')
      for t in $(rows | awk -F'\t' '$4 == "PENDING" { print $1 }'); do
        deps=$(rows | awk -F'\t' -v t="$t" '$1 == t { print $2 }' | tr ',' ' ')
        for d in $deps; do
          if echo "$blocked" | grep -qx "$d"; then
            set_state "$t" BLOCKED || exit 4
            echo "queue: $t BLOCKED because $d is BLOCKED" >&2; changed=1; break
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
  start)
    task="${1:?queue start <task>}"; need_state "$task" PENDING; need_clean_tree "$task"
    test_file=$(rows | awk -F'\t' -v t="$task" '$1 == t { print $3 }')
    set_state "$task" "IN PROGRESS" || exit 4
    if [ -n "$test_file" ] && [ "$test_file" != none ]; then unskip "$test_file" || exit 3; echo "$test_file"; fi ;;
  done)
    task="${1:?queue done <task> <message>}"; shift; msg="${*:-done}"
    need_state "$task" "IN PROGRESS"
    write_state "$task" DONE || exit 3
    if ! { git add -A && git commit -q -m "$task: $msg"; }; then
      write_state "$task" "IN PROGRESS"; git reset -q -- "$STATUS" 2>/dev/null
      echo "queue: commit failed; $task is still IN PROGRESS" >&2; exit 4
    fi
    echo "queue: $task DONE" ;;
  block)
    task="${1:?queue block <task> <reason>}"; shift; why="${*:-no reason given}"
    need_state "$task" "IN PROGRESS"
    stash_work "$task blocked: $why" || exit 4
    set_state "$task" BLOCKED || exit 4
    echo "queue: $task BLOCKED ($why)" ;;
  recover)
    for t in $(rows | awk -F'\t' '$4 == "IN PROGRESS" { print $1 }'); do
      stash_work "$t interrupted" || exit 4
      set_state "$t" PENDING || exit 4
      echo "queue: $t back to PENDING"
    done ;;
  set)
    set_state "${1:?queue set <task> <state>}" "${*:2}" ;;
  state)
    s=$(state_of "${1:?queue state <task>}"); [ -n "$s" ] || { echo "queue: unknown task: $1" >&2; exit 3; }; echo "$s" ;;
  tests)
    rows | awk -F'\t' '($4 == "IN PROGRESS" || $4 == "DONE") && $3 != "" && $3 != "none" { print $3 }' ;;
  summary)
    rows | awk -F'\t' '{ n[$4]++ } END { printf "Progress: %d DONE, %d BLOCKED, %d PENDING\n", n["DONE"], n["BLOCKED"], n["PENDING"] + n["IN PROGRESS"] }' ;;
esac
