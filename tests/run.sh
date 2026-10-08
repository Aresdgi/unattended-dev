#!/usr/bin/env bash
# Tests for the scripts in skills/unattended-dev/assets/desatendido.
# Usage: bash tests/run.sh   (Linux and macOS; needs git, perl, awk, sed)
# SRC=<folder> runs them against other copies of the scripts (an older version).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${SRC:-$ROOT/skills/unattended-dev/assets/desatendido}"
WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
pass=0; fail=0

check() { # check "<name>" <expected exit> <command...>
  local name="$1" expected="$2"; shift 2
  "$@" >"$WORK/out" 2>&1; local got=$?
  if [ "$got" = "$expected" ]; then pass=$((pass + 1)); echo "ok   $name"
  else fail=$((fail + 1)); echo "FAIL $name (expected $expected, got $got)"; sed 's/^/     /' "$WORK/out" | tail -n 15; fi
}
check_fails() { # check_fails "<name>" <command...>: any non-zero exit
  local name="$1"; shift
  "$@" >"$WORK/out" 2>&1; local got=$?
  if [ "$got" != 0 ]; then pass=$((pass + 1)); echo "ok   $name (exit $got)"
  else fail=$((fail + 1)); echo "FAIL $name (expected non-zero, got 0)"; sed 's/^/     /' "$WORK/out" | tail -n 15; fi
}
check_out() { # check_out "<name>" "<text expected in the last output>"
  if grep -qF -- "$2" "$WORK/out"; then pass=$((pass + 1)); echo "ok   $1"
  else fail=$((fail + 1)); echo "FAIL $1 (missing: $2)"; sed 's/^/     /' "$WORK/out" | tail -n 15; fi
}

