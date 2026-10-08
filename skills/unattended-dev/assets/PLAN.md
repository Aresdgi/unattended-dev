# PLAN

<!-- unattended-dev v8.9. Does not change during the queue; the state lives in STATUS.md. -->

Gate: `.desatendido/gate.sh`
Acceptance tests: `{TESTS_FOLDER}`

## T01: {title}

- **Goal:** {one or two sentences; points to the section of docs/SPEC.md}
- **Signature or screen:** `{exact signature, or route and states}`
- **Files it may touch:** `{file}` (never the tests: `queue.sh start` removes the skip and they stay read-only). Phase zero copies this list to `.desatendido/allowed/T01`
- **Test:** `{path of the T01 acceptance test}`. It checks only what this task does: never the whole output of the program if a later task will change it
- **Done by:** implements | design
- **Risk:** low | high. Low: one `combined` QA review. High (money, data, security, delicate algorithm or a contract other tasks use): `fidelity` and `technical` apart
- **QA:** {combined | fidelity, technical}{, design if it touches the UI}. Phase zero writes it in `.desatendido/qa/T01`
- **Depends on:** none

| Case | Input or situation | Expected result |
| --- | --- | --- |
| valid | | |
| invalid ({error}) | | |

Cases by what the task has, not a fixed number. With inputs: one invalid
case per possible error, the limits of each input (minimum, maximum,
empty, zero) and one valid case per SPEC rule. Without inputs (UI,
integration): one case per state it has to show (empty, error, result,
disabled...).
