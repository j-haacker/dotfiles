---
name: validate-fresh-context
description: Prevents actions based on expired or mismatched context by classifying state, binding fresh evidence to the target, and rechecking action preconditions. Use when acting on information observed earlier, resuming work, or making a consequential decision or mutation whose target or preconditions could have changed.
---

# Validate Fresh Context

## Quick start

Treat earlier observations as evidence, not current state.

Before an action that depends on mutable information:

1. Identify the action’s preconditions.
2. Recheck the mutable ones immediately before acting.
3. Confirm that the evidence identifies the intended target and scope.
4. Act only when the fresh state satisfies those preconditions.

## State classes

| Class | Examples | Default handling |
|---|---|---|
| Immutable | Content hash, committed Git object, published version | Reuse if identity is certain |
| Locally mutable | Working tree, config, output directory | Recheck before dependent work |
| Externally mutable | Process, lock, service, job, remote branch, capacity | Recheck immediately before action |
| Human mutable | Preference, approval, priority, intended target | Prefer the latest user instruction |

When uncertain, treat state as mutable.

## Fresh-evidence workflow

For each mutable precondition, collect evidence that binds:

- **Identity:** exact path, PID, branch, URL, job ID, account, or resource
- **State:** existence, contents, status, ownership, or configuration
- **Time:** observed immediately before the action
- **Scope:** repository, directory, host, environment, account, or service

Compare that evidence with the intended action. Do not substitute a similar target, an earlier observation, or an inferred continuation.

## Revalidation triggers

Revalidate when:

- a tool call, user, agent, or external system could have changed state
- a command ran long enough for state to plausibly change
- work resumes after interruption, compaction, or a user correction
- changing branch, worktree, directory, host, environment, account, or service
- acting on an identifier obtained earlier in the conversation
- performing a destructive, irreversible, external, expensive, or workflow-altering action
- fresh behavior conflicts with earlier observations

## Action levels

**Read or explain:** Earlier context may be used, but identify uncertainty.

**Plan or recommend:** Recheck inputs that materially affect the conclusion.

**Mutate:** Recheck every mutable precondition immediately before the mutation.

**Destructive or externally visible action:** Report the fresh target identity and proposed action. Obtain confirmation if that action is not already authorized.

## Minimum record

```text
Target: <exact identity>
Scope: <repository, directory, host, account, or environment>
Observed now: <relevant current state>
Evidence: <command, query, hash, status, or metadata>
Action enabled: <specific action>
```

## Examples

Before a Git commit, recheck the branch, `HEAD`, staged paths, and working tree.

Before stopping a process, recheck its PID, start time, full command, parent/cgroup, working directory, and scope.

Before unlocking Snakemake, recheck active workflow processes, their scopes and working directories, then verify the lock has no current owner.

Before deployment, recheck the selected environment, revision, target account, and service health.

## Conflicting evidence

When fresh evidence conflicts with earlier context:

1. Stop relying on the earlier observation.
2. Explain the conflict and its consequence.
3. Rebuild the plan from fresh state.
4. Do not act until the target and preconditions are unambiguous.