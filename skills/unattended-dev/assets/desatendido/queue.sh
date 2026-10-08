#!/usr/bin/env bash
# unattended-dev v8.9: deterministic queue state. The orchestrator and
# bucle.sh call this instead of deciding by reading the table themselves.
#
# Reads and writes the queue table in STATUS.md (or $STATUS_FILE):
#   | Task | Title | Depends on | Test | State |
#   | T01  | ...   | none       | tests/acceptance/T01.test.ts | PENDING |
# States: PENDING, IN PROGRESS, DONE, BLOCKED. "Depends on" is "none" or a
# comma-separated list of task ids.
#
# Every state change is committed at once, so a crash can never bring back
# an old state. Each step also writes its own line in the Log, docs/LOG.md
# (or $LOG_FILE; a Log at the end of STATUS.md, from before v8.9, is moved
# there). A task is measured against the commit it started from (its
# "started at" line in the Log), never against the tree of the moment. After
# each of its commits, queue.sh points refs/worktree/queue-state at it (one
# per worktree): while a task is IN PROGRESS, STATUS.md, the Log and
# docs/DECISIONES.md must be exactly as there, and any other change to them
# is out of task.
#
# Git hooks: only done's commit runs the project's hooks (a hook that fails
# stops it with exit 4). Every other commit, and every reference queue.sh
# moves, runs none (not even prepare-commit-msg or reference-transaction,
# which --no-verify leaves): they only carry the queue files, or they put the
# tree back (block, recover, restore-outside), which a failing hook must
# never leave stuck.
#
# Phase zero leaves, next to this script (all committed before the queue):
#   allowed/<task>  Files the task may touch, one per line (a folder ends in /).
#                   Its test, STATUS.md, the Log and docs/DECISIONES.md are always
#                   allowed, but only queue.sh may change the last three.
#   qa/<task>       The QA types the task needs: "combined" for low risk (one
#                   review, or fidelity and technical apart), "fidelity technical"
#                   for high risk (each its own review, a combined one does not
#                   count), plus "design" if it touches the UI. Without the file:
#                   fidelity and technical, and a combined review counts for both.
#   gate.sh         The gate, executable: the guard, then typecheck, tests, build.
#
# Usage (from the project root):
#   queue.sh next                 Print the next PENDING task whose dependencies
#                                 are all DONE (BLOCKED spreads to the tasks that
#                                 depend on it). Exit 0 found, 1 queue finished,
#                                 2 tasks left but none can start.
#   queue.sh start <task>         IN PROGRESS (committed) and remove the skip from
#                                 its test (not committed: it is part of the task).
#                                 Refuses if a dependency is not DONE, another task
#                                 is IN PROGRESS, the task has no allowed list or
#                                 the working tree has other changes.
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
#   queue.sh qa <task> <type> PASS|FAIL <summary>
#                                 Record a QA verdict (fidelity, technical, design
#                                 or combined) for the code exactly as it is now.
#   queue.sh outside <task>       Files changed since the task started (committed
#                                 or not) that it may not touch. Exit 6 if any.
#   queue.sh restore-outside <task>
#                                 Copy everything to a backup branch, put the files
#                                 of "outside" back as they were at the start and
#                                 commit that. The task's own work stays.
#   queue.sh done <task> <msg>    Checks, in order: nothing outside the task (6),
#                                 the gate passes and changes no file (7), a QA
#                                 PASS of each type for the code as it is now (8).
#                                 Then DONE and commit everything as "<task>: <msg>".
#                                 If it refuses, the task stays IN PROGRESS and the
#                                 tree is as it was (what the gate changed is put back).
#   queue.sh block <task> <why>   Copy the task's work to a backup branch, put every
#                                 file it touched back as it was at its start, then
#                                 BLOCKED, all in one commit.
#   queue.sh recover              Give write permission back to what an unfinished
#                                 vigilar-worker.sh begin left read-only, and put
#                                 the queue files back as queue.sh left them. Then every
#                                 IN PROGRESS task was cut off: the same as block,
#                                 but back to PENDING.
#   queue.sh set <task> <state>   Low level, for people: PENDING or BLOCKED only
#                                 (DONE goes through done, IN PROGRESS through start).
#   queue.sh state <task>         Print the state of one task.
#   queue.sh tests                Tests of IN PROGRESS and DONE tasks (for
#                                 guardia-tests.sh: they must have no skip).
#   queue.sh summary              "Progress: X DONE, Y BLOCKED, Z PENDING".
#
# Backup branches are named queue/backup/<task>-<date>: git branch --list 'queue/backup/*'
#
# Exit 3: wrong usage or state. Exit 4: a git step failed; nothing was marked.
# Exit 5: no fixes or decisions left. Exit 6: files outside the task (also
# fix, decide, note, qa and set when a queue file has changes queue.sh did not make).
# Exit 7: the gate failed. Exit 8: QA missing, failed, or for other code.
set -u
STATUS="${STATUS_FILE:-STATUS.md}"
LOG="${LOG_FILE:-docs/LOG.md}"
DECISIONS="${DECISIONS_FILE:-docs/DECISIONES.md}"
MAX_FIXES="${QUEUE_MAX_FIXES:-2}"
MAX_DECISIONS=2
HERE="$(dirname "$0")"
case "${1:-}" in next|start|fix|decide|note|qa|outside|restore-outside|done|block|recover|set|state|tests|summary) ;; *) sed -n "2,94p" "$0"; exit 3;; esac
git rev-parse -q --verify HEAD >/dev/null 2>&1 || { echo "queue: needs a git repo with at least one commit" >&2; exit 3; }
CONF="$(cd "$HERE" && git rev-parse --show-prefix)" # this folder, from the repo root (for git show)
TRUST="refs/worktree/queue-state" # per worktree: another worktree's queue never moves it

