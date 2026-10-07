# PLAN

<!-- unattended-dev v8.3. Does not change during the queue; the state lives in STATUS.md. -->

Gate: `{GATE}`
Acceptance tests: `{TESTS_FOLDER}`

## T01: {title}

- **Goal:** {one or two sentences; points to the section of docs/SPEC.md}
- **Signature or screen:** `{exact signature, or route and states}`
- **Files it may touch:** `{file}` (never the tests: `queue.sh start` removes the skip and they stay read-only)
- **Test:** `{path of the T01 acceptance test}`
- **Done by:** implements | design
- **Depends on:** none

| Case | Input or situation | Expected result |
| --- | --- | --- |
| valid | | |
| invalid ({error}) | | |

At least 6 valid and 6 invalid, with one invalid per possible error.
