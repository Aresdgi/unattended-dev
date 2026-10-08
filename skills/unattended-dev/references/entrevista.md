# Interview

Goal: a SPEC that a cheap worker can follow without interpreting, and
everything else you will need from the user, asked now. After the
confirmation nobody answers questions: phase zero and the queue run
alone. Whatever the user does not know or does not care about, you decide
and mark "(default)".

Run `date` before the first question: that time goes in the Log as the
start of the preparation.

## What has to be clear

- **What and for whom**: problem, user, the minimum that has to work and
  at least 3 things out of scope.
- **Shape**: type (library, CLI, web, app, API...), stack (if there is no
  preference, the simplest one that fits what they already use) and repo.
- **Data**: where it comes from and whether there is a source of truth
  (regulation, website, known algorithm, design). Credentials never go
  into the queue.
- **Limits of every input**: minimum, maximum and units of each value
  the user can enter, and what happens outside them (a named error). Ask
  it even if it seems obvious: "greater than 0" lets through values so
  small or so large that the result breaks (infinite, overflow, absurd).
  Propose sensible limits and mark them "(default)" if the user does not
  care.
- **Edge cases** (what an adversarial review of the SPEC would find, asked
  here instead of in a separate call): empty values, zeros, extremes that
  make a result infinite, huge or negative, overflow, rounding, and inputs
  that contradict each other. Each one with a proposed rule, recommended
  first.
- **Verification**: tests, screenshots, comparing with the source. With
  a UI: the states of each screen (empty, error, result, disabled), sizes
  and minimum accessibility. They become Playwright assertions.
- **UI behaviours** a worker would have to decide alone (what is hidden,
  what is disabled, where the result appears).
- **Limits**: what is not touched and forbidden dependencies.
- **How it runs**: the team (`references/equipo.md`), the autonomy, the
  time limit and the launch (`references/lanzadores.md`).

## How to ask

- At most 4 questions per round, with options and your recommendation
  first.
- First round: what, MVP, type and stack. As soon as you can count the
  tasks, check the size: with 3 or fewer, say in one line that a normal
  session does it sooner (with `/goal` if the tool has it) and offer it
  as an option.
- Second round: limits and edge cases, data and verification, and in one
  question the team, the autonomy and the launch ("the usual" if it is
  saved; then only the hours). A third round only if it changes the plan,
  and only in full mode.
- Without a usual team, its questions (`references/equipo.md`) are one
  extra round, only that first time on the machine.

## Signs that something is missing

- You cannot write a valid and an invalid case for each function, or the
  states of each screen.
- You do not know which files each task would touch.
- A worker would have to choose between two reasonable behaviours.

If any of these happens, ask before the confirmation.

## Confirmation

Before it, check what would make phase zero stop later, so the user can
fix it now (`references/lanzadores.md`, "Before the confirmation").

Then one summary, short:

- What it does and the limits and rules decided, marking the defaults.
- The tasks: title, files, risk (low or high, see `assets/PLAN.md`) and
  dependencies. Two tasks never check the same output if a later one will
  change it (see `references/fase-cero.md`).
- Mode, team, autonomy, time limit and launch, and the preparation budget
  with the steps that are already recorded for this machine.
- Whatever will need the user's OK later, asked now: installing tmux,
  accepting "Trust this folder?" for the orchestrator, creating the repo
  and pushing the phase zero commit.

End with "shall I set it up and leave it running?". It is the last
question: with a yes, phase zero and the launch run without stopping, and
the user can go.