# Rows of the queue table as "id<TAB>deps<TAB>test<TAB>state" (of $STATUS, or of the file given).
rows() {
  awk -F'|' '
    NF >= 7 && $2 ~ /^[[:space:]]*[A-Za-z]*[0-9]+[[:space:]]*$/ {
      for (i = 2; i <= 6; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i) }
      print $2 "\t" $4 "\t" $5 "\t" $6
    }' "${1:-$STATUS}"
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

log_init() { [ -f "$LOG" ] || { mkdir -p "$(dirname "$LOG")" && printf '# Log\n\nWritten by `queue.sh`: starts, fixes, decisions, QA, DONE, BLOCKED and interruptions, one line each.\n\n' > "$LOG"; }; }
log_line() { # append one line to the Log (not committed); fails if it cannot
  log_init || return 1
  printf -- '- %s %s\n' "$(date '+%F %H:%M')" "$*" >> "$LOG"
}

# log_awk <awk args>: awk over the Log as queue.sh last committed it (empty if there is none),
# so a worker that overwrites it cannot hide where a task started or what its QA said.
log_awk() { git show "$(trusted_commit):./$LOG" 2>/dev/null | awk "$@"; }

since_start() { # since_start <task> <word>: how many "<word>" lines since its last start
  log_awk -v t="$1" -v w="$2" '$1 == "-" && $4 == t { if ($5 == "started") n = 0; else if ($5 == w || $5 == w ":") n++ } END { print n + 0 }'
}

start_of() { # the commit the task started from ("<task> started at <sha>"), empty if none or set by hand since
  log_awk -v t="$1" '$1 == "-" && $4 == t { if ($5 == "started") s = ($6 == "at") ? $7 : ""; else if ($5 == "set") s = "" } END { print s }'
}

need_start() { # the start commit of an IN PROGRESS task, or stop
  local s; s=$(start_of "$1")
  if [ -z "$s" ] || ! git cat-file -e "$s^{commit}" 2>/dev/null; then
    echo "queue: $1 has no start commit in the Log; start it with queue.sh start" >&2; exit 3
  fi
  echo "$s"
}

git_nohooks() { git -c core.hooksPath=/dev/null "$@"; } # its own commits and references run no project hook
trust_head() { git_nohooks update-ref "$TRUST" HEAD; } # after every commit queue.sh makes
commit_nohooks() { git_nohooks commit -q --no-verify "$@"; } # every commit but done's

trusted_commit() { # the last commit queue.sh made in this worktree (HEAD before its first one)
  git rev-parse -q --verify "$TRUST^{commit}" 2>/dev/null || git rev-parse HEAD
}

in_task() { # is a task IN PROGRESS, as queue.sh left STATUS.md?
  git show "$(trusted_commit):./$STATUS" 2>/dev/null | rows - | awk -F'\t' '$4 == "IN PROGRESS"' | grep -q .
}

