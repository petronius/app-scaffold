# Scaffold

<!-- Replace this paragraph with what the app is, in three sentences: what it does, for whom, and what it deliberately is not. -->
An app for iPhone, iPad and Apple Watch. Local-first: each device keeps the user's data in its own store and works without a connection; iCloud keeps the devices in step through the user's private CloudKit database. There is no server of our own. Read `SPEC.md` before making product-affecting changes.

## Scope discipline

Work ONLY on the current ask. Do not drift onto other changes of your own accord, even ones that look correct or related (a stray bug spotted in passing, a cleanup, a nearby inconsistency). Note such findings to Michael and let him decide; do not fold them into the current change. Unrelated edits bundled into a task make the diff harder to review and derail the thing actually asked for.

## Finish the task as given

A task is done when every part of it as Michael stated it is built, merged and pushed. Until then it is in progress, whatever the size.

- **Build the whole ask.** Never narrow it, drop a part, or stop after a "first batch" and present the rest as later work. If an issue or a message lists fifteen items, the task is fifteen items.
- **No amount of work is too much.** The size of a task is never a reason to cut it or to ask whether to go on. Work through it in order, one logical commit and PR at a time, and keep going until the list is empty.
- **Do not ask for input you can supply.** Sample data, captions, which example to draw, the order of batches, whether a small refactor is needed to get there: decide, state the decision in the PR, and build. Ask only when two readings of the ask would produce materially different work and neither is a clear default.
- **A question is not a stopping point.** If Michael asks a question mid-task, answer it and carry on with the task; do not wait for a second go-ahead that was already given.
- **Say "done" only when it is done.** Report what landed, and if anything at all is left, name it as unfinished work that continues now, never as a follow-up for someone else.

## Document map

- `SPEC.md`: the binding product spec: what the app does, on which devices, and the rules no feature may break. `FUTURE.md` holds features deliberately deferred.
- `STYLE_GUIDE.md`: the prose rules for all writing in the project, replies to Michael included.
- `spec/`: internal documents, never bundled into the app. `spec/README.md` is the index.
    - `spec/DESIGN-STYLE.md`: the rules every screen, widget and complication follows (HIG first, type, colour, surfaces, numbers, states, motion). Read it before designing or restyling a screen.
    - `spec/DOCS-STYLE.md`: how the Library articles are written and organised. Read it before adding or changing an article.
    - `spec/capabilities/`: one page per integration or stored feature with its own lifecycle, starting with `CloudSync/` (the store, the sync, and the checklist for syncing a new type).
- `docs/`: the Library, the user-facing manual bundled into the app and browsable on the Library tab. One article per system of the app, in section folders (`docs/{section}/{article}.md`), indexed by `docs/README.md`, which also orders the in-app list. Written for a reader who is not technical: process and logic, never code. When behaviour an article describes changes, the article changes in the same commit.
- `references/`: every paper, standard, algorithm reference and dataset the code, spec or Library cite or ship, one entry per source, indexed by `references/README.md`. **A citation or a bundled dataset added anywhere in the repository adds its entry here in the same commit**; a cited source with no entry is a missing file.
- `design/`: the icon source (`design/icon/`) and design mockups.
- `.taskbot/`: build units for parallel background work (`todo/`, `doing/`, `done/`); `.taskbot/README.md` holds the rules every unit follows.
- `HANDOFF.md`, when present: the context a session that ended mid-work leaves for the next. Read it first, and delete it once the work it describes has landed.

**Keep these current as part of the change that alters behaviour, not as a later cleanup: the commit that changes how the app works updates the document that describes it.**

**Every build carries its release notes, written from the commits.** Every commit subject is a Conventional Commit (Git practice, below). `Scripts/testflight.sh` tags each uploaded commit `build/<build number>` and, through `Scripts/release-notes.sh`, writes the build's article in the Library's Release notes section (`docs/release-notes/`) from the commits since the previous tag: each `feat` a line under New features, each `fix` a line under Fixes, and any other type one line, "Maintenance and performance improvements".

**Constants live in code, nowhere else.** Every domain constant and model parameter sits on the type that uses it, with its value, unit, valid range and citation. There is no separate constants document to keep in step, so a constant can never be changed in prose without changing the value.

## Git practice

