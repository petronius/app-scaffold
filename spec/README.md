# Implementation spec

Implementation notes on the app as built, one page per part: where the code lives, what it reads and writes, the rules it follows, and the edge cases it handles. Each page describes the code as it is now. What the user reads about a feature is the Library in `docs/`; what the app is for is `SPEC.md`; deferred work is `FUTURE.md` or GitHub issues.

Conventions:

- **No constant values.** Domain numbers, their bounds and citations live on the type that uses them. A page names the constant and leaves the value to the code.
- **No copy.** Strings the user reads live in `Copy/copy.tsv`; a page names a key or an area (`Copy.sync`) where it needs to, and quotes a string only when the logic turns on it.
- **No line numbers.** Name the file and the type or function.

Ownership, so nothing is written twice:

- **pages/** own screen layout, section order, navigation and page-level states; they link to components for row and card internals.
- **components/** own the reusable rows, cards, lists and detail screens.
- **capabilities/** own integrations and stored features with their own lifecycle: the store and iCloud, widgets, the watch, any system framework the app reads.
- **core/** owns the pure domain code in `AppCore`.

Create a folder when its first page is written.

[DESIGN-STYLE.md](DESIGN-STYLE.md) is how the app's screens look and move.

[DOCS-STYLE.md](DOCS-STYLE.md) is how the Library in `docs/` is written and organised.

## Capabilities

- [CloudSync](capabilities/CloudSync/README.md): the local store, iCloud sync through CKSyncEngine, and the checklist for syncing a new type.