commit_queue() { # commit STATUS.md and the Log alone, if they changed
  local p=("$STATUS")
  { [ -e "$LOG" ] || git cat-file -e "HEAD:$LOG" 2>/dev/null; } && p+=("$LOG")
  [ -z "$(git status --porcelain -- "${p[@]}")" ] && return 0
  git add -A -- "${p[@]}" && commit_nohooks -m "$1" -- "${p[@]}" && trust_head \
    || { echo "queue: could not commit $STATUS and $LOG" >&2; return 4; }
}

save_queue() { SAVED=$(mktemp -d); cp -p "$STATUS" "$SAVED/status"; [ ! -f "$LOG" ] || cp -p "$LOG" "$SAVED/log"; }
undo_queue() { # put STATUS.md and the Log back as save_queue found them, unstaged
  cat "$SAVED/status" > "$STATUS"
  if [ -f "$SAVED/log" ]; then cat "$SAVED/log" > "$LOG"; else rm -f "$LOG"; fi
  rm -rf "$SAVED"; git reset -q -- "$STATUS" "$LOG" 2>/dev/null; return 0
}

record() { # record <commit message> <Log line> [<task> <state>]: committed together; on failure nothing changes
  save_queue
  log_line "$2" || { echo "queue: could not write the Log ($LOG)" >&2; undo_queue; return 4; }
  if [ $# -ge 4 ]; then write_state "$3" "$4" || { undo_queue; return 3; }; fi
  commit_queue "$1" || { undo_queue; return 4; }
  rm -rf "$SAVED"
}

migrate_log() { # a Log at the end of STATUS.md (before v8.9) moves to $LOG, committed
  grep -q '^## Log' "$STATUS" || return 0
  in_task && { queue_file_tampered "$STATUS" || queue_file_tampered "$LOG"; } && return 0 # restore-outside or recover first
  local tmp; tmp=$(mktemp); save_queue; log_init
  awk '/^## Log/ { on = 1; next } on && /^## / { on = 0 } on && /^- / { print }' "$STATUS" >> "$LOG"
  log_line "note: Log moved here from $STATUS" || { rm -f "$tmp"; undo_queue; return 4; }
  awk '/^## Log/ { on = 1; next } on && /^## / { on = 0 } on { next }
       /^[[:space:]]*$/ { blank = blank $0 "\n"; next } { printf "%s", blank; blank = ""; print }' "$STATUS" > "$tmp" \
    && cat "$tmp" > "$STATUS"
  rm -f "$tmp"
  commit_queue "queue: Log moved to $LOG" || { undo_queue; return 4; }
  rm -rf "$SAVED"
}

# Run git on a throwaway copy of the index, so the real one is never touched.
# cp -p keeps the time of the index, so git still re-reads files changed in the same second.
tmp_index_init() { TMP_INDEX="$(mktemp -d)/index"; cp -p "$(git rev-parse --git-path index)" "$TMP_INDEX" 2>/dev/null || GIT_INDEX_FILE="$TMP_INDEX" git read-tree HEAD; }
tmp_git() { GIT_INDEX_FILE="$TMP_INDEX" git "$@"; }
tmp_index_done() { rm -rf "$(dirname "$TMP_INDEX")"; }

code_hash() { # the working tree as it is now, untracked files included and STATUS.md and the Log left out
  local tree
  tmp_index_init
  tmp_git add -A && tmp_git update-index --force-remove -- "$STATUS" "$LOG" && tree=$(tmp_git write-tree)
  tmp_index_done
  [ -n "${tree:-}" ] || { echo "queue: could not hash the working tree" >&2; return 4; }
  echo "$tree"
}

backup_work() { # backup_work <task> <why>: the whole tree, uncommitted and untracked included, in a new branch
  local tree commit name
  tmp_index_init
  tmp_git add -A && tree=$(tmp_git write-tree) && commit=$(git commit-tree "$tree" -p HEAD -m "queue: backup of $1 ($2)")
  tmp_index_done
  [ -n "${commit:-}" ] || { echo "queue: could not save the work of $1 in a backup branch" >&2; return 4; }
  local base n=2; base="queue/backup/$1-$(date +%Y%m%d-%H%M%S)"; name="$base"
  while git rev-parse -q --verify "refs/heads/$name" >/dev/null; do name="$base-$n"; n=$((n + 1)); done
  git_nohooks update-ref "refs/heads/$name" "$commit" || { echo "queue: could not create branch $name" >&2; return 4; }
  echo "$name"
}

touched() { # touched <sha>: every file changed since <sha>, committed or not, untracked included
  { git diff --name-only --no-renames -z "$1"
    git diff --cached --name-only --no-renames -z "$1"
    git diff --name-only --no-renames -z "$1" HEAD
    git ls-files --others --exclude-standard -z
  } | tr '\0' '\n' | grep -v '^$' | sort -u
}

is_queue_file() { [ "$1" = "$STATUS" ] || [ "$1" = "$LOG" ] || [ "$1" = "$DECISIONS" ]; }

queue_file_tampered() { # queue_file_tampered <file>: not exactly as queue.sh left it?
  local want have=""
  want=$(git rev-parse -q --verify "$(trusted_commit):$1" 2>/dev/null)
  [ -f "$1" ] && have=$(git hash-object -- "$1")
  [ "$want" != "$have" ]
}

need_trusted_queue_files() { # during a task, refuse to commit changes queue.sh did not make
  local f bad=""
  in_task || return 0
  for f in "$STATUS" "$LOG" "$DECISIONS"; do queue_file_tampered "$f" && bad="$bad $f"; done
  [ -z "$bad" ] && return 0
  echo "queue: changes that queue.sh did not make in:$bad; nothing was done." >&2
  echo "queue: put them back with: queue.sh restore-outside <task> (or queue.sh recover)" >&2
  exit 6
}

trusted_version() { # trusted_version <file> <start>: the commit a file goes back to
  if is_queue_file "$1"; then trusted_commit; else echo "$2"; fi
}

outside_of() { # outside_of <task> <start>: changed files the task may not touch
  local task="$1" start="$2" allowed test f p ok
  allowed=$(git show "$start:${CONF}allowed/$task" 2>/dev/null | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')
  test=$(git show "$start:./$STATUS" 2>/dev/null | rows - | awk -F'\t' -v t="$task" '$1 == t { print $3 }')
  touched "$start" | while IFS= read -r f; do
    case "$f" in logs/*) continue;; esac
    if is_queue_file "$f"; then queue_file_tampered "$f" && echo "$f"; continue; fi
    [ -n "$test" ] && [ "$f" = "$test" ] && continue
    ok=0
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      case "$f" in "$p"|"${p%/}"/*) ok=1; break;; esac
    done <<EOF
$allowed
EOF
    [ "$ok" = 1 ] || echo "$f"
  done
}

restore_files() { # restore_files <start> < files: each back to its trusted version (removed if it did not exist)
  local start="$1" f v gone=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    v=$(trusted_version "$f" "$start")
    if git cat-file -e "$v:$f" 2>/dev/null; then
      git checkout -q "$v" -- "$f" || return 4
    else
      git rm -q -r -f --cached --ignore-unmatch -- "$f" >/dev/null || return 4
      gone="$gone$f
"
    fi
  done
  # Files only removed once every git step worked, so a failure loses nothing.
  printf '%s' "$gone" | while IFS= read -r f; do [ -n "$f" ] && rm -f -- "$f"; done
  return 0
}

put_back() { # put_back <task> <state> <log text>: backup branch, files back to the start, new state, one commit
  local task="$1" new="$2" text="$3" start files branch=""
  start=$(start_of "$task")
  if [ -z "$start" ] || ! git cat-file -e "$start^{commit}" 2>/dev/null; then
    start=$(git rev-parse HEAD) # started before v8.8 or by hand: only uncommitted work is undone
  fi
  files=$(touched "$start")
  if [ -n "$(echo "$files" | grep -vxF -e "$STATUS" -e "$LOG" -e "$DECISIONS")" ]; then
    branch=$(backup_work "$task" "$new") || return 4
    text="$text; its work is in branch $branch"
  fi
  [ -n "${FOUND_BACKUP:-}" ] && text="$text; the queue files as they were found are in branch $FOUND_BACKUP"
  echo "$files" | restore_files "$start" \
    || { echo "queue: could not put back the files of $task${branch:+ (its work is in branch $branch)}; nothing was marked" >&2; return 4; }
  save_queue
  log_line "$task $text" || { echo "queue: could not write the Log ($LOG); nothing was marked" >&2; undo_queue; return 4; }
  write_state "$task" "$new" || { undo_queue; return 3; }
  if ! { git add -A && commit_nohooks -m "queue: $task $new" && trust_head; }; then
    undo_queue
    echo "queue: commit failed; $task is still IN PROGRESS${branch:+ and its work is in branch $branch}" >&2; return 4
  fi
  rm -rf "$SAVED"
  [ -n "$branch" ] && echo "queue: the work of $task is saved in branch $branch"
  return 0
}

qa_last() { # qa_last <task> <type> <own> <tree>: why <type> has no PASS for <tree> (nothing if it has)
  # The last verdict decides; a combined one is a verdict on fidelity and technical too, but
  # with <own> = 1 (high risk) its PASS does not count: they need their own review.
  log_awk -v t="$1" -v ty="$2" -v own="$3" -v tree="$4" '
    $1 == "-" && $4 == t && $5 == "started" { r = ""; h = ""; k = "" }
    $1 == "-" && $4 == t && $5 == "qa" && ($6 == ty || ($6 == "combined" && (ty == "fidelity" || ty == "technical"))) { r = $7; h = $9; k = $6; sub(/:$/, "", h) }
    END {
      if (r == "") print ty ": no QA recorded since the start"
      else if (r != "PASS") print ty ": the last QA is " r
      else if (own == 1 && k != ty) print ty ": needs its own review (high risk); a combined one does not count"
      else if (h != tree) print ty ": the PASS was for other code (it changed after the QA)"
    }'
}

qa_missing() { # qa_missing <task> <start> <tree>: every required QA type without a PASS for <tree>
  local task="$1" start="$2" tree="$3" types ty own=1 m
  types=$(git show "$start:${CONF}qa/$task" 2>/dev/null | sed 's/#.*//' | tr ',' ' ')
  [ -n "$(echo $types)" ] || { types="fidelity technical"; own=0; }
  for ty in $types; do
    if [ "$ty" = combined ]; then # one combined review, or fidelity and technical apart
      m=$(qa_last "$task" fidelity 0 "$tree"; qa_last "$task" technical 0 "$tree")
      case "$m" in *"no QA recorded"*"no QA recorded"*) echo "combined: no QA recorded since the start";; ?*) echo "$m";; esac
    else
      qa_last "$task" "$ty" "$own" "$tree"
    fi
  done
}