- Small, logical commits: one coherent change per commit. Large commits need exceptional rationale (e.g. an atomic refactor) and should be rare.
- Every subject line is a Conventional Commit, `<type>: <summary>`, ≤ 72 characters in all, the summary imperative and present tense with a capital first letter ("feat: Add tags to items"); the body explains why when the diff alone doesn't. `feat` is a feature a tester can see or use and `fix` a fix a tester would notice: their summary becomes the build's release-note line as it stands, so it is written for the tester, in the app's own words, with no code in it. Everything else is `refactor`, `perf`, `test`, `docs`, `build`, `ci`, `style` or `chore`, and shows only as "Maintenance and performance improvements". A scope is allowed (`fix(sync): ...`) and not shown; `chore(release)` is the release script's own. Merge commits keep git's default message.
- Never mention AI tools in commit messages, PR text, code or comments; no Co-Authored-By trailers. The committer is fully responsible for the commit.
- All commits are authored and committed as `Michael Schuller <petronius1125@gmail.com>`, and no other key signs them. Any tool making commits on his behalf uses that name and email for both the author and the committer, with no separate tool attribution. A machine's global git identity is not his, so a new checkout sets the repository's local config before its first commit: `git config user.name "Michael Schuller"`, `git config user.email petronius1125@gmail.com`, and `git config commit.gpgsign false` where the global config signs with another key. `git var GIT_COMMITTER_IDENT` shows the identity a commit will carry.
- **Always push.** Once the repository has a remote, every commit is pushed to `origin` as soon as it is made, without being asked. Michael works across several environments, so an unpushed commit is a broken hand-off.
- Don't commit build products, the generated Xcode project or Xcode user state (see `.gitignore`).

## GitHub issues

Issues carry two labels and no others:

- **`draft`**, grey: an idea or a deferred feature still being shaped. Nothing is built from it.
- **`ready for development`**, green: specified well enough to build as it stands.

No other label is created, by hand or by a tool. `Scripts/gh-labels.sh` sets the two on the repository and deletes every other label; it runs once on every new repository, and again whenever a label has crept in.

Working on issues:

- **Asked to look at the open issues, take only those labelled `ready for development`.** A `draft` issue, or one with no label, is not work to pick up unless Michael names it.
- **An issue is done when it is built, merged and closed.** Build it under the rules here, say `Closes #<number>` in the body of the commit that finishes it, merge to `main` and push, then close the issue as completed if the push has not already closed it.

## Merging branches: merge when green, no locks

Parallel units build in their own worktree on `bgbuild/<NNN>-<slug>` and are merged as soon as they are ready. There is **no merge lock**: do not create one, wait on one, or check for one.

When your branch is green:

1. `git merge main` **in your own worktree**, resolve conflicts there, re-run the tests and the build. Never resolve conflicts in the root working tree.
2. Move the task file `doing/` → `done/` and commit.
3. `git -C <root> merge --no-ff --no-edit bgbuild/<NNN>-<slug>`.
4. If step 3 fails because `main` moved while you were verifying, that is ordinary concurrency, not an error: go back to step 1, merge the new `main`, resolve, re-test and retry. Two iterations is typical, three is unusual.
5. Remove the worktree and delete the branch.

- **Never hold anything while iterating.** Do the screenshot-and-fix loop first; start the merge sequence only when the branch is actually green.
- **Re-run the suite after merging `main`**, every time. That is what makes the merge safe, not exclusivity.

## Writing style (Library, UI copy, commit bodies)

See `STYLE_GUIDE.md` for the prose rules, which apply to all writing. The rules below add to them.

- **Copy lives in `Copy/copy.tsv`, never as a literal**: a string the user reads goes in the table as a row, and the call site reads `Copy.area.screen.element`. Run `Scripts/gen-copy.sh` and commit the table and `Core/Sources/AppText/Copy.generated.swift` together. This holds from the first screen, so there is never a migration.
- State the fact and stop. Drop trailing clauses that explain why the fact is nice ("Synced at 14:05, so your devices agree" becomes "Synced at 14:05"). A clause earns its place by adding information the reader can act on ("turn sync on to upload again") or a real reason, never by supplying significance.
- **Name things exactly.** One concept has one word, in the copy table, the Library and the code alike. When the app adopts a term, write it down here with what it means and what it does not.
- **Accuracy is stated, never implied.** A figure is shown to the precision its data supports.

## Engineering conventions

