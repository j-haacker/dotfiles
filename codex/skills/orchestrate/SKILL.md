---
name: orchestrate
description: Coordinate independent, substantial workstreams through focused subagents. Use when a task has at least two separable outcomes that can progress in parallel; handle tightly coupled or sequential work directly.
---

# Orchestrate

Keep responsibility for the task: remain available to the user, retain approvals, integrate the result, and verify the completed work.

Use this skill only after identifying at least two substantial, independent workstreams. Work directly when the task is small, sequential, or requires the same files or subsystem to change together.

1. Split the work into outcomes with clear boundaries. Assign each worker an exclusive subsystem or set of files, its expected result, and the checks it should run.
2. Use narrow, read-only scouts to resolve independent unknowns early. Give implementation work only to workers with exclusive ownership.
3. Tell every worker not to delegate further. Have workers report their findings, changed files, validation, and unresolved issues.
4. Review the results, resolve cross-cutting decisions, integrate the changes, and run final verification before reporting back to the user.