restore_tree() { # restore_tree <tree> <now>: files that differ put back as in <tree>; the real index is untouched
  local f
  tmp_index_init
  tmp_git read-tree "$1" || { tmp_index_done; return 4; }
  git diff --name-only --no-renames -z "$1" "$2" | tr '\0' '\n' | while IFS= read -r f; do
    [ -n "$f" ] || continue
    if git cat-file -e "$1:$f" 2>/dev/null; then tmp_git checkout-index -f -- "$f" || exit 4
    else rm -f -- "$f"; fi
  done
  local status=$?
  tmp_index_done
  return "$status"
}

restore_readonly() { # undo what a vigilar-worker.sh begin without its end left read-only
  local d p
  for d in logs/.vigilar-*; do
    [ -d "$d" ] || continue
    if [ -f "$d/readonly" ]; then
      while IFS= read -r p; do
        [ -n "$p" ] && [ -e "$p" ] && chmod -R u+w "$p" && echo "queue: write permission given back to $p"
      done < "$d/readonly"
    fi
    rm -rf "$d"
  done
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
if [ "$cmd" = recover ]; then
  restore_readonly
  if in_task; then # a worker may have emptied, deleted or rewritten the table
    bad="" # one path per line: they may have spaces
    for f in "$STATUS" "$LOG" "$DECISIONS"; do queue_file_tampered "$f" && bad="$bad$f
"; done
    if [ -n "$bad" ]; then # save everything as found before putting anything back
      t=$(git show "$(trusted_commit):./$STATUS" | rows - | awk -F'\t' '$4 == "IN PROGRESS" { print $1; exit }')
      FOUND_BACKUP=$(backup_work "$t" "as found by recover") || exit 4
      echo "queue: everything as it was found, the queue files included, is in branch $FOUND_BACKUP"
    fi
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      c=$(trusted_commit)
      if git cat-file -e "$c:$f" 2>/dev/null; then git checkout -q "$c" -- "$f"
      else git rm -q -f --cached --ignore-unmatch -- "$f" >/dev/null && rm -f -- "$f"; fi \
        || { echo "queue: could not put back $f; nothing was marked" >&2; exit 4; }
      echo "queue: $f put back as queue.sh left it"
    done <<EOF
$bad
EOF
  fi
fi
[ -f "$STATUS" ] || { echo "queue: $STATUS not found" >&2; exit 3; }
case "$cmd" in
  start|fix|decide|note|qa|next) need_trusted_queue_files ;;