- Swift 6 (strict concurrency) and SwiftUI. iOS 18 and watchOS 11 at minimum, set in `project.yml` and `Core/Package.swift` together.
- **Local-first.** The store on the device is the source of truth. The app opens, reads and writes with no connection and with iCloud off. The sync is a peer that carries changes between devices; no feature waits on it, and no view talks to CloudKit or to the database. Views read `StoreModel` (`Shared/Sources/StoreModel.swift`) and call its edit methods.
- **The core is pure.** Domain logic lives in `Core/` (`AppCore`): pure functions of their inputs, no I/O, no clock access, no CloudKit, deterministic, tested with `swift test`. A function that needs "now" takes it as an argument. Views, widgets, complications and the watch all read from the core; none computes a figure of its own. A feature that needs a figure the core does not provide adds it to the core.
- **Domain models carry no storage or sync fields.** The store keeps the edit stamp and the tombstone beside the row; the sync carries them in the envelope. A model can change without touching either.
- **Store** (`AppData`): GRDB over SQLite, a `DatabasePool` in the App Group container shared with the widgets, which open it read-only. Every synced table has `id`, `payload` (the model as `SyncCoding` JSON), `updatedAt` (a `SyncStamp`) and `deletedAt`, plus the denormalised columns its queries need, so a field added to a model needs no migration. Every write stamps `updatedAt` in the same statement as the edit; a delete sets `deletedAt` and keeps the row as a tombstone. Reads skip tombstones. Schema changes are new named migrations in `AppDatabase.migrator`, never an edit to a shipped one. Housekeeping that is not the user's edit never touches `updatedAt`.
- **Sync** (`AppSync`): `CKSyncEngine` over the private database, one custom zone, one record per fact, typed by `SyncRecordType`, resolved by `SyncResolution` (newer edit wins, a tombstone is a fact). Payloads are in the record's encrypted values. A shipped record type, field or zone name is permanent. The schema is `Scripts/cloudkit-schema.ckdb`. Syncing a new type follows the checklist in `spec/capabilities/CloudSync/README.md`; data a device can derive for itself is never synced.
- **One formatting for every figure.** A number becomes text through `AppText.Format`, which rounds with the standard library's `rounded()`, a half away from zero, so 102.5 reads 103. Never `String(format:)` with a float spec (it rounds a half to even), a number format style, or `Int(value)` on a shown figure (it cuts the fraction off). `FormattingSourceScanTests` scans the sources. Add a function to `Format` when a kind of figure is missing.
- **One figure, one place per screen.** A piece of data (a figure, a date, a name) appears exactly once on a screen, and a widget or complication counts as a screen; any other element on that screen that needs it points to it or leaves it out, never states it again in other words. Every surface that shows the same figure reads it from one source function with one set of inputs and one empty state, so two places can never disagree. A new element that would repeat a figure already on the screen is redesigned, not added.
- **Remove unused code eagerly.** When a change leaves a type, function, property, copy row, stored field or article with no reader, the same change deletes it, along with whatever existed only to feed it. Nothing is kept "for when it comes back": git has it.
- **iPhone and iPad from one target.** Compact width is the phone layout; regular width turns the tab bar into a sidebar (`.sidebarAdaptable`) and a list screen into a `NavigationSplitView`. New screens must work in both, and in Split View on iPad.
- **The watch is a peer.** The watch app has its own store and its own `CloudSync`, against the same container, so it works with the phone out of reach. No feature relies on WatchConnectivity for data the sync already carries.
- **Time.** Absolute instants for elapsed-time math; the user's current time zone for calendar concepts (today, a day's boundaries). A function that needs a time zone takes it as an argument.
- **Fetched data carries its age.** Anything fetched from the network carries the time it was fetched and the window it is valid for. A consumer checks both before using it, and outside the window the figure is hidden or flagged, never shown as current.
- **One `NavigationLink` per list row, or none.** A `List` row is one cell, and a tap on it activates *every* link the cell contains, so a row holding several opens all of their destinations at once. When a row carries more than one tap target, each one is a `Button`, and the screen opens the destination: append to the stack's own path, or set one `@State` that a single `.navigationDestination(item:)` reads. `.navigationDestination` is declared once, on the screen the tap came from, never inside the `ForEach` and never on a stack root the screen sits above.
- **An unstyled container carries no corner radius.** A grouped `List` masks every row to its section's corners, so a card drawn flush inside one has its own corners shaved wherever the two radii differ. A container that draws no fill of its own must not round or clip what it holds, and one that does must clip to the shape it draws rather than to a rectangle.

## Build & run

