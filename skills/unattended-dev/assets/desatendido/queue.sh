#!/usr/bin/env bash
# unattended-dev v8.7: deterministic queue state. The orchestrator and
# bucle.sh call this instead of deciding by reading the table themselves.
#
# Reads and writes the queue table in STATUS.md (or $STATUS_FILE):
#   | Task | Title | Depends on | Test | State |
#   | T01  | ...   | none       | tests/acceptance/T01.test.ts | PENDING |
# States: PENDING, IN PROGRESS, DONE, BLOCKED. "Depends on" is "none" or a
# comma-separated list of task ids.
#
# Every state change is committed at once, so a stash or a crash can never
# bring back an old state. Closing a task is one atomic command. Each step
# also writes its own line in the Log of STATUS.md, so the Log never depends
# on the orchestrator remembering it.
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
#   queue.sh fix <task> <reason>  Count one fix attempt (committed in the Log).
#                                 Exit 5 when the task has no fixes left: block it.
#                                 The limit is 2 ($QUEUE_MAX_FIXES), plus one per
#                                 decision recorded for the task.
#   queue.sh decide <task> <text> Record a default decision for a gap in the SPEC
#                                 in docs/DECISIONES.md ($DECISIONS_FILE) and the
#                                 Log, committed at once so it survives a block.
#                                 Exit 5 after 2 decisions for one task: block it.
#   queue.sh note <text>          Add a free line to the Log (committed), for what
#                                 the orchestrator must record outside a task step.
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
# Exit 5: no fixes or decisions left for the task.
set -u
STATUS="${STATUS_FILE:-STATUS.md}"
DECISIONS="${DECISIONS_FILE:-docs/DECISIONES.md}"
MAX_FIXES="${QUEUE_MAX_FIXES:-2}"
MAX_DECISIONS=2
case "${1:-}" in next|start|fix|decide|note|done|block|recover|set|state|tests|summary) ;; *) sed -n "2,46p" "$0"; exit 3;; esac
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

log_line() { # append one line to the Log at the end of STATUS.md (not committed)
  grep -q '^## Log' "$STATUS" || printf '\n## Log\n\n' >> "$STATUS"
  printf -- '- %s %s\n' "$(date '+%F %H:%M')" "$*" >> "$STATUS"
}

since_start() { # since_start <task> <word>: how many "<word>" lines since its last start
  awk -v t="$1" -v w="$2" '$1 == "-" && $4 == t { if ($5 == "started") n = 0; else if ($5 == w || $5 == w ":") n++ } END { print n + 0 }' "$STATUS"
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
            log_line "$t BLOCKED: depends on $d, which is BLOCKED"
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
    log_line "$task started"
    set_state "$task" "IN PROGRESS" || exit 4
    if [ -n "$test_file" ] && [ "$test_file" != none ]; then unskip "$test_file" || exit 3; echo "$test_file"; fi ;;
  fix)
    task="${1:?queue fix <task> <reason>}"; shift; why="${*:-no reason given}"
    need_state "$task" "IN PROGRESS"
    used=$(since_start "$task" fix); allowed=$(( MAX_FIXES + $(since_start "$task" decision) ))
    if [ "$used" -ge "$allowed" ]; then
      echo "queue: $task has used its $allowed fixes; block it with: queue.sh block $task \"<reason>\"" >&2; exit 5
    fi
    log_line "$task fix $((used + 1)): $why"
    commit_status "queue: $task fix $((used + 1))" || exit 4
    echo "queue: $task fix $((used + 1)) of $allowed" ;;
  decide)
    task="${1:?queue decide <task> <decision>}"; shift; text="${*:?queue decide <task> <decision>}"
    need_state "$task" "IN PROGRESS"
    if [ "$(since_start "$task" decision)" -ge "$MAX_DECISIONS" ]; then
      echo "queue: $task already has $MAX_DECISIONS decisions; block it and leave it for the user" >&2; exit 5
    fi
    mkdir -p "$(dirname "$DECISIONS")"
    [ -f "$DECISIONS" ] || printf '# Default decisions\n\nTaken during the unattended queue for gaps in the SPEC. Review them and undo the ones you do not want.\n\n' > "$DECISIONS"
    printf -- '- %s %s: %s\n' "$(date '+%F %H:%M')" "$task" "$text" >> "$DECISIONS"
    log_line "$task decision: $text"
    if ! { git add -- "$STATUS" "$DECISIONS" && git commit -q -m "queue: $task decision" -- "$STATUS" "$DECISIONS"; }; then
      echo "queue: could not commit the decision" >&2; exit 4
    fi
    echo "queue: decision for $task recorded in $DECISIONS (one more fix allowed)" ;;
  note)
    text="${*:?queue note <text>}"
    log_line "note: $text"
    commit_status "queue: note" || exit 4
    echo "queue: noted in the Log" ;;
  done)
    task="${1:?queue done <task> <message>}"; shift; msg="${*:-done}"
    need_state "$task" "IN PROGRESS"
    backup=$(mktemp); cp "$STATUS" "$backup"
    write_state "$task" DONE || { rm -f "$backup"; exit 3; }
    log_line "$task DONE: $msg"
    if ! { git add -A && git commit -q -m "$task: $msg"; }; then
      cat "$backup" > "$STATUS"; rm -f "$backup"; git reset -q -- "$STATUS" 2>/dev/null
      echo "queue: commit failed; $task is still IN PROGRESS" >&2; exit 4
    fi
    rm -f "$backup"
    echo "queue: $task DONE" ;;
  block)
    task="${1:?queue block <task> <reason>}"; shift; why="${*:-no reason given}"
    need_state "$task" "IN PROGRESS"
    stash_work "$task blocked: $why" || exit 4
    log_line "$task BLOCKED: $why"
    set_state "$task" BLOCKED || exit 4
    echo "queue: $task BLOCKED ($why)" ;;
  recover)
    for t in $(rows | awk -F'\t' '$4 == "IN PROGRESS" { print $1 }'); do
      stash_work "$t interrupted" || exit 4
      log_line "$t interrupted: back to PENDING, its work is in stash \"$t interrupted\""
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
