# Interview

Goal: a SPEC that a cheap worker can follow without interpreting.
Whatever the user does not know or does not care about, you decide and
mark "(default)".

## What has to be clear

- **What and for whom**: problem, user, the minimum that has to work and
  at least 3 things out of scope.
- **Shape**: type (library, CLI, web, app, API...), stack (if there is no
  preference, the simplest one that fits what they already use) and repo.
- **Data**: where it comes from and whether there is a source of truth
  (regulation, website, known algorithm, design). Credentials never go
  into the queue.
- **Verification**: tests, screenshots, comparing with the source. With
  a UI: sizes, empty and error states, minimum accessibility.
- **UI behaviours** a worker would have to decide alone (what is hidden,
  what is disabled, where the result appears).
- **Limits**: what is not touched and forbidden dependencies.

## How to ask

- At most 4 questions per round, with options and your recommendation
  first.
- First round: what, MVP, type and stack. Second: data, verification and
  whatever is still open. A third one only if it changes the plan.
- In fast mode, try to close it in 2 rounds.

## Signs that something is missing

- You cannot write a valid and an invalid case for each function.
- You do not know which files each task would touch.
- A worker would have to choose between two reasonable behaviours.

If any of these happens, ask before going on.