esac
case "$cmd" in state|tests|summary) ;; *) migrate_log || exit 4;; esac
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
            record "queue: $t BLOCKED" "$t BLOCKED: depends on $d, which is BLOCKED" "$t" BLOCKED || exit 4
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
    task="${1:?queue start <task>}"; need_state "$task" PENDING
    for d in $(rows | awk -F'\t' -v t="$task" '$1 == t { print $2 }' | tr ',' ' '); do
      [ "$d" = none ] && continue
      s=$(state_of "$d")
      [ "$s" = DONE ] || { echo "queue: $task depends on $d, which is ${s:-not in the queue}, not DONE" >&2; exit 3; }
    done
    busy=$(rows | awk -F'\t' '$4 == "IN PROGRESS" { print $1 }' | head -n 1)
    [ -z "$busy" ] || { echo "queue: $busy is IN PROGRESS; one task at a time (close it, or queue.sh recover if it was cut off)" >&2; exit 3; }
    git cat-file -e "HEAD:${CONF}allowed/$task" 2>/dev/null \
      || { echo "queue: $task has no allowed list: commit ${CONF}allowed/$task (the files it may touch, one per line) first" >&2; exit 3; }
    need_clean_tree "$task"
    test_file=$(rows | awk -F'\t' -v t="$task" '$1 == t { print $3 }')
    record "queue: $task IN PROGRESS" "$task started at $(git rev-parse HEAD)" "$task" "IN PROGRESS" || exit 4
    if [ -n "$test_file" ] && [ "$test_file" != none ]; then unskip "$test_file" || exit 3; echo "$test_file"; fi ;;
  fix)
    task="${1:?queue fix <task> <reason>}"; shift; why="${*:-no reason given}"
    need_state "$task" "IN PROGRESS"
    used=$(since_start "$task" fix); allowed=$(( MAX_FIXES + $(since_start "$task" decision) ))
    if [ "$used" -ge "$allowed" ]; then
      echo "queue: $task has used its $allowed fixes; block it with: queue.sh block $task \"<reason>\"" >&2; exit 5
    fi
    record "queue: $task fix $((used + 1))" "$task fix $((used + 1)): $why" || exit 4
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
    log_line "$task decision: $text" || { echo "queue: could not write the Log ($LOG)" >&2; exit 4; }
    if ! { git add -- "$LOG" "$DECISIONS" && commit_nohooks -m "queue: $task decision" -- "$LOG" "$DECISIONS" && trust_head; }; then
      echo "queue: could not commit the decision" >&2; exit 4
    fi
    echo "queue: decision for $task recorded in $DECISIONS (one more fix allowed)" ;;
  note)
    text="${*:?queue note <text>}"
    record "queue: note" "note: $text" || exit 4
    echo "queue: noted in the Log" ;;
  qa)
    task="${1:-}"; type="${2:-}"; result="${3:-}"
    case "$type" in fidelity|technical|design|combined) ;; *) echo "queue: qa <task> fidelity|technical|design|combined PASS|FAIL <summary>" >&2; exit 3;; esac
    case "$result" in PASS|FAIL) ;; *) echo "queue: qa <task> <type> PASS|FAIL <summary>" >&2; exit 3;; esac
    shift 3; summary="${*:-no summary}"
    need_state "$task" "IN PROGRESS"
    tree=$(code_hash) || exit 4
    record "queue: $task qa $type $result" "$task qa $type $result on $tree: $summary" || exit 4
    echo "queue: $task $type QA $result recorded for the code as it is now" ;;
  outside)
    task="${1:?queue outside <task>}"; need_state "$task" "IN PROGRESS"; start=$(need_start "$task") || exit 3
    out=$(outside_of "$task" "$start")
    [ -z "$out" ] && exit 0
    echo "$out"; exit 6 ;;
  restore-outside)
    task="${1:?queue restore-outside <task>}"; need_state "$task" "IN PROGRESS"; start=$(need_start "$task") || exit 3
    out=$(outside_of "$task" "$start")
    [ -n "$out" ] || { echo "queue: nothing outside $task"; exit 0; }
    branch=$(backup_work "$task" "outside its task") || exit 4
    echo "$out" | restore_files "$start" || { echo "queue: could not put the files back (everything is in branch $branch)" >&2; exit 4; }
    log_line "$task put back outside its task: $(echo $out); copy in branch $branch" \
      || { echo "queue: could not write the Log (everything is in branch $branch)" >&2; exit 4; }
    git add -- "$STATUS" "$LOG" || exit 4
    paths=("$STATUS" "$LOG")
    while IFS= read -r f; do # only paths git knows; a new file that was removed is already gone
      if git cat-file -e "HEAD:$f" 2>/dev/null || git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then paths+=("$f"); fi
    done <<EOF