new_repo() { # fresh git repo with the scripts in .desatendido/
  local d="$WORK/$1"; rm -rf "$d"; mkdir -p "$d/tests/acceptance" "$d/src"; cd "$d" || exit 1
  git init -q; git config user.email t@t; git config user.name t; git config commit.gpgsign false
  mkdir .desatendido; cp "$SRC"/*.sh .desatendido/; chmod +x .desatendido/*.sh
  printf 'logs/\nAGENT_STOP\n' > .gitignore
}
replace() { # replace <file> <perl substitution>: portable in-place edit
  perl -pi -e "$2" "$1"
}
queue_files() { # queue_files <task...>: what phase zero leaves for queue.sh (allowed list src/ and the gate)
  local t; mkdir -p .desatendido/allowed
  for t in "$@"; do echo "src/" > ".desatendido/allowed/$t"; done
  printf '#!/usr/bin/env bash\n.desatendido/guardia-tests.sh fase-cero tests/acceptance $(.desatendido/queue.sh tests)\n' > .desatendido/gate.sh
  chmod +x .desatendido/gate.sh
}
qa_pass() { # qa_pass <task>: fidelity and technical PASS for the code as it is now
  $Q qa "$1" fidelity PASS "ok" >/dev/null && $Q qa "$1" technical PASS "ok" >/dev/null
}
backup_of() { # the newest backup branch of a task
  git for-each-ref --format='%(refname:short)' "refs/heads/queue/backup/$1-*" | tail -n 1
}
tree_state() { # HEAD, status and the content of every file (a temporary index, the real one is untouched)
  local d; d=$(mktemp -d)
  git rev-parse HEAD; git status --porcelain --untracked-files=all; git ls-files -s
  cp -p "$(git rev-parse --git-path index)" "$d/i"; GIT_INDEX_FILE="$d/i" git add -A; GIT_INDEX_FILE="$d/i" git write-tree
  rm -rf "$d"
}
same_tree() { [ "$(tree_state)" = "$1" ]; }

echo "== guardia-tests.sh"
new_repo guard
printf "describe.skip('T01', () => {\n  it('add', () => { expect(add(1, 2)).toBe(3) })\n  it('sub', () => { expect(sub(3, 1)).toBe(2) })\n})\n" > tests/acceptance/T01.test.ts
printf 'import pytest\n@pytest.mark.skip(reason="T02")\ndef test_a():\n    assert f(1) == 2\n' > tests/acceptance/test_t02.py
printf 'package x\nfunc TestA(t *testing.T) {\n\tt.Skip("T03")\n\tif f() != 1 { t.Fail() }\n}\n' > tests/acceptance/t03_test.go
printf "describe('T04', function () {\n  it('x', function () {\n    this.skip(); expect(f(1)).toBe(2)\n  })\n})\n" > tests/acceptance/T04.test.js
git add -A; git commit -qm start; git tag start
G=".desatendido/guardia-tests.sh start tests/acceptance"
check "unchanged tests pass" 0 $G
replace tests/acceptance/T01.test.ts 's/describe\.skip\(/describe(/'
replace tests/acceptance/test_t02.py '$_ = "" if /\@pytest\.mark\.skip/'
replace tests/acceptance/t03_test.go '$_ = "" if /t\.Skip\(/'
replace tests/acceptance/T04.test.js 's/this\.skip\(\); //'
check "removing skips (js, py, go, this.skip) passes" 0 $G tests/acceptance/T01.test.ts tests/acceptance/test_t02.py tests/acceptance/t03_test.go tests/acceptance/T04.test.js
git stash -q; git stash drop -q
check "a task test that still has its skip fails" 1 $G tests/acceptance/T01.test.ts
replace tests/acceptance/T01.test.ts 's/toBe\(3\)/toBe(4)/'
check "changing an expected value fails" 1 $G
git checkout -q -- tests
replace tests/acceptance/T01.test.ts 's/describe\.skip\(/describe(/; s/  it\(.sub/  xit(\x27sub/'
check "adding xit to a failing test fails" 1 $G
git checkout -q -- tests
replace tests/acceptance/T01.test.ts 's/  it\(.sub/  it.skip(\x27sub/'
check "adding it.skip fails" 1 $G
git checkout -q -- tests
replace tests/acceptance/T04.test.js '$_ = "" if /this\.skip\(\); expect/'
check "deleting a line with this.skip(); expect(...) fails" 1 $G
git checkout -q -- tests
echo "x" > tests/acceptance/extra.test.ts
check "an unexpected new test fails" 1 $G
rm tests/acceptance/extra.test.ts
rm tests/acceptance/test_t02.py
check "a deleted test fails" 1 $G
git checkout -q -- tests

echo "== lanzar-worker.sh"
new_repo worker
echo x > src/a.ts; echo y > src/b.ts; git add -A; git commit -qm base
W=".desatendido/lanzar-worker.sh"
check "allowed change passes" 0 $W impl T01 --allowed "src/a.ts" -- bash -c 'echo 1 >> src/a.ts'
check "uncommitted change outside fails with 3" 3 $W impl T01 --allowed "src/a.ts" -- bash -c 'echo 1 >> src/b.ts'
check_out "it names the file outside" "OUT OF TASK: src/b.ts"
git checkout -q -- src
check "committed change outside fails with 3" 3 $W impl T01 --allowed "src/a.ts" -- bash -c 'echo 1 >> src/b.ts; git commit -qam sneaky'
git reset -q --hard HEAD~1
echo dirty >> src/b.ts
check "changing an already dirty file outside fails with 3" 3 $W impl T01 --allowed "src/a.ts" -- bash -c 'echo more >> src/b.ts'
git checkout -q -- src
check "deleting a file outside fails with 3" 3 $W impl T01 --allowed "src/a.ts" -- rm src/b.ts
git checkout -q -- src
check "a folder in --allowed covers its files" 0 $W impl T01 --allowed "src/" -- bash -c 'echo 1 > src/c.ts'
rm -f src/c.ts
check "timeout returns 124" 124 $W impl T01 --timeout 1 -- bash -c 'sleep 20'
check "a worker killed by SIGTERM does not return 0" 143 $W impl T01 -- bash -c 'kill -TERM $$'
check "the worker's own exit code is kept" 7 $W qa smoke -- bash -c 'exit 7'
# Blocked by permissions for normal users; as root it is still caught as OUT OF TASK.
check_fails "writing into --readonly tests never passes" $W impl T01 --readonly "tests" -- bash -c 'echo x >> tests/acceptance/new.txt'
rm -f tests/acceptance/new.txt
check "--readonly restores write permission afterwards" 0 bash -c 'touch tests/acceptance/after.txt'
rm -f tests/acceptance/after.txt
check_fails "a worker that writes the queue scripts never passes" $W impl T01 --allowed "src/a.ts" -- bash -c 'echo "exit 0" >> .desatendido/queue.sh'
# Blocked by permissions for normal users; as root it is still caught as OUT OF TASK.
check "the queue scripts are unchanged" 0 bash -c '[ "$(id -u)" = 0 ] || git diff --quiet -- .desatendido'
git checkout -q -- .desatendido
check "the scripts folder is writable again afterwards" 0 bash -c '[ -w .desatendido/queue.sh ] && touch .desatendido/x && rm .desatendido/x'

echo "== con-limite.sh"
new_repo limit
L=".desatendido/con-limite.sh"
check "a command within its time keeps its exit code" 3 $L 5 -- bash -c 'exit 3'
check "over its time it returns 124" 124 $L 1 -- sleep 20
check "it stops the whole process group" 1 bash -c "$L 1 -- bash -c 'sleep 30 & echo \$! > child.pid; wait'; sleep 1; kill -0 \$(cat child.pid) 2>/dev/null"
began=$(date +%s)
check "when the command ends, what it left running ends too" 0 bash -c "$L 20 -- bash -c 'sleep 30 & echo \$! > child2.pid; exit 0' | cat"
check "a pipe after it does not wait for the leftover" 0 test $(( $(date +%s) - began )) -lt 10
check "the leftover process is gone" 1 bash -c 'sleep 1; kill -0 $(cat child2.pid) 2>/dev/null'
check "it needs -- before the command" 2 $L 5 true
check "it needs whole seconds" 2 $L 1.5 -- true

echo "== vigilar-worker.sh (workers that start and finish on their own)"
new_repo vigil
echo x > src/a.ts; echo y > src/b.ts; printf "describe('T01', () => {})\n" > tests/acceptance/T01.test.ts
git add -A; git commit -qm base
V=".desatendido/vigilar-worker.sh"
check "begin makes the tests read-only" 0 $V begin impl T01 --readonly "tests"
check_fails "while it runs, the tests cannot be written" bash -c '[ "$(id -u)" = 0 ] && exit 1; echo x >> tests/acceptance/T01.test.ts'
echo 1 >> src/a.ts
check "end passes when only allowed files changed" 0 $V end impl T01 --allowed "src/a.ts"
check "end restores write permission" 0 bash -c 'touch tests/acceptance/x && rm tests/acceptance/x'
$V begin impl T01 >/dev/null
check_fails "between begin and end the scripts folder is read-only" bash -c '[ "$(id -u)" = 0 ] && exit 1; echo x >> .desatendido/queue.sh'
check_fails "and no file can be added to it" bash -c '[ "$(id -u)" = 0 ] && exit 1; touch .desatendido/new.sh'
$V end impl T01 --allowed "src/a.ts" >/dev/null
check "end makes the scripts folder writable again" 0 bash -c 'touch .desatendido/x && rm .desatendido/x'
git checkout -q -- src
$V begin impl T01 >/dev/null
echo 1 >> src/b.ts; git commit -qam "sneaky commit"
check "end catches a committed file outside" 3 $V end impl T01 --allowed "src/a.ts"
check_out "it names it" "OUT OF TASK: src/b.ts"
git reset -q --hard HEAD~1
$V begin qa T01 >/dev/null
echo 1 > src/new.ts
check "QA (nothing allowed) creating a file is out of task" 3 $V end qa T01
rm -f src/new.ts
check "end without begin is a usage error" 2 $V end impl T09
check "no arguments shows usage" 2 $V

echo "== queue.sh"
new_repo queue
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
| T02 | b | T01 | tests/acceptance/T02.test.ts | PENDING |
| T03 | c | none | tests/acceptance/T03.test.ts | PENDING |
EOF
for t in T01 T02 T03; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
queue_files T01 T02 T03
git add -A; git commit -qm start; git tag fase-cero
Q=".desatendido/queue.sh"
check "next gives the first ready task" 0 $Q next; check_out "it is T01" "T01"
check "start marks IN PROGRESS and removes the skip" 0 $Q start T01
check "the started task's test has no skip" 1 grep -q "skip" tests/acceptance/T01.test.ts
check "state reads IN PROGRESS" 0 $Q state T01; check_out "state is IN PROGRESS" "IN PROGRESS"
check "the Log records the start commit" 0 grep -qE "T01 started at [0-9a-f]{40}" STATUS.md
check "tests lists the started task" 0 $Q tests; check_out "T01 test listed" "tests/acceptance/T01.test.ts"
check "next skips a task whose dependency is not DONE" 0 $Q next; check_out "it is T03" "T03"
check "set rejects an invalid state" 3 $Q set T01 FINISHED
check "set refuses DONE: only done closes a task" 3 $Q set T01 DONE; check_out "it says to use done" "queue.sh done"
check "set refuses IN PROGRESS: only start opens a task" 3 $Q set T03 "IN PROGRESS"; check_out "it says to use start" "queue.sh start"
check "T01 is still IN PROGRESS" 0 $Q state T01; check_out "T01 IN PROGRESS" "IN PROGRESS"
echo impl > src/T01.ts; qa_pass T01; $Q done T01 "impl" >/dev/null
check "next now gives T02" 0 $Q next; check_out "it is T02" "T02"
check "set BLOCKED works" 0 $Q set T02 BLOCKED
check "set writes itself in the Log" 0 grep -q "T02 set to BLOCKED by hand" STATUS.md
$Q start T03 >/dev/null; echo impl > src/T03.ts; qa_pass T03; $Q done T03 "impl" >/dev/null
check "queue finished returns 1" 1 $Q next
$Q set T02 PENDING >/dev/null; $Q set T01 BLOCKED >/dev/null
check "a task depending on a BLOCKED one becomes BLOCKED" 1 $Q next
check "T02 is now BLOCKED" 0 $Q state T02; check_out "T02 BLOCKED" "BLOCKED"
$Q set T01 PENDING >/dev/null; $Q start T01 >/dev/null; echo half > src/half.ts
check "recover saves and resets an IN PROGRESS task" 0 $Q recover
check_out "recover names the task" "T01 interrupted"
check "after recover T01 is PENDING" 0 $Q state T01; check_out "T01 PENDING" "PENDING"
check "the half-done file is gone from the tree" 1 test -f src/half.ts
check "summary counts states" 0 $Q summary; check_out "summary line" "Progress:"

echo "== queue.sh: state survives block and failures"
new_repo state
cat > STATUS.md <<'EOF2'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
| T02 | b | T01 | tests/acceptance/T02.test.ts | PENDING |
| T03 | c | T02 | tests/acceptance/T03.test.ts | PENDING |
EOF2
for t in T01 T02 T03; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
queue_files T01 T02 T03
git add -A; git commit -qm start; git tag fase-cero
Q=".desatendido/queue.sh"
$Q start T01 >/dev/null; echo impl > src/T01.ts; qa_pass T01
check "T01 closes with done" 0 $Q done T01 "impl"
$Q start T02 >/dev/null; echo half > src/T02.ts
check "block saves the task's work" 0 $Q block T02 "tests keep failing"
check "a blocked T02 does not bring T01 back to IN PROGRESS" 0 $Q state T01; check_out "T01 still DONE" "DONE"
check "T02 is BLOCKED" 0 $Q state T02; check_out "T02 BLOCKED" "BLOCKED"
check "the backup branch has T02's work" 0 git cat-file -e "$(backup_of T02):src/T02.ts"
check "the Log names the backup branch" 0 grep -q "T02 BLOCKED: tests keep failing; its work is in branch queue/backup/T02-" STATUS.md
check "the tree is clean after block" 0 bash -c '[ -z "$(git status --porcelain)" ]'
$Q set T02 PENDING >/dev/null; $Q set T03 PENDING >/dev/null
# done is atomic: state and work in one commit.
$Q start T02 >/dev/null; echo impl > src/T02.ts; qa_pass T02
check "done commits state and work together" 0 $Q done T02 "implemented"
check "T02 is DONE in the last commit" 0 bash -c 'git show HEAD:STATUS.md | grep -q "| T02 | b | T01 | tests/acceptance/T02.test.ts | DONE |"'
check "the last commit has T02's work" 0 bash -c 'git show --name-only HEAD | grep -q src/T02.ts'
check "done refuses a task that is not IN PROGRESS" 3 $Q done T03 "nothing"
# Recover after DONE tasks keeps them DONE and the queue can go on.
$Q start T03 >/dev/null; echo half > src/T03.ts
check "recover after DONE tasks" 0 $Q recover
check "T01 and T02 stay DONE" 0 bash -c '[ "$('$Q' state T01)" = DONE ] && [ "$('$Q' state T02)" = DONE ]'
check "their work stays" 0 test -f src/T02.ts
check "next gives T03 again, not a stuck queue" 0 $Q next; check_out "it is T03" "T03"
# A git step that cannot be done stops everything and marks nothing.
$Q start T03 >/dev/null; echo half > src/T03.ts
touch .git/index.lock
check "recover fails with 4 when git cannot put the files back" 4 $Q recover
check "the task stays IN PROGRESS" 0 $Q state T03; check_out "T03 still IN PROGRESS" "IN PROGRESS"
check "its work is still in the tree" 0 test -f src/T03.ts
check "block also fails with 4" 4 $Q block T03 "x"
rm -f .git/index.lock
$Q block T03 "clean up" >/dev/null; $Q set T03 PENDING >/dev/null

echo "== queue.sh: unrelated changes never enter a task"
echo "readme" > README.md; git add README.md; git commit -qm readme
echo "my own note" >> README.md
check "start refuses with unrelated changes in the tree" 3 $Q start T03
check_out "it names the file" "README.md"
check "the task did not start" 0 $Q state T03; check_out "T03 still PENDING" "PENDING"
check "my change is untouched" 0 grep -q "my own note" README.md
git checkout -q -- README.md

echo "== queue.sh: fixes, decisions and the Log"
new_repo fixes
cat > STATUS.md <<'EOF2'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
| T02 | b | T01 | tests/acceptance/T02.test.ts | PENDING |

## Log

EOF2
for t in T01 T02; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
queue_files T01 T02
git add -A; git commit -qm start; git tag fase-cero
Q=".desatendido/queue.sh"
$Q start T01 >/dev/null
check "the Log records the start" 0 grep -q "T01 started" STATUS.md
echo half > src/T01.ts
check "fix 1 is allowed" 0 $Q fix T01 "gate red"; check_out "it counts" "fix 1 of 2"
check "fix 2 is allowed" 0 $Q fix T01 "QA FAIL"; check_out "it counts" "fix 2 of 2"
check "a third fix is refused with 5" 5 $Q fix T01 "again"
check_out "it says to block" "block it"
check "a decision is recorded" 0 $Q decide T01 "reject distances under 0.1 km with fuera_de_rango"
check "the decision is in DECISIONES.md" 0 grep -q "T01: reject distances under 0.1 km" docs/DECISIONES.md
check "the decision is committed" 0 bash -c 'git show HEAD --name-only | grep -q docs/DECISIONES.md'
check "the task work is not in the decision commit" 1 bash -c 'git show HEAD --name-only | grep -q src/T01.ts'
check "a decision gives one more fix" 0 $Q fix T01 "after the decision"; check_out "fix 3 of 3" "fix 3 of 3"
check "then it is refused again" 5 $Q fix T01 "more"
$Q decide T01 "second decision" >/dev/null
check "a third decision is refused with 5" 5 $Q decide T01 "third"
check "block writes the reason in the Log" 0 $Q block T01 "contradictory reviews"
check "the Log has the BLOCKED line" 0 grep -q "T01 BLOCKED: contradictory reviews" STATUS.md
check "the decisions survive the block" 0 grep -q "second decision" docs/DECISIONES.md
check "next writes why a dependent is blocked" 1 $Q next
check "the Log says T02 depends on T01" 0 grep -q "T02 BLOCKED: depends on T01" STATUS.md
$Q set T01 PENDING >/dev/null; $Q set T02 PENDING >/dev/null
$Q start T01 >/dev/null
check "a new start resets the fix count" 0 $Q fix T01 "fresh start"; check_out "fix 1 of 2" "fix 1 of 2"
mkdir -p src; echo impl > src/T01.ts; qa_pass T01
check "done writes the Log line in the same commit" 0 $Q done T01 "implemented"
check "the DONE line is in the committed STATUS.md" 0 bash -c 'git show HEAD:STATUS.md | grep -q "T01 DONE: implemented"'
$Q start T02 >/dev/null; mkdir -p src; echo half > src/T02.ts
check "recover writes the interruption in the Log" 0 $Q recover
check "the Log names the backup branch" 0 grep -q "T02 interrupted: back to PENDING; its work is in branch queue/backup/T02-" STATUS.md
check "fix needs the task IN PROGRESS" 3 $Q fix T02 "x"
$Q start T02 >/dev/null; echo half > src/T02.ts
check "note writes a free line in the Log" 0 $Q note "Orca run run_123"
check "the note is committed" 0 bash -c 'git show HEAD:STATUS.md | grep -q "note: Orca run run_123"'
check "the note commit takes only STATUS.md" 1 bash -c 'git show HEAD --name-only | grep -q src/T02.ts'
check "a note does not count as a fix" 0 $Q fix T02 "after a note"; check_out "fix 1 of 2" "fix 1 of 2"
check "note needs a text" 1 $Q note

echo "== queue.sh: start respects dependencies, one task at a time"
new_repo deps
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
| T02 | b | T01 | tests/acceptance/T02.test.ts | PENDING |
| T03 | c | none | tests/acceptance/T03.test.ts | PENDING |
| T04 | d | none | tests/acceptance/T04.test.ts | PENDING |
EOF
for t in T01 T02 T03 T04; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
queue_files T01 T02 T03
git add -A; git commit -qm start
Q=".desatendido/queue.sh"
check "start refuses a task whose dependency is PENDING" 3 $Q start T02
check_out "it names the dependency" "T02 depends on T01, which is PENDING"
check "the task stays PENDING" 0 $Q state T02; check_out "T02 PENDING" "PENDING"
$Q set T01 BLOCKED >/dev/null
check "start refuses a task whose dependency is BLOCKED" 3 $Q start T02
check_out "it says it is BLOCKED" "which is BLOCKED"
$Q set T01 PENDING >/dev/null
$Q start T01 >/dev/null
check "start refuses a second task while one is IN PROGRESS" 3 $Q start T03
check_out "it names the task in progress" "T01 is IN PROGRESS"
check "the second task stays PENDING" 0 $Q state T03; check_out "T03 PENDING" "PENDING"
$Q recover >/dev/null
check "start refuses a task with no allowed list" 3 $Q start T04
check_out "it says what is missing" "no allowed list"

echo "== queue.sh: a task is measured from its start"
new_repo scope
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
| T02 | b | T01 | tests/acceptance/T02.test.ts | PENDING |
EOF
for t in T01 T02; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
echo '{"scripts":{"test":"vitest run"}}' > package.json; echo old > src/f.ts
mkdir -p docs; echo guide > docs/guide.md
queue_files T01 T02; echo "src/f.ts" > .desatendido/allowed/T01
git add -A; git commit -qm start; git tag fase-cero
Q=".desatendido/queue.sh"; W=".desatendido/lanzar-worker.sh"
$Q start T01 >/dev/null
# The scenario that was reproduced: a change out of task survives a fix.
check "worker 1 also changes package.json: exit 3" 3 $W impl T01 --allowed "src/f.ts" -- bash -c 'echo new > src/f.ts; echo "{\"scripts\":{\"test\":\"exit 0\"}}" > package.json'
$Q fix T01 "out of task" >/dev/null
check "worker 2 only touches its file: exit 0" 0 $W impl T01 --allowed "src/f.ts" -- bash -c 'echo newer > src/f.ts'
check "outside still sees what worker 1 left" 6 $Q outside T01; check_out "it names package.json" "package.json"
qa_pass T01
check "done refuses with 6 while package.json is changed" 6 $Q done T01 "ok"
check "T01 stays IN PROGRESS" 0 $Q state T01; check_out "T01 IN PROGRESS" "IN PROGRESS"
check "restore-outside puts it back" 0 $Q restore-outside T01
check "package.json is as at the start" 0 grep -q "vitest run" package.json
check "the task's own work stays" 0 grep -qx newer src/f.ts
check "nothing is outside now" 0 $Q outside T01
check "the copy in the backup branch has the change" 0 bash -c "git show '$(backup_of T01):package.json' | grep -q 'exit 0'"
qa_pass T01
check "done closes T01" 0 $Q done T01 "ok"
check "the DONE commit does not touch package.json" 1 bash -c 'git show --name-only --format= HEAD | grep -qx package.json'
check "package.json in the last commit is the original" 0 bash -c 'git show HEAD:package.json | grep -q "vitest run"'
# restore-outside with a new, a modified, a deleted and a committed file.
$Q start T02 >/dev/null
echo work > src/T02.ts
echo note > notes.txt; echo more >> package.json; rm docs/guide.md
echo ci > ci.yml; git add ci.yml; git commit -qm "worker commit"
check "outside lists every file out of the task" 6 $Q outside T02
check_out "the new one" "notes.txt"; check_out "the modified one" "package.json"
check_out "the deleted one" "docs/guide.md"; check_out "the committed one" "ci.yml"
check "restore-outside" 0 $Q restore-outside T02
check "the new file is gone" 1 test -e notes.txt
check "the committed new file is gone" 1 test -e ci.yml
check_fails "and it is not in the last commit" git cat-file -e HEAD:ci.yml
check "the modified file is back" 1 grep -qx more package.json
check "the deleted file is back" 0 grep -qx guide docs/guide.md
check "the task's own file stays" 0 grep -qx work src/T02.ts
check "only the task's work is left in the tree" 1 bash -c 'git status --porcelain --untracked-files=all | grep -v -e src/T02.ts -e tests/acceptance/T02.test.ts | grep -q .'
# Only queue.sh writes STATUS.md, and the allowed list is the one at the start.
echo "- forged line" >> STATUS.md
check "an edit to STATUS.md is outside the task" 6 $Q outside T02; check_out "it names STATUS.md" "STATUS.md"
$Q restore-outside T02 >/dev/null
check "restore-outside removes the edit" 1 grep -q "forged line" STATUS.md
echo "package.json" >> .desatendido/allowed/T02; echo more >> package.json
check "widening the allowed list during the task does not help" 6 $Q outside T02; check_out "package.json is still outside" "package.json"
$Q restore-outside T02 >/dev/null
# A worker that commits broken code: block and recover undo the commits too.
echo broken > src/f.ts; git commit -qam "worker commit 2"
check "block after a worker commit" 0 $Q block T02 "broken"
check "the committed file is back as at the start of T02" 0 grep -qx newer src/f.ts
check "the task's new file is gone" 1 test -e src/T02.ts
check "the test is skipped again" 0 grep -q "skip" tests/acceptance/T02.test.ts
check "the backup branch has the broken code" 0 bash -c "git show '$(backup_of T02):src/f.ts' | grep -qx broken"
check "the history was not rewritten" 0 bash -c 'git log --format=%s | grep -qx "worker commit 2"'
check "the tree is clean" 0 bash -c '[ -z "$(git status --porcelain --untracked-files=all)" ]'
$Q set T02 PENDING >/dev/null; $Q start T02 >/dev/null
echo broken2 > src/f.ts; git commit -qam "worker commit 3"; echo half > src/T02.ts
check "recover after a worker commit" 0 $Q recover
check "the committed file is back" 0 grep -qx newer src/f.ts
check "T02 is PENDING" 0 $Q state T02; check_out "T02 PENDING" "PENDING"
check "the backup branch has it" 0 bash -c "git show '$(backup_of T02):src/f.ts' | grep -qx broken2"
check "the tree is clean after recover" 0 bash -c '[ -z "$(git status --porcelain --untracked-files=all)" ]'

echo "== queue.sh: done checks before closing"
new_repo close
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
| T02 | b | none | tests/acceptance/T02.test.ts | PENDING |
EOF
for t in T01 T02; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
echo '{}' > package.json
queue_files T01 T02; rm .desatendido/gate.sh
mkdir -p .desatendido/qa; printf 'combined design\n' > .desatendido/qa/T02
git add -A; git commit -qm start; git tag fase-cero
Q=".desatendido/queue.sh"
$Q start T01 >/dev/null; echo impl > src/T01.ts; qa_pass T01
before=$(tree_state)
check "done without a gate refuses with 3" 3 $Q done T01 "x"; check_out "it says so" "no gate"
check "T01 stays IN PROGRESS" 0 $Q state T01; check_out "IN PROGRESS" "IN PROGRESS"
check "the tree did not change" 0 same_tree "$before"
$Q recover >/dev/null; queue_files T01 T02
git add -A; git commit -qm "gate"
$Q start T01 >/dev/null; echo impl > src/T01.ts
before=$(tree_state)
check "done without QA refuses with 8" 8 $Q done T01 "x"; check_out "it says what is missing" "fidelity: no QA recorded"
check "T01 stays IN PROGRESS" 0 $Q state T01; check_out "IN PROGRESS" "IN PROGRESS"
check "the tree did not change" 0 same_tree "$before"
echo hack >> package.json; qa_pass T01
before=$(tree_state)
check "done with a file outside refuses with 6" 6 $Q done T01 "x"; check_out "it names it" "package.json"
check "T01 stays IN PROGRESS" 0 $Q state T01; check_out "IN PROGRESS" "IN PROGRESS"
check "the tree did not change" 0 same_tree "$before"
git checkout -q -- package.json; qa_pass T01
echo "// weaker" >> tests/acceptance/T01.test.ts
before=$(tree_state)
check "done with a failing gate refuses with 7" 7 $Q done T01 "x"; check_out "it shows the gate output" "GUARD"
check "T01 stays IN PROGRESS" 0 $Q state T01; check_out "IN PROGRESS" "IN PROGRESS"
check "the tree did not change" 0 same_tree "$before"
replace tests/acceptance/T01.test.ts '$_ = "" if /weaker/'
echo more >> src/T01.ts
check "a change after the QA PASS refuses with 8" 8 $Q done T01 "x"; check_out "it says the code changed" "changed after the QA"
qa_pass T01; $Q qa T01 technical FAIL "a bug" >/dev/null
check "a QA FAIL after the PASS refuses with 8" 8 $Q done T01 "x"; check_out "it says FAIL" "the last QA is FAIL"
check "qa rejects an unknown type" 3 $Q qa T01 style PASS "x"
check "qa rejects a result other than PASS or FAIL" 3 $Q qa T01 technical OK "x"
qa_pass T01
check "a QA PASS for the code as it is: done passes" 0 $Q done T01 "implemented"
check "qa needs the task IN PROGRESS" 3 $Q qa T02 fidelity PASS "x"
$Q start T02 >/dev/null; echo ui > src/T02.ts
$Q qa T02 combined PASS "fidelity and technical" >/dev/null
check "a task that needs design QA refuses without it" 8 $Q done T02 "x"; check_out "it names design" "design: no QA recorded"
$Q qa T02 design PASS "screenshots fine" >/dev/null
check "combined and design PASS: done passes" 0 $Q done T02 "implemented"

echo "== queue.sh: only queue.sh writes STATUS.md during a task"
new_repo trust
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
| T02 | b | none | tests/acceptance/T02.test.ts | PENDING |
EOF
for t in T01 T02; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
echo old > src/f.ts
queue_files T01 T02
git add -A; git commit -qm start; git tag fase-cero
Q=".desatendido/queue.sh"
$Q start T01 >/dev/null; echo impl > src/T01.ts
replace STATUS.md 's/^\| T02 \| b \| none \| tests\/acceptance\/T02\.test\.ts \| PENDING \|$/| T02 | b | none | none | DONE |/'
check "fix refuses while STATUS.md has changes queue.sh did not make" 6 $Q fix T01 "x"; check_out "it names STATUS.md" "STATUS.md"
check "qa refuses too" 6 $Q qa T01 fidelity PASS "x"
check "note refuses too" 6 $Q note "x"
check "decide refuses too" 6 $Q decide T01 "x"
check "set refuses too" 6 $Q set T02 BLOCKED
check "the edit was never committed" 0 bash -c 'git show HEAD:STATUS.md | grep -q "| T02 | b | none | tests/acceptance/T02.test.ts | PENDING |"'
$Q restore-outside T01 >/dev/null
check "after restore-outside, fix works" 0 $Q fix T01 "x"
echo "- worker progress" >> STATUS.md; git commit -qam "worker: progress"
check "an edit the worker committed is outside" 6 $Q outside T01
check "restore-outside puts it back" 0 $Q restore-outside T01
check "once put back it is no longer outside" 0 $Q outside T01
qa_pass T01
check "and done can close the task" 0 $Q done T01 "impl"
$Q start T02 >/dev/null; echo broken > src/f.ts
: > STATUS.md; git commit -qam "worker: wipe"
check "recover with an emptied STATUS.md committed" 0 $Q recover
check "T02 is back to PENDING" 0 $Q state T02; check_out "T02 PENDING" "PENDING"
check "the broken code is gone" 0 grep -qx old src/f.ts
check "next gives T02: the queue does not look finished" 0 $Q next; check_out "it is T02" "T02"
$Q start T02 >/dev/null; echo broken > src/f.ts
.desatendido/vigilar-worker.sh begin impl T02 --readonly "tests/acceptance"
git rm -q STATUS.md; git commit -qam "worker: delete"
check "recover with STATUS.md deleted and committed" 0 $Q recover
check "STATUS.md is back with T02 PENDING" 0 $Q state T02; check_out "T02 PENDING" "PENDING"
check "write permission is back too" 0 bash -c '[ -w .desatendido/queue.sh ] && [ -w tests/acceptance/T02.test.ts ]'
$Q start T02 >/dev/null; echo broken > src/f.ts
replace STATUS.md 's/^\| T02 \| b \| none \| tests\/acceptance\/T02\.test\.ts \| IN PROGRESS \|$/| T02 | b | none | tests\/acceptance\/T02.test.ts | DONE |/'
git commit -qam "worker: T02 done"
check "start refuses after a worker marked its task DONE" 6 $Q start T01
check "nothing was committed by the queue" 0 bash -c '[ "$(git log -1 --format=%s)" = "worker: T02 done" ]'
check "recover puts T02 back to PENDING" 0 $Q recover
check "T02 is PENDING, not DONE" 0 $Q state T02; check_out "T02 PENDING" "PENDING"
$Q start T02 >/dev/null; echo half > src/T02.ts
echo "- my note" >> STATUS.md; mkdir -p docs; echo "my decision" > docs/DECISIONES.md
check "recover with STATUS.md and DECISIONES.md changed by hand" 0 $Q recover
check "a backup branch keeps them as they were found" 0 bash -c 'for b in $(git for-each-ref --format="%(refname:short)" "refs/heads/queue/backup/T02-*"); do git show "$b:STATUS.md" | grep -q "my note" && git show "$b:docs/DECISIONES.md" | grep -q "my decision" && exit 0; done; exit 1'
check "and the tree is clean" 0 bash -c '[ -z "$(git status --porcelain --untracked-files=all)" ]'

echo "== queue.sh: each worktree trusts only its own queue"
new_repo wta
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
EOF
printf "describe.skip('T01', () => {})\n" > tests/acceptance/T01.test.ts
echo old > src/f.ts
queue_files T01
git add -A; git commit -qm start
git worktree add -q -b other "$WORK/wtb"
Q=".desatendido/queue.sh"
$Q start T01 >/dev/null; echo broken > src/f.ts; : > STATUS.md; git commit -qam "worker: wipe"
(cd "$WORK/wtb" && .desatendido/queue.sh note "from the other worktree" >/dev/null)
check "recover in this worktree after the other one used the queue" 0 $Q recover
check "T01 is back to PENDING" 0 $Q state T01; check_out "T01 PENDING" "PENDING"
check "the broken code is gone" 0 grep -qx old src/f.ts
check "next gives T01: the queue does not look finished" 0 $Q next; check_out "it is T01" "T01"

echo "== queue.sh: a refused done leaves the tree as it was"
new_repo gate
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
EOF
printf "describe.skip('T01', () => {})\n" > tests/acceptance/T01.test.ts
queue_files T01
cat > .desatendido/gate.sh <<'EOF'
#!/usr/bin/env bash
.desatendido/guardia-tests.sh fase-cero tests/acceptance $(.desatendido/queue.sh tests) || exit 1
if [ -f logs/gate-writes ]; then echo generated >> src/T01.ts; fi
if [ -f logs/gate-breaks ]; then echo clobbered > src/T01.ts; echo gen > src/gen.ts; exit 1; fi
if [ -f logs/gate-status ]; then perl -pi -e 's/IN PROGRESS/DONE/' STATUS.md; exit 1; fi
if [ -f logs/gate-stages ]; then echo C > src/T01.ts; git add src/T01.ts; exit 1; fi
if [ -f logs/gate-commits ]; then echo D >> src/T01.ts; git add -A src; git commit -qm "gate commit"; exit 0; fi
if [ -f logs/gate-switches ]; then git switch -q other; exit 1; fi
exit 0
EOF
chmod +x .desatendido/gate.sh
git add -A; git commit -qm start; git tag fase-cero
git switch -q -c other; echo b > b.txt; git add b.txt; git commit -qm "other's own commit"; git switch -q -
Q=".desatendido/queue.sh"
$Q start T01 >/dev/null; echo impl > src/T01.ts; qa_pass T01
mkdir -p logs; touch logs/gate-writes
before=$(tree_state)
check "a gate that passes but changes an allowed file: done refuses with 7" 7 $Q done T01 "x"
check_out "it says the gate changed files" "the gate changed files"
check "the file is as before the gate" 0 same_tree "$before"
check "T01 stays IN PROGRESS" 0 $Q state T01; check_out "T01 IN PROGRESS" "IN PROGRESS"
rm -f logs/gate-writes; touch logs/gate-breaks
check "a failing gate that overwrites the work: done refuses with 7" 7 $Q done T01 "x"
check "the work is as before the gate" 0 same_tree "$before"
check "the file the gate created is gone" 1 test -e src/gen.ts
rm -f logs/gate-breaks; touch logs/gate-status
check "a failing gate that rewrites STATUS.md: done refuses with 7" 7 $Q done T01 "x"
check "STATUS.md is as before the gate" 0 same_tree "$before"
check "T01 is still IN PROGRESS" 0 $Q state T01; check_out "T01 IN PROGRESS" "IN PROGRESS"
rm -f logs/gate-status
echo A > src/T01.ts; git add src/T01.ts; echo impl > src/T01.ts; qa_pass T01
before=$(tree_state)
touch logs/gate-stages
check "a failing gate that stages a file: done refuses with 7" 7 $Q done T01 "x"
check "what was staged is as before the gate" 0 same_tree "$before"
rm -f logs/gate-stages; touch logs/gate-commits
check "a gate that commits: done refuses with 7" 7 $Q done T01 "x"
check "HEAD, the index and the files are as before the gate" 0 same_tree "$before"
rm -f logs/gate-commits; touch logs/gate-switches
branch=$(git symbolic-ref HEAD); tip=$(git rev-parse HEAD); other_tip=$(git rev-parse other)
check "a gate that switches branch: done stops with 4" 4 $Q done T01 "x"
check_out "it says the gate switched branch" "switched branch"
check "the queue branch was not moved" 0 bash -c "[ \"\$(git rev-parse '$branch')\" = '$tip' ]"
check "the other branch was not moved" 0 bash -c "[ \"\$(git rev-parse other)\" = '$other_tip' ]"
check "T01 is still IN PROGRESS" 0 bash -c "git show '$branch':STATUS.md | grep -q '| T01 | a | none | tests/acceptance/T01.test.ts | IN PROGRESS |'"
rm -f logs/gate-switches; git switch -q "${branch#refs/heads/}"
check "with a gate that changes nothing, done passes" 0 $Q done T01 "impl"
check "the DONE commit has the code the QA saw" 0 bash -c '[ "$(git show HEAD:src/T01.ts)" = impl ]'

echo "== queue.sh: block and recover with a new file staged and changed again"
new_repo staged
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
EOF
printf "describe.skip('T01', () => {})\n" > tests/acceptance/T01.test.ts
queue_files T01
git add -A; git commit -qm start
Q=".desatendido/queue.sh"
$Q start T01 >/dev/null; echo A > src/new.ts; git add src/new.ts; echo B > src/new.ts
check "recover works" 0 $Q recover
check "the new file is gone" 1 test -e src/new.ts
check "the tree is clean" 0 bash -c '[ -z "$(git status --porcelain --untracked-files=all)" ]'
check "the backup has its last content" 0 bash -c "[ \"\$(git show '$(backup_of T01):src/new.ts')\" = B ]"
$Q start T01 >/dev/null; echo A > src/new.ts; git add src/new.ts; echo B > src/new.ts
check "block works" 0 $Q block T01 "x"
check "the new file is gone after block" 1 test -e src/new.ts

echo "== queue.sh: the project's git hooks"
new_repo hooks
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
| T02 | b | none | tests/acceptance/T02.test.ts | PENDING |
EOF
for t in T01 T02; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
queue_files T01 T02
git add -A; git commit -qm start; git tag fase-cero
mkdir -p logs; touch logs/hook-fails
printf '#!/bin/sh\necho ran >> logs/hook.log\n[ -f logs/hook-fails ] && exit 1\nexit 0\n' > "$(git rev-parse --git-path hooks)/pre-commit"
chmod +x "$(git rev-parse --git-path hooks)/pre-commit"
Q=".desatendido/queue.sh"
check "start does not run the hooks" 0 $Q start T01
check "fix does not run them" 0 $Q fix T01 "x"
check "note does not run them" 0 $Q note "x"
check "qa does not run them" 0 $Q qa T01 fidelity PASS "x"
check "decide does not run them" 0 $Q decide T01 "a rule"
check "set does not run them" 0 $Q set T02 BLOCKED
check "no hook ran for those commits" 1 test -e logs/hook.log
echo impl > src/T01.ts; qa_pass T01
check "done runs the hooks: a failing hook stops it with 4" 4 $Q done T01 "impl"
check "the hook ran" 0 test -e logs/hook.log
check "T01 stays IN PROGRESS" 0 $Q state T01; check_out "T01 IN PROGRESS" "IN PROGRESS"
rm -f logs/hook-fails
check "with a passing hook, done closes the task" 0 $Q done T01 "impl"

echo "== queue.sh: recover gives back write permission"
new_repo perms
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
EOF
printf "describe.skip('T01', () => {})\n" > tests/acceptance/T01.test.ts
queue_files T01
git add -A; git commit -qm start
Q=".desatendido/queue.sh"
$Q start T01 >/dev/null
.desatendido/vigilar-worker.sh begin impl T01 --readonly "tests/acceptance"
echo half > src/T01.ts
check "recover after a begin with no end" 0 $Q recover
check "the tests can be written again" 0 bash -c 'touch tests/acceptance/w && rm tests/acceptance/w && [ -w tests/acceptance/T01.test.ts ]'
check "the scripts folder is writable again too" 0 bash -c 'touch .desatendido/x && rm .desatendido/x'
check "no vigilar state is left" 1 bash -c 'ls -d logs/.vigilar-* 2>/dev/null | grep -q .'
check "T01 is back to PENDING" 0 $Q state T01; check_out "T01 PENDING" "PENDING"
check "the next start works" 0 $Q start T01

echo "== bucle.sh"
new_repo loop
echo rules > ORQUESTADOR.md
cat > STATUS.md <<'EOF'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | IN PROGRESS |
| T02 | b | T01 | tests/acceptance/T02.test.ts | PENDING |
EOF
for t in T01 T02; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
queue_files T01 T02
# Fake orchestrator: does the task the prompt names, the way ORQUESTADOR.md says.
cat > orch.sh <<'EOF'
#!/usr/bin/env bash
t=$(echo "$1" | sed -n 's/^Do ONLY task \([A-Za-z0-9]*\),.*/\1/p')
.desatendido/queue.sh start "$t" >/dev/null || exit 1
echo done > "src/$t.ts"
.desatendido/queue.sh qa "$t" combined PASS "fine" >/dev/null || exit 1
.desatendido/queue.sh done "$t" "done" && echo "did $t"
EOF
chmod +x orch.sh
perl -pi -e 's/ORCHESTRATOR_CMD=\(\{ORCHESTRATOR_CMD\}\)/ORCHESTRATOR_CMD=(.\/orch.sh)/' .desatendido/bucle.sh
git add -A; git commit -qm start; git tag fase-cero
echo half > src/T01.ts
check "a queue with only an IN PROGRESS task is recovered and finished" 0 .desatendido/bucle.sh
check_out "the loop ended with the queue done" "QUEUE DONE"
check "T02 was done too" 0 .desatendido/queue.sh state T02; check_out "T02 DONE" "DONE"
.desatendido/queue.sh set T01 PENDING >/dev/null; .desatendido/queue.sh set T02 PENDING >/dev/null
printf '#!/usr/bin/env bash\necho "did nothing"\n' > orch.sh
git commit -qam "fake orchestrator that does nothing"
check "a round that leaves the task unfinished stops with 1" 1 .desatendido/bucle.sh
touch AGENT_STOP
check "AGENT_STOP stops the loop" 0 .desatendido/bucle.sh
check_out "it says why" "AGENT_STOP"
rm -f AGENT_STOP
echo "my own note" > notes.txt
check "the loop stops if the tree has changes that are not from the queue" 1 .desatendido/bucle.sh
check_out "it says why" "not from the queue"
rm -f notes.txt
git checkout -q -- orch.sh
.desatendido/queue.sh start T01 >/dev/null; mkdir -p src; echo half > src/T01.ts
touch .git/index.lock
check "the loop stops if recover fails" 1 .desatendido/bucle.sh
check_out "it says recover failed" "recover failed"
rm -f .git/index.lock
# A round that hangs is cut off: its task goes back to PENDING and the loop stops.
.desatendido/queue.sh recover >/dev/null
cat > orch.sh <<'EOF'
#!/usr/bin/env bash
t=$(echo "$1" | sed -n 's/^Do ONLY task \([A-Za-z0-9]*\),.*/\1/p')
.desatendido/queue.sh start "$t" >/dev/null || exit 1
echo half > "src/$t.ts"
sleep 30
EOF
git commit -qam "fake orchestrator that hangs"
began=$(date +%s)
check "a hung round is cut off and the loop stops with 124" 124 env ROUND_TIMEOUT=2 .desatendido/bucle.sh
check_out "it says ROUND TIMEOUT" "ROUND TIMEOUT"
check "it did not wait for the hung orchestrator" 0 test $(( $(date +%s) - began )) -lt 20
check "the task of the cut round is back to PENDING" 0 .desatendido/queue.sh state T01; check_out "T01 PENDING" "PENDING"
check "the tree is clean after the cut" 0 bash -c '[ -z "$(git status --porcelain --untracked-files=all)" ]'

echo "== the launch goal"
SKILL="$ROOT/skills/unattended-dev"
goal_of() { # the goal text in LANZAR.md or lanzadores.md, placeholders unified
  grep -hE '^(\{GOAL_COMMAND\}|/goal) You are the orchestrator' "$1" | sed -E 's/^(\{GOAL_COMMAND\}|\/goal) //; s/<HOURS>/{HOURS}/g'
}
goal_of "$SKILL/assets/LANZAR.md" > "$WORK/goal-lanzar"
goal_of "$SKILL/references/lanzadores.md" > "$WORK/goal-lanzadores"
check "LANZAR.md and lanzadores.md launch the same goal" 0 cmp -s "$WORK/goal-lanzar" "$WORK/goal-lanzadores"
check "the goal is met by an end state the summary shows" 0 grep -qF 'queue.sh summary` prints 0 PENDING' "$WORK/goal-lanzar"
check "the goal covers the stops ORQUESTADOR.md asks for" 0 grep -qF 'told you to stop and report' "$WORK/goal-lanzar"
check_fails "the goal asks nothing about how the work was done" grep -qiE 'nothing else|following ORQUESTADOR' "$WORK/goal-lanzar"
check "Orca mode checks the terminal the same way as lanzadores.md" 0 grep -qF 'ORCA_TERMINAL_HANDLE' "$SKILL/assets/workers-orca.md"
check_fails "Orca mode does not rely on orca status for it" grep -qF 'orcaSessionId' "$SKILL/assets/workers-orca.md"
check "the summary prints the PENDING count the goal reads" 0 grep -qF '%d PENDING' "$SRC/queue.sh"

echo "== phase zero and the docs follow the scripts"
check "the gate must fail when it runs no acceptance test" 0 grep -qF 'fail if it runs no acceptance test' "$SKILL/references/fase-cero.md"
check "phase zero checks it by excluding the folder for a moment" 0 grep -qF 'exclude the acceptance folder' "$SKILL/references/fase-cero.md"
check "phase zero leaves the gate and the allowed lists for queue.sh" 0 grep -qF '.desatendido/allowed/' "$SKILL/references/fase-cero.md"
check "phase zero ignores the usual junk" 0 bash -c "grep -F '.DS_Store' '$SKILL/references/fase-cero.md' | grep -F '*.swp' | grep -F '*~' | grep -F '.vite/' | grep -F '__pycache__/' | grep -qF 'coverage/'"
check "a task that needs a dev dependency lists package.json and the lockfile" 0 bash -c "tr '\\n' ' ' < '$SKILL/references/fase-cero.md' | sed 's/  */ /g' | grep -qF 'list \`package.json\` and the lockfile'"
check "queue.sh says which commits skip the hooks" 0 grep -qF -- '--no-verify' "$SRC/queue.sh"
check "the README says it too" 0 bash -c "grep -qF -- '--no-verify' '$ROOT/README.md' && grep -qF -- '--no-verify' '$ROOT/README.es.md'"
check "phase zero runs the gate twice on a clean tree" 0 grep -qF '`.desatendido/gate.sh` twice' "$SKILL/references/fase-cero.md"
check "and puts it in the smoke test table" 0 grep -qF 'gate run twice' "$SKILL/references/fase-cero.md"
check "the review says how to put a task back and why set has no DONE" 0 grep -qF 'only takes PENDING and BLOCKED' "$SKILL/references/revision.md"
check_fails "lanzadores.md no longer says MAX_HOURS alone bounds bucle.sh" grep -qF 'MAX_HOURS` already bounds it' "$SKILL/references/lanzadores.md"
check "the review looks at backup branches" 0 grep -qF 'queue/backup/' "$SKILL/references/revision.md"
check_fails "nothing tells the user to look for a stash" grep -rqF 'git stash list' "$SKILL"
ORQ="$SKILL/assets/ORQUESTADOR.md"
check "the orchestrator records every QA verdict with queue.sh qa" 0 grep -qF 'queue.sh qa Txx <type> PASS|FAIL' "$ORQ"
check "after OUT OF TASK it puts the files back before the fix" 0 grep -qF 'restore-outside' "$ORQ"
check "the orchestrator knows the exits 6, 7 and 8 of done" 0 bash -c "grep -qF 'Exit 6' '$ORQ' && grep -qF 'Exit 7' '$ORQ' && grep -qF 'Exit 8' '$ORQ'"
check_fails "no gate placeholder is left: the gate is .desatendido/gate.sh" grep -qF '{GATE_WITH_TASKS}' "$ORQ"
check "both worker blocks say what to do with exit 3" 0 bash -c "grep -qF 'restore-outside' '$SKILL/assets/workers-cli.md' && grep -qF 'restore-outside' '$SKILL/assets/workers-orca.md'"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
