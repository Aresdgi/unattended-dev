# STATUS

<!-- unattended-dev v8.2. Keep the table format: queue.sh reads and writes it. Test is the path of the task's acceptance test (or none). -->

States: PENDING, IN PROGRESS, DONE, BLOCKED.

## Queue

| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | {title} | none | {tests/acceptance/T01 test} | PENDING |

## Outside the queue

Pending decisions and risky tasks that will be done supervised.

- {task or decision}: {reason}

## Log

One line per task: date, task, state, attempts, QA and one sentence.
