# PLAN

<!-- unattended-dev v8.8. Does not change during the queue; the state lives in STATUS.md. -->

Gate: `.desatendido/gate.sh`
Acceptance tests: `{TESTS_FOLDER}`

## T01: {title}

- **Goal:** {one or two sentences; points to the section of docs/SPEC.md}
- **Signature or screen:** `{exact signature, or route and states}`
- **Files it may touch:** `{file}` (never the tests: `queue.sh start` removes the skip and they stay read-only). Phase zero copies this list to `.desatendido/allowed/T01`
- **Test:** `{path of the T01 acceptance test}`
- **Done by:** implements | design
- **QA:** fidelity, technical{, design if it touches the UI: phase zero writes it in `.desatendido/qa/T01`}
- **Depends on:** none

| Case | Input or situation | Expected result |
| --- | --- | --- |
| valid | | |
| invalid ({error}) | | |

At least 6 valid and 6 invalid, with one invalid per possible error.
