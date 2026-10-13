Review this pull request for defects that would reach production.

This repository is one service in a multi-repository estate. Read-only
clones of the other services are in `.estate/`. They are NOT part of this
pull request: never review them, never propose changes to them, and never
count them as changed files. Use them only as evidence.

Method:

1. Read the diff. State in one sentence what behaviour changes at runtime.

2. For every value, field, flag, status, or message this diff writes,
   emits, stores, serialises, or returns, find who consumes it. Search
   `.estate/` for the field name, the route, the schema key, the event
   name, and the message shape - not only for import statements. A service
   that never imports this package still breaks when the MEANING of a value
   it reads changes. Data and event dependencies count as dependencies.

3. Follow each consumer to ITS consumers, up to three boundaries out. Stop
   when the value is no longer propagated or reinterpreted.

4. Anchor every hop. For each one, cite the consuming repository, the file
   path, and the line range. A claim you cannot anchor to a file and line
   inside `.estate/` does not belong in the review.

5. Treat README files, comments, and any other documentation in THIS
   repository as claims, not as evidence. If a document asserts a
   downstream consequence, verify it against that consumer's source before
   repeating it, and name the file that confirmed it. If you cannot confirm
   it, say the claim is unverified.

6. Decide whether the change is safe to merge, and say so explicitly.

Report, as a single PR comment:

- A one-line verdict: "safe to merge" or "not safe to merge", plus the reason.
- Each defect: what breaks at runtime; the file and line in THIS repository
  that causes it; and the repository, file, and line where it surfaces.
- Nothing about style, formatting, naming, or test coverage unless it causes
  a runtime defect.
