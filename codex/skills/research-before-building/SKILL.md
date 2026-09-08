---
name: research-before-building
description: Checks for existing libraries before custom implementation to reduce owned code and maintenance. Use when about to implement a reusable algorithm, parser, utility, protocol, or infrastructure feature that an established library might already provide.
---

# Research Before Building

Before writing a custom implementation of a reusable concept, do a quick web search for existing solutions. Prefer a suitable library when it meaningfully reduces the codebase's implementation and maintenance burden and benefits from upstream testing and expertise.

## Workflow

1. **Identify the concept and constraints.** Name the general problem behind the feature. Check existing code, dependencies, and standard-library or framework capabilities first. If these already satisfy the need, reuse them and stop the search. Keep ordinary application-specific glue and trivial changes outside this workflow.

2. **Search before implementing.** Use the concept's common names plus the project's language or ecosystem. Start with one or two focused queries; inspect at most two or three plausible candidates. Aim for a few minutes, and stop when there is enough evidence to choose. Search generic technical requirements, keeping private project details out of queries.

3. **Check whether reuse actually helps.** Read the strongest candidate's official documentation and repository. Briefly assess:
   - **Fit:** Required behavior, edge cases, runtime and version compatibility, and relevant performance constraints.
   - **Quality:** Evidence of tests, documentation, maintenance, and handling of relevant bugs. Popularity alone does not establish quality; a stable library need not release frequently.
   - **Cost:** License compatibility, dependency footprint, integration code, and ongoing upgrade burden compared with the custom code it replaces.

   If one uncertainty could change the decision, resolve it with a focused documentation check or a small disposable experiment. Expand the investigation only when the task's risk or complexity warrants it.

4. **Choose and continue the task.** Prefer existing project or platform functionality, then a well-fitting library. Write a small custom implementation when the candidates fail concrete requirements or add more burden than they remove. Respect explicit dependency constraints and the user's purpose, including learning exercises. Adopt a library through the project's existing dependency workflow, with only the integration code needed for the current task.

5. **Keep local verification focused.** Let the library own its general-purpose implementation and upstream tests. Verify the application's integration and required behavior; upstream quality assurance does not prove the application uses the library correctly.

## Decision note

Briefly report the concept searched, the strongest candidate with a source link, and the decisive reason for reuse or custom code. Include a material tradeoff or unresolved uncertainty when relevant. Keep this in the normal task update or final response rather than adding a separate report file.

If browsing is unavailable or disallowed, say the search was not performed, use available local evidence, and continue within the task's constraints. Describe an unsuccessful search as “no suitable candidate found in this quick search,” rather than claiming none exists.

## Examples

- **CSV import:** Before writing delimiter and quote handling, search for a CSV parser in the project's ecosystem. Check streaming and dialect support, then keep only application-specific field mapping and validation locally.
- **Retry behavior:** Before implementing backoff, check the existing client and then search for a compatible retry library. Verify cancellation, retry limits, and which operations may safely be retried.
- **Small domain rule:** A short calculation specific to the application's business rules can remain local. There is no reusable technical concept that warrants a library search.
