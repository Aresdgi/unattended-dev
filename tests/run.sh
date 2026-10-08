#!/usr/bin/env bash
# Tests for the scripts in skills/unattended-dev/assets/desatendido.
# Usage: bash tests/run.sh   (Linux and macOS; needs git, perl, awk, sed)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/skills/unattended-dev/assets/desatendido"
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
git add -A; git commit -qm start
Q=".desatendido/queue.sh"
check "next gives the first ready task" 0 $Q next; check_out "it is T01" "T01"
check "start marks IN PROGRESS and removes the skip" 0 $Q start T01
check "the started task's test has no skip" 1 grep -q "skip" tests/acceptance/T01.test.ts
check "state reads IN PROGRESS" 0 $Q state T01; check_out "state is IN PROGRESS" "IN PROGRESS"
check "tests lists the started task" 0 $Q tests; check_out "T01 test listed" "tests/acceptance/T01.test.ts"
check "next skips a task whose dependency is not DONE" 0 $Q next; check_out "it is T03" "T03"
check "set rejects an invalid state" 3 $Q set T01 FINISHED
check "set DONE works" 0 $Q set T01 DONE
check "next now gives T02" 0 $Q next; check_out "it is T02" "T02"
$Q set T02 BLOCKED >/dev/null; $Q set T03 DONE >/dev/null
check "queue finished returns 1" 1 $Q next
$Q set T02 PENDING >/dev/null; $Q set T01 BLOCKED >/dev/null
check "a task depending on a BLOCKED one becomes BLOCKED" 1 $Q next
check "T02 is now BLOCKED" 0 $Q state T02; check_out "T02 BLOCKED" "BLOCKED"
$Q set T01 "IN PROGRESS" >/dev/null; echo half > src/half.ts
check "recover stashes and resets an IN PROGRESS task" 0 $Q recover
check_out "recover names the stash" "T01 interrupted"
check "after recover T01 is PENDING" 0 $Q state T01; check_out "T01 PENDING" "PENDING"
check "the half-done file is gone from the tree" 1 test -f src/half.ts
check "summary counts states" 0 $Q summary; check_out "summary line" "Progress:"

echo "== queue.sh: state survives stash and failures"
new_repo state
cat > STATUS.md <<'EOF2'
| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | a | none | tests/acceptance/T01.test.ts | PENDING |
| T02 | b | T01 | tests/acceptance/T02.test.ts | PENDING |
| T03 | c | T02 | tests/acceptance/T03.test.ts | PENDING |
EOF2
for t in T01 T02 T03; do printf "describe.skip('$t', () => {})\n" > tests/acceptance/$t.test.ts; done
git add -A; git commit -qm start
Q=".desatendido/queue.sh"
# Old template order: commit the work first, then mark DONE.
$Q start T01 >/dev/null; echo impl > src/T01.ts; git add -A; git commit -qm "T01: done"
check "set DONE after a manual commit" 0 $Q set T01 DONE
$Q start T02 >/dev/null; echo half > src/T02.ts
check "block stashes the task's work" 0 $Q block T02 "tests keep failing"
check "a blocked T02 does not bring T01 back to IN PROGRESS" 0 $Q state T01; check_out "T01 still DONE" "DONE"
check "T02 is BLOCKED" 0 $Q state T02; check_out "T02 BLOCKED" "BLOCKED"
check "the stash has T02's work" 0 bash -c 'git stash list | grep -q "T02 blocked"'
check "the tree is clean after block" 0 bash -c '[ -z "$(git status --porcelain)" ]'
$Q set T02 PENDING >/dev/null; $Q set T03 PENDING >/dev/null
# done is atomic: state and work in one commit.
$Q start T02 >/dev/null; echo impl > src/T02.ts
check "done commits state and work together" 0 $Q done T02 "implemented"
check "T02 is DONE in the last commit" 0 bash -c 'git show HEAD:STATUS.md | grep -q "| T02 | b | T01 | tests/acceptance/T02.test.ts | DONE |"'
check "the last commit has T02's work" 0 bash -c 'git show --name-only HEAD | grep -q src/T02.ts'
check "done refuses a task that is not IN PROGRESS" 3 $Q done T03 "nothing"
# Recover after DONE tasks keeps them DONE and the queue can go on.
$Q start T03 >/dev/null; echo half > src/T03.ts
check "recover after DONE tasks" 0 $Q recover
check "T01 and T02 stay DONE" 0 bash -c '[ "$('$Q' state T01)" = DONE ] && [ "$('$Q' state T02)" = DONE ]'
check "next gives T03 again, not a stuck queue" 0 $Q next; check_out "it is T03" "T03"
# A stash that cannot be made stops everything and marks nothing.
$Q start T03 >/dev/null; echo half > src/T03.ts
touch .git/index.lock
check "recover fails with 4 when git stash fails" 4 $Q recover
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
git add -A; git commit -qm start
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
mkdir -p src; echo impl > src/T01.ts
check "done writes the Log line in the same commit" 0 $Q done T01 "implemented"
check "the DONE line is in the committed STATUS.md" 0 bash -c 'git show HEAD:STATUS.md | grep -q "T01 DONE: implemented"'
$Q start T02 >/dev/null; mkdir -p src; echo half > src/T02.ts
check "recover writes the interruption in the Log" 0 $Q recover
check "the Log names the stash" 0 grep -q "T02 interrupted: back to PENDING" STATUS.md
check "fix needs the task IN PROGRESS" 3 $Q fix T02 "x"

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
# Fake orchestrator: does the task the prompt names, the way ORQUESTADOR.md says.
cat > orch.sh <<'EOF'
#!/usr/bin/env bash
t=$(echo "$1" | sed -n 's/^Do ONLY task \([A-Za-z0-9]*\),.*/\1/p')
.desatendido/queue.sh start "$t" >/dev/null || exit 1
echo done > "src/$t.ts"
.desatendido/guardia-tests.sh start tests/acceptance $(.desatendido/queue.sh tests) >/dev/null || exit 1
.desatendido/queue.sh done "$t" "done" && echo "did $t"
EOF
chmod +x orch.sh
perl -pi -e 's/ORCHESTRATOR_CMD=\(\{ORCHESTRATOR_CMD\}\)/ORCHESTRATOR_CMD=(.\/orch.sh)/' .desatendido/bucle.sh
git add -A; git commit -qm start; git tag start
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
.desatendido/queue.sh set T01 "IN PROGRESS" >/dev/null; mkdir -p src; echo half > src/T01.ts
touch .git/index.lock
check "the loop stops if recover fails" 1 .desatendido/bucle.sh
check_out "it says recover failed" "recover failed"
rm -f .git/index.lock

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

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
