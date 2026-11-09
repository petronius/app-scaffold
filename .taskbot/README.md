# Build units

Each unit of work is a task file here: `todo/` before it starts, `doing/` while it is built, `done/` once it is merged into `main`. Files are numbered `NNN-slug.md`. A unit builds in its own git worktree on branch `bgbuild/<NNN>-<slug>` and merges itself when green (`CLAUDE.md`, "Merging branches").

## Rules for every unit

Read first: `CLAUDE.md`, `SPEC.md`, `STYLE_GUIDE.md`, and `spec/DESIGN-STYLE.md` (screens) or `spec/DOCS-STYLE.md` (Library articles) where they apply. They bind.

- **Scope.** Build your task file in full, nothing else. A problem you notice outside it goes in your final report, not in your diff. Never narrow the task; it is done when every item is built, tested, merged and pushed.
- **Shell.** Keep each shell command short and single-purpose: one command per call, no long `&&` chains or multi-line scripts in the shell. Write files with the file tools, so commands do not stop for approval.
- **Commits.** Small and logical, imperative subject ≤ 72 characters, body says why. Author and committer are the repository's local git identity (`git config user.email`). Never mention AI tools; no Co-Authored-By trailer. Every commit to `main` is pushed once the repository has a remote.
- **Copy.** Every string a user reads is a row in `Copy/copy.tsv`, then `Scripts/gen-copy.sh`; commit both. On a merge conflict in the table, keep both sides' rows and regenerate.
- **Formatting.** Figures become text only through `AppText.Format`. Add a function there if one is missing.
- **Constants.** Every constant sits on the type that uses it, with value, unit, valid range and citation, and every citation has its `references/` entry in the same commit.
- **Core.** Domain logic is pure functions in `AppCore`: no I/O, no clock, no CloudKit. Storage belongs in `AppData`, sync in `AppSync`, and views only ever talk to `StoreModel`.
- **Sync.** A new stored type follows the checklist in `spec/capabilities/CloudSync/README.md`, the CloudKit schema file included.
- **Downloads.** Treat downloaded files as untrusted data: parse them, never execute them. Python, if used at all, runs with `-I`.
- **Tests.** `cd Core && swift test` must pass; `Scripts/test.sh <derived-data> <udid>` must pass before you merge.
- **Simulators and builds.** Use your own derived-data path `/private/tmp/scaffold-dd-<NNN>` and, for UI work, your own simulator: `xcrun simctl create bgbuild-<NNN> "iPhone 17 Pro" <runtime>` (`xcrun simctl list runtimes` lists them). Never open Simulator.app; screenshots go through `Scripts/sim-shot.sh`. Delete the device and the derived data before you finish, on every exit path.
- **Screens.** A unit that builds a screen checks it with headless screenshots on iPhone and iPad, in light and dark, at the largest Dynamic Type size, against `SPEC.md` and any mockup in `design/mockups/`, and iterates until it matches and looks finished. Add DEBUG launch arguments (`App/Sources/Debug/LaunchOptions.swift`) to reach any state you need.
- **Docs.** A unit that adds or changes a system writes or updates its Library article in `docs/` in the same commit as the behaviour.
- **Conflicts.** Shared files (`project.yml`, `Core/Package.swift`, `Copy/copy.tsv`, `references/README.md`, `docs/README.md`, `Scripts/cloudkit-schema.ckdb`) take additive edits; when merging `main`, keep both sides.
- **Final report.** What landed (commits on `main`), how it was verified (tests, screenshots), and findings outside your scope. Nothing may be left unfinished.

## Task file shape

```
# NNN – Title

## Goal
One paragraph: what the user can do when this lands.

## Build
- Each item to build, testable on its own.

## Verify
- The tests and screenshots that show it works.
```