- **Michael builds and tests on his Mac.** An environment without the Swift/Xcode toolchain, or without another development tool, is known and expected: write the change carefully by inspection and carry on. Never warn about the missing toolchain or tool, in a reply, a commit or a PR.
- Simulator builds are signed ad hoc (`CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual`, as `Scripts/build.sh` does), never `CODE_SIGNING_ALLOWED=NO`: an unsigned build carries no entitlements, and CloudKit traps at launch without the iCloud one.
- The Xcode project is generated: `xcodegen generate` (`project.yml` is the source of truth; `Scaffold.xcodeproj`, the `Info.plist` files and the entitlements files are gitignored and rewritten on every generate).
- The shared code is a Swift package with its own tests, runnable without a simulator: `Core/` (`AppCore` the models and sync rules, `AppText` formatting and the generated copy, `AppData` the store, `AppSync` the CloudKit sync).
- Commands, from the repository root:
    - `cd Core && swift test`: the core tests.
    - `Scripts/gen-copy.sh`: regenerate `Copy.generated.swift` after editing `Copy/copy.tsv`; `--check` fails when they disagree.
    - `Scripts/build.sh [derived-data]`: generate the project and build the phone app, with the watch app, the complication and the widget, for the simulator; prints the `.app` path.
    - `Scripts/test.sh [derived-data] [udid]`: the core tests, the copy check, the app tests and a watch build.
    - `Scripts/sim-shot.sh <udid> <app> <out.png> [launch args]`: install, launch and screenshot headlessly. Launch arguments are listed in `App/Sources/Debug/LaunchOptions.swift`.
    - `Scripts/make-icon.sh`: rebuild the app icon from `design/icon/` into both asset catalogues.
    - `Scripts/cloudkit-schema.sh`: import the CloudKit schema into Development.
    - `Scripts/testflight.sh`: archive and upload to TestFlight, with the build's release notes. It reads the App Store Connect key from `~/.scaffold-asc.env`, falling back to `~/.asc.env`. On its first run with no build tag it first writes the release notes of every earlier build, from the builds App Store Connect lists.
    - `Scripts/release-notes.sh preview`: the release notes the next build will carry. `backfill` writes those of earlier builds (see the script's header).

## Verification is headless, always

Never take foreground control of the machine to check the app: no computer-use tools, no screen screenshots, no clicking or typing into the UI, and never `open -a Simulator`. It blocks the user's own work. Everything is reachable headlessly:

- `xcrun simctl boot <udid>` boots without opening Simulator.app.
- `xcrun simctl io <udid> screenshot <file>.png` captures a booted device with no visible window; read the file back instead of looking at the screen. The same works for a watch simulator.
- Reach screens and states with DEBUG launch arguments (`-DebugFixture 1`, `-DebugTab`, `-DebugScreen`) rather than simulating taps. If a screen has no route in, add a launch argument for it.
- `xcrun simctl ui <udid> content-size extra-extra-extra-large` sets Dynamic Type, and `xcrun simctl ui <udid> appearance dark` dark mode, without Settings.
- Read pass/fail from the xcodebuild log, never from watching the UI.

With several builds running at once, use a dedicated simulator device and your own `-derivedDataPath`: a shared device produces stale, crash-like results. `simctl install` over an existing bundle can keep serving the old binary, so `uninstall` first.

**Clean up what you started, on every exit path including failure.** Before finishing, a background task removes everything it created:

- `xcrun simctl shutdown <udid>` every device it booted, then `xcrun simctl delete <udid>` every device it created. Never delete a device you did not create, and never delete a standing device: a sibling may be mid-run on one.
- Quit any `Simulator.app` it caused to launch. Nothing here needs the GUI; if it is running, something took the non-headless path.
- Delete its `-derivedDataPath` directory under `/private/tmp`.
- Remove its worktree and delete its branch, per the merge protocol.

Name created devices after the task (`bgbuild-<NNN>`) so an orphan is traceable to the run that leaked it.

## Testing

- Core logic is tested in `Core/Tests` with Swift Testing: every rule a table of cases, every reference value with its tolerance and its `references/` entry.
- The store is tested against an in-memory database (`AppDatabase.inMemory()`); the sync's rules through `SyncResolution` and `RecordMapping`, which need no account.
- App tests (`App/Tests`) cover the app target's own logic: launch options, and the bundled Library (every article indexed, every link resolving, every `ArticleID` in the sources bundled).
- The sync between two real devices, push delivery, widgets and complications on the Lock Screen and watch face can only be judged on hardware. Real-device testing happens on Michael's iPhone, iPad and Apple Watch; never rely on the simulator for those.
