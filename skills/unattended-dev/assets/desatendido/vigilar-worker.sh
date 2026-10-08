#!/usr/bin/env bash
# unattended-dev v8.7: the protections around one worker, in two steps, for
# workers that start and finish on their own (for example Orca workers).
# lanzar-worker.sh uses the same two steps around the command it runs.
#
# Usage (from the project root):
#   vigilar-worker.sh begin <role> <task> [--readonly "tests/acceptance ..."]
#       Before the worker starts: take a snapshot of the tree and HEAD, and
#       make the --readonly paths read-only while the worker runs.
#   vigilar-worker.sh end <role> <task> [--allowed "src/a.ts docs/ ..."]
#       After the worker settles: restore write permission and list every
#       file it touched outside --allowed, committed or not.
#
# Exit of end: 0 nothing outside what is allowed; 3 OUT OF TASK; 2 wrong
# usage or no matching begin. It detects changes after the fact; it is not
# a sandbox.
set -u

cmd="${1:-}"; role="${2:-}"; task="${3:-}"
[ -n "$cmd" ] && [ -n "$role" ] && [ -n "$task" ] || { sed -n "2,18p" "$0"; exit 2; }
shift 3
allowed=""; readonly_paths=""
while [ $# -gt 0 ]; do
  case "$1" in
    --allowed) allowed="$2"; shift 2;;
    --readonly) readonly_paths="$2"; shift 2;;
    *) echo "vigilar: unknown option: $1" >&2; exit 2;;
  esac
done

state="logs/.vigilar-${task}-${role}"

# Modified files: path and a hash of their content, so a file that was
# already modified and changes again is noticed too.
snapshot() {
  git status --porcelain --untracked-files=all 2>/dev/null \
    | sed -E 's/^.{3}//; s/^"//; s/"$//; s/.* -> //' | grep -v '^logs/' \
    | while IFS= read -r f; do
        if [ -f "$f" ]; then echo "$f $(git hash-object -- "$f")"; else echo "$f deleted"; fi
      done | sort
}

case "$cmd" in
  begin)
    mkdir -p "$state"
    git rev-parse -q --verify HEAD > "$state/head" 2>/dev/null || echo none > "$state/head"
    snapshot > "$state/snapshot"
    printf '%s\n' $readonly_paths > "$state/readonly"
    for p in $readonly_paths; do [ -e "$p" ] && chmod -R a-w "$p"; done
    exit 0 ;;
  end)
    [ -d "$state" ] || { echo "vigilar: no begin for $role $task" >&2; exit 2; }
    while IFS= read -r p; do [ -n "$p" ] && [ -e "$p" ] && chmod -R u+w "$p"; done < "$state/readonly"
    head_before=$(cat "$state/head")
    head_after=$(git rev-parse -q --verify HEAD 2>/dev/null || echo none)
    after=$(snapshot)
    changed=$( (comm -13 "$state/snapshot" <(echo "$after"); comm -23 "$state/snapshot" <(echo "$after")) \
      | sed -E 's/ [^ ]+$//'
      # Files changed by commits the worker made, which git status no longer shows.
      if [ "$head_before" != "$head_after" ]; then
        if [ "$head_before" = none ]; then git ls-tree -r --name-only HEAD
        else git diff --name-only "$head_before" "$head_after"; fi
      fi )
    changed=$(echo "$changed" | grep -v '^logs/' | grep -v '^$' | sort -u)
    rm -rf "$state"
    outside=""
    for f in $changed; do
      ok=0
      for p in $allowed; do
        case "$f" in "$p"|"$p"/*|"${p%/}"/*) ok=1;; esac
      done
      [ "$ok" = 1 ] || outside="$outside $f"
    done
    if [ -n "$outside" ]; then echo "OUT OF TASK:$outside"; exit 3; fi
    exit 0 ;;
  *)
    sed -n "2,18p" "$0"; exit 2 ;;
esac