$out
EOF
    { commit_nohooks -m "queue: $task put back outside its task" -- "${paths[@]}" && trust_head; } \
      || { echo "queue: could not commit the files put back (everything is in branch $branch)" >&2; exit 4; }
    echo "queue: put back as at the start of $task:"; echo "$out" | sed 's/^/  /'
    echo "queue: copy of everything in branch $branch" ;;
  done)
    task="${1:?queue done <task> <message>}"; shift; msg="${*:-done}"
    need_state "$task" "IN PROGRESS"; start=$(need_start "$task") || exit 3
    out=$(outside_of "$task" "$start")
    if [ -n "$out" ]; then
      echo "queue: $task changed files outside its task; nothing was marked:" >&2; echo "$out" | sed 's/^/  /' >&2
      echo "queue: put them back with: queue.sh restore-outside $task" >&2; exit 6
    fi
    [ -x "$HERE/gate.sh" ] || { echo "queue: no gate: phase zero leaves it, executable, in ${CONF}gate.sh; nothing was marked" >&2; exit 3; }
    tree=$(code_hash) || exit 4 # the code the QA must have seen, and how the gate must leave it
    # What code_hash leaves out is kept too: STATUS.md, the Log, what is staged and HEAD.
    keep=$(mktemp -d); trap 'rm -rf "$keep"' EXIT
    index_file=$(git rev-parse --git-path index)
    cp -p "$STATUS" "$keep/status"; cp -p "$LOG" "$keep/log"; cp -p "$index_file" "$keep/index" 2>/dev/null
    git ls-files -s > "$keep/staged"; head_before=$(git rev-parse HEAD)
    branch_before=$(git symbolic-ref -q HEAD || echo "a detached HEAD")
    mkdir -p logs; gate_log="logs/$task-gate.log"
    "$HERE/gate.sh" > "$gate_log" 2>&1 < /dev/null; gate=$?
    branch_now=$(git symbolic-ref -q HEAD || echo "a detached HEAD")
    if [ "$branch_now" != "$branch_before" ]; then # never move a reference that is not the queue's
      echo "queue: the gate switched branch, from $branch_before to $branch_now; nothing was touched and no" >&2
      echo "queue: reference was moved. Go back to ${branch_before#refs/heads/} by hand and fix the gate." >&2
      exit 4
    fi
    changed=""
    if [ "$(git rev-parse HEAD)" != "$head_before" ]; then
      git update-ref HEAD "$head_before" || { echo "queue: the gate made a commit and HEAD could not be put back" >&2; exit 4; }
      changed="HEAD (the gate made a commit)"
    fi
    if ! git ls-files -s | cmp -s - "$keep/staged"; then # what is staged, not just the stat data git refreshes
      cp -p "$keep/index" "$index_file" || { echo "queue: the gate changed what is staged and it could not be put back" >&2; exit 4; }
      changed="$changed
