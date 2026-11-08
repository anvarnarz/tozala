## Docs format (read by my project dashboard — keep exact)

For notable changes and releases, update VERSION, CHANGELOG.md, TODOS.md
and README.md before calling the task complete. Routine commits (typo,
one-line fix, internal rename) need no CHANGELOG entry or version bump.

- VERSION: semver. Patch for fixes, minor for features, major for breaking.
- CHANGELOG.md: newest entry first. Heading:
  `## YYYY-MM-DD — Short description (X.Y.Z)`
  Real em dash (U+2014). X.Y.Z is the VERSION value after the bump, in
  parentheses, no "v". One heading per release, even several on the same
  day. Keep any `---` separators between entries. Subsections only
  ### Added, ### Changed, ### Fixed, ### Removed (omit empty ones), one
  line per item. The top heading's (X.Y.Z) must equal VERSION.
- TODOS.md layout, in this order:
  ## Now  — 1–3 lines of prose: what's in progress, what's half done,
             next step. Never empty; if idle write
             "Idle — last finished: <item>".
  ## Open — unchecked `- [ ] item` lines only, no nesting.
  ## <any extra sections, e.g. "Waiting on client"> — optional, between
             Open and Done; unchecked lines only. Unchecked items in them
             count as open.
  ## Done — last. `- [x] item (X.Y.Z)`, no "v".
- Before ending any session where work was done, update ## Now in
  TODOS.md, even if nothing else changed.
- README.md must match the current state, not future plans.
- If any of these files don't exist, create them on the first notable change.
