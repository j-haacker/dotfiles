---
name: minimal-change
description: >
  Use when implementing or reviewing code changes where minimizing
  architectural complexity, new abstractions, files, dependencies,
  indirection, and maintenance burden is important.
---

# Minimal Change

Before implementation:

1. Identify the smallest existing location where the change can be made.
2. Search for existing functionality that can be reused.
3. Prefer modification or deletion over adding parallel machinery.
4. Do not add a new abstraction for a single current use case.
5. Do not add a new file unless it creates a clear separation of responsibility.

After implementation:

1. Inspect the complete diff.
2. Identify every new file, class, function, dependency, and configuration layer.
3. Remove anything not necessary for the requested behavior.
4. Check whether the same behavior can be expressed with fewer layers.
5. Report any remaining increase in architectural complexity and why it is needed.