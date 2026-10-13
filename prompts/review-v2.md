Review this pull request for defects that would reach production.

This repository is one service in a multi-repository estate. Read-only
clones of the other services are in `.estate/`. They are NOT part of this
pull request: never review them, never propose changes to them, and never
count them as changed files. Use them only as evidence.

Method:

1. Read the diff. State in one sentence what behaviour changes at runtime.
   Then check the diff itself for defects that need no other repository:
   state shared between callers or goroutines that is now written (fields
   set on a shared struct, a config, a cache, a pointer receiver); missing
   locks and data races; goroutines, channels, or resources that are never
   released; changed defaults, units, or rounding; errors that are dropped,
   replaced, or wrapped so callers can no longer tell them apart; boundary
   and off-by-one conditions; and whether every early return keeps the
   invariants the old code kept.

2. For every value, field, flag, status, or message this diff writes,
   emits, stores, serialises, or returns, find who consumes it. Search
   `.estate/` for the field name, the route, the schema key, the event
   name, and the message shape - not only for import statements. A service
   that never imports this package still breaks when the MEANING of a value
   it reads changes. Data and event dependencies count as dependencies.

3. Follow each consumer to ITS consumers, up to three boundaries out. Stop
   when the value is no longer propagated or reinterpreted.

4. Anchor every claim. A defect inside this pull request is anchored by its
   file and line in THIS repository and needs no `.estate/` citation. For a
   cross-repository hop, cite the consuming repository, the file path, and
   the line range. A cross-repository claim you cannot anchor does not
   belong in the review. If `.estate/` code looks like a different version
   from this pull request, trust this pull request's code.

5. Treat README files, comments, and any other documentation in THIS
   repository as claims, not as evidence. If a document asserts a
   downstream consequence, verify it against that consumer's source before
   repeating it, and name the file that confirmed it. If you cannot confirm
   it, say the claim is unverified.

6. Before you call any part of the change correct, try to break it: name a
   concrete input, call order, or reused object that would make it misbehave.
   Check where the diff normalises, clamps, validates, or resets a value, and
   whether every earlier use (a cache or map key, a lookup, a comparison, an
   early return) sees the raw value instead. Check objects that are pooled or
   reused between calls for fields that are not reset. Check that a filter,
   limit, or cutoff keeps exactly what the old code or the description says.
   Only write "looks correct" for code you tried to break and could not.

7. A defect in this pull request is reported even when nothing in `.estate/`
   calls the changed code today. Exported or new APIs will be called later.
   Having no current consumer lowers severity at most, never hides a defect.
   Redundant work, unbounded growth, and wrong results are defects. Style is not.

8. Decide whether the change is safe to merge, and say so explicitly. Any
   defect that produces wrong results, lost data, leaks, races, or unbounded
   growth makes it "not safe to merge" until fixed.

Report, as a single PR comment:

- A one-line verdict: "safe to merge" or "not safe to merge", plus the reason.
- Each defect, most severe first: what breaks at runtime; the file and line in
  THIS repository that causes it; where it surfaces in another repository, or
  "no consumer yet"; and the fix.
- Nothing about style, formatting, naming, or test coverage unless it causes
  a runtime defect.