what is staged (the index)"
    fi
    now=$(code_hash) || exit 4
    if [ "$now" != "$tree" ]; then
      changed="$changed
$(git diff --name-only --no-renames "$tree" "$now")"
      restore_tree "$tree" "$now" && [ "$(code_hash)" = "$tree" ] \
        || { echo "queue: the gate changed files and they could not be put back:" >&2; echo "$changed" | sed '/^$/d; s/^/  /' >&2; exit 4; }
    fi
    for f in status log; do
      if [ "$f" = status ]; then q="$STATUS"; else q="$LOG"; fi
      cmp -s "$keep/$f" "$q" && continue
      cp -p "$keep/$f" "$q" || { echo "queue: the gate changed $q and it could not be put back" >&2; exit 4; }
      changed="$changed
$q"
    done
    if [ -n "$changed" ]; then
      [ "$gate" != 0 ] && { echo "queue: the gate failed (exit $gate). Last 20 lines ($gate_log):" >&2; tail -n 20 "$gate_log" >&2; }
      echo "queue: the gate changed files; they are put back as they were and nothing was marked:" >&2
      echo "$changed" | sed '/^$/d; s/^/  /' >&2
      echo "queue: a gate must not change files that are not in .gitignore (build output, coverage, --fix) nor commit" >&2
      exit 7
    fi
    if [ "$gate" != 0 ]; then
      echo "queue: the gate failed (exit $gate); nothing was marked. Last 20 lines ($gate_log):" >&2
      tail -n 20 "$gate_log" >&2; exit 7
    fi
    out=$(outside_of "$task" "$start")
    if [ -n "$out" ]; then
      echo "queue: the gate left files outside $task (ignore them in .gitignore); nothing was marked:" >&2; echo "$out" | sed 's/^/  /' >&2; exit 6
    fi
    missing=$(qa_missing "$task" "$start" "$tree")
    if [ -n "$missing" ]; then
      echo "queue: $task has no QA PASS for the code as it is now; nothing was marked:" >&2; echo "$missing" | sed 's/^/  /' >&2
      echo "queue: run that QA again and record it with: queue.sh qa $task <type> PASS|FAIL \"<summary>\"" >&2; exit 8
    fi
    save_queue
    write_state "$task" DONE || { undo_queue; exit 3; }
    log_line "$task DONE: $msg" || { undo_queue; echo "queue: could not write the Log ($LOG); $task is still IN PROGRESS" >&2; exit 4; }
    if ! { git add -A && git commit -q -m "$task: $msg" && trust_head; }; then # the only commit that runs the hooks
      undo_queue; echo "queue: commit failed; $task is still IN PROGRESS" >&2; exit 4
    fi
    rm -rf "$SAVED"
    echo "queue: $task DONE" ;;
  block)
    task="${1:?queue block <task> <reason>}"; shift; why="${*:-no reason given}"
    need_state "$task" "IN PROGRESS"
    put_back "$task" BLOCKED "BLOCKED: $why" || exit $?
    echo "queue: $task BLOCKED ($why)" ;;
  recover)
    restore_readonly
    for t in $(rows | awk -F'\t' '$4 == "IN PROGRESS" { print $1 }'); do
      put_back "$t" PENDING "interrupted: back to PENDING" || exit $?
      echo "queue: $t interrupted, back to PENDING"
    done ;;
  set)
    task="${1:?queue set <task> <state>}"; new="${*:2}"
    case "$new" in
      PENDING|BLOCKED) ;;
      DONE) echo "queue: set cannot mark DONE: a task is closed with queue.sh done, which checks it" >&2; exit 3;;
      "IN PROGRESS") echo "queue: set cannot mark IN PROGRESS: a task is opened with queue.sh start" >&2; exit 3;;
      *) echo "queue: invalid state: $new" >&2; exit 3;;
    esac
    s=$(state_of "$task")
    [ -n "$s" ] || { echo "queue: unknown task: $task" >&2; exit 3; }
    [ "$s" != "IN PROGRESS" ] || { echo "queue: $task is IN PROGRESS: use queue.sh block or queue.sh recover" >&2; exit 3; }
    need_trusted_queue_files
    record "queue: $task $new" "$task set to $new by hand" "$task" "$new" || exit $? ;;
  state)
    s=$(state_of "${1:?queue state <task>}"); [ -n "$s" ] || { echo "queue: unknown task: $1" >&2; exit 3; }; echo "$s" ;;
  tests)
    rows | awk -F'\t' '($4 == "IN PROGRESS" || $4 == "DONE") && $3 != "" && $3 != "none" { print $3 }' ;;
  summary)
    rows | awk -F'\t' '{ n[$4]++ } END { printf "Progress: %d DONE, %d BLOCKED, %d PENDING\n", n["DONE"], n["BLOCKED"], n["PENDING"] + n["IN PROGRESS"] }' ;;
esac
