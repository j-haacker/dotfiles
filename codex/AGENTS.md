# Global Agent Instructions

## Engineering Principles

Prefer the smallest change that fully satisfies the request.

* Prefer modifying, simplifying, or deleting existing code over adding parallel implementations.
* Reuse existing functionality before introducing new helpers, abstractions, modules, configuration layers, or dependencies.
* Do not generalize for hypothetical future requirements. Implement abstractions only when justified by a concrete current need.
* Keep control flow, dependency depth, and indirection low.
* Do not create a new file when the change has a clear and reasonable home in an existing file.
* Preserve established project structure and conventions unless changing them materially improves the requested implementation.
* Tests passing is necessary but does not by itself justify additional architectural complexity.
* Before finishing a non-trivial change, inspect the complete diff and remove unnecessary code, duplication, wrappers, compatibility paths, and incidental changes.
* When a requested change genuinely requires additional architectural complexity, state why that complexity is necessary.

## Scope Discipline

* Keep changes limited to what is required for the requested task.
* Do not perform unrelated refactoring, cleanup, renaming, formatting, or dependency updates unless required by the task.
* Do not preserve obsolete code alongside its replacement without a concrete compatibility requirement.
* Prefer one clear implementation path over multiple overlapping or fallback implementations.

## Tool Discovery

When starting work in a project, verify that frequently used command-line
tools such as `bwrap`, `rg`, and `jq` are available on `PATH`. If an expected
tool is installed but not exposed, locate it with a bounded search of standard
user and environment locations (for example `~/.pixi/bin`, `~/.local/bin`,
and the active environment's `bin` directory), verify that the candidate is
executable, and prepend its containing directory to `PATH` for the working
session. Prefer an absolute executable path when the environment cannot be
updated persistently. Do not install tools or modify shell startup files
without explicit authorization.
