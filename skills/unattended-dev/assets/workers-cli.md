## Workers: CLI

<!-- unattended-dev v8.8. Phase zero pastes this block into ORQUESTADOR.md, in place of {WORKERS}, when the worker launcher is CLI. -->

Each worker is one command that `lanzar-worker.sh` runs, waits for and
ends. If a flag fails, check its `--help`.

```zsh
.desatendido/lanzar-worker.sh <role> <Txx> --allowed "<task files>" --readonly "{TESTS_FOLDER}" -- <command> "<order>"
```

- Implementer and design: `--allowed` with the task's files.
- QA: no `--allowed` (any change is OUT OF TASK) and its tool's read-only
  mode.
- It prints the last 30 lines of the worker; that is all you read.
- A worker **failed** if `lanzar-worker.sh` exits with anything other than
  0: 3 out of task, 124 timeout (20 minutes), 128+N killed, or the
  worker's own error code. With 3, `.desatendido/queue.sh restore-outside
  <Txx>` before the fix.
- While it runs, `.desatendido/` is read-only too, so a worker cannot
  change the scripts that judge it.
- Nothing to close: each worker ends with its command.
