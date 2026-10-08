# STATUS

<!-- unattended-dev v8.9. Keep the table format: queue.sh reads and writes it. Test is the path of the task's acceptance test (or none). The Log is in docs/LOG.md, written by queue.sh. -->

States: PENDING, IN PROGRESS, DONE, BLOCKED.

## Queue

| Task | Title | Depends on | Test | State |
| --- | --- | --- | --- | --- |
| T01 | {title} | none | {tests/acceptance/T01 test} | PENDING |

## Outside the queue

Pending decisions and risky tasks that will be done supervised.

- {task or decision}: {reason}
