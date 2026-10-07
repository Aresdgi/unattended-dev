#!/usr/bin/env bash
# unattended-dev v8.1: fails if the acceptance tests have changed in anything
# other than removing the skip since the start tag. It goes inside the gate.
#
# Usage: .desatendido/guardia-tests.sh <tag> <tests-folder> [tests-without-skip...]
# Example: .desatendido/guardia-tests.sh fase-cero tests/acceptance tests/acceptance/T01.test.ts
#
# The tests-without-skip are those of the current task and of the DONE tasks:
# they cannot have any skip mark, or the task has not really been done.
#
# "Removing the skip" means: .skip( -> (, xit/xdescribe/xtest -> it/describe/test,
# and deleting lines with @pytest.mark.skip, t.Skip() or this.skip().
# If your stack uses another mark, add it in SKIP_EXTRA as a sed -E expression.
set -u
tag="${1:?missing the tag}"; folder="${2:?missing the tests folder}"; shift 2
git rev-parse -q --verify "refs/tags/$tag" >/dev/null || { echo "GUARD: tag $tag does not exist"; exit 1; }

normalize() {
  # First delete the lines that are only a skip mark; then remove the marks
  # inside a line. The order matters.
  sed -E \
    -e '/^[[:space:]]*@pytest\.mark\.skip/d' \
    -e '/^[[:space:]]*(t\.Skip|this\.skip)\(/d' \
    -e 's/\.skip(\(|\b)/\1/g' \
    -e 's/(^|[^A-Za-z0-9_])x(it|describe|test)\(/\1\2(/g' \
    ${SKIP_EXTRA:+-e "$SKIP_EXTRA"}
}

# Lines with a skip mark. Removing skips is allowed; adding a new one is not
# (it would be the trick of skipping a failing test).
skips() {
  grep -E '\.skip(\(|\b)|(^|[^A-Za-z0-9_])x(it|describe|test)\(|@pytest\.mark\.skip|t\.Skip\(|this\.skip\(' \
    | sed -E 's/^[[:space:]]+//' | sort
}

failures=0
originals=$(git ls-tree -r --name-only "$tag" -- "$folder")
current=$( (git ls-files -- "$folder"; git ls-files --others --exclude-standard -- "$folder") | sort -u)

for f in $originals; do
  if [ ! -f "$f" ]; then echo "GUARD: $f has been deleted"; failures=1; continue; fi
  if ! diff -q <(git show "$tag:$f" | normalize) <(normalize < "$f") >/dev/null; then
    echo "GUARD: $f has changed in something other than the skip:"
    diff <(git show "$tag:$f" | normalize) <(normalize < "$f") | head -n 10
    failures=1
  fi
  new=$(comm -13 <(git show "$tag:$f" | skips) <(skips < "$f"))
  if [ -n "$new" ]; then
    echo "GUARD: $f has a skip that was not in $tag:"
    echo "$new" | head -n 5
    failures=1
  fi
done
for f in $current; do
  echo "$originals" | grep -qxF "$f" || { echo "GUARD: unexpected new test: $f"; failures=1; }
done

for f in "$@"; do
  if [ ! -f "$f" ]; then echo "GUARD: $f does not exist"; failures=1; continue; fi
  left=$(skips < "$f")
  if [ -n "$left" ]; then
    echo "GUARD: $f still has a skip and its task should be done:"
    echo "$left" | head -n 5
    failures=1
  fi
done

[ "$failures" = 0 ] && echo "GUARD: acceptance tests intact."
exit "$failures"
