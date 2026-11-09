# App scaffold

The starting point for a new iPhone, iPad and Apple Watch app: local-first, with iCloud sync and no server. It takes the structure, conventions and documents that held up in Sundial and Astrometrics, generalised, with one small example feature (Items) wired end to end so every layer has a working pattern to copy.

## What is in it

| Part | Where | What it gives you |
|---|---|---|
| Core package | `Core/` | `AppCore` (pure models and sync rules), `AppText` (one formatting, generated copy), `AppData` (GRDB store in the App Group), `AppSync` (CKSyncEngine sync). `swift test`, no simulator |
| iPhone and iPad app | `App/` | Tab bar on iPhone, sidebar and split columns on iPad, Items, Library, Settings with the iCloud toggle and status |
| Apple Watch | `WatchApp/`, `WatchWidget/` | A watch app that syncs through iCloud on its own, and a complication |
| Widget | `Widget/`, `WidgetShared/` | Home Screen and Lock Screen widget reading the store read-only |
| Shared | `Shared/` | `StoreModel` (what views see), identifiers, sample data |
| Library | `docs/` | The user manual, bundled and rendered in the app: search, tables, equations, diagrams, links |
| Copy table | `Copy/copy.tsv` | Every user-facing string, generated into typed Swift |
| Project | `project.yml` | XcodeGen; the `.xcodeproj` is generated and never committed |
| Scripts | `Scripts/` | build, test, headless screenshots, copy generation, icon, CloudKit schema, TestFlight, rename |
| Documents | `CLAUDE.md`, `STYLE_GUIDE.md`, `SPEC.md`, `FUTURE.md`, `spec/`, `references/`, `.taskbot/` | The rules, the spec templates, design and docs style guides, the sync design |
| Icon | `design/icon/` | A placeholder icon (default, dark, tinted) and the script that renders it |

## Start a new project

Needs Xcode 26 or later, XcodeGen and librsvg (`brew install xcodegen librsvg`).

1. Copy the scaffold's committed files into a new folder, without its history, and start a repository there:

    ```bash
    mkdir ../MyApp && git archive main | tar -x -C ../MyApp && cd ../MyApp && git init -b main
    ```

2. Rename it. This rewrites the names, bundle ids, App Group, iCloud container and file names, replaces this README with the project's own, and regenerates the Xcode project:

    ```bash
    Scripts/rename.sh --name "My App" --product MyApp --bundle-id com.yourname.myapp --team ABCDE12345
    ```

3. Set the commit identity, build, test, and make the first commit:

    ```bash
    git config user.name "Your Name" && git config user.email you@example.com
    ```

    ```bash
    Scripts/test.sh
    ```

4. Write `SPEC.md` and the first paragraph of `CLAUDE.md`. Replace the Item example with the app's own model, following `spec/capabilities/CloudSync/README.md` ("Syncing a new type"). Replace the placeholder icon (`design/icon/README.md`).

## First run on a device

Simulator builds need none of this. A signed build on a device, and iCloud sync anywhere, need the identifiers registered with Apple (developer portal, Certificates, Identifiers & Profiles):

1. App IDs: `<bundle-id>`, `<bundle-id>.widget`, `<bundle-id>.watchkitapp`, `<bundle-id>.watchkitapp.widget`.
2. On every App ID: App Groups, with the group `group.<bundle-id>`.
3. On the app and the watch app: iCloud (CloudKit) with the container `iCloud.<bundle-id>`, and Push Notifications.
4. With automatic signing, Xcode can create most of this on the first device build; check the portal afterwards.
5. Before the first TestFlight build: create the app record in App Store Connect, run `Scripts/cloudkit-schema.sh`, and deploy the schema to Production in the CloudKit Console.

## Choices, and why

- **GRDB and CKSyncEngine over SwiftData with CloudKit.** A plain SQLite store with one JSON payload per row keeps migrations rare, reads fast and widgets simple, and the sync rules are pure functions under test. SwiftData's CloudKit mirroring resolves conflicts out of sight, forbids unique constraints and needs every property optional or defaulted. `CKSyncEngine` (iOS 17 and later) does the change tokens, batching, subscriptions and retries that Sundial wrote by hand.
- **Tombstones and newer-edit-wins.** A deletion is a record, so an offline device cannot bring a deleted item back. The rule is simple enough for a user to predict, and it is written down in the Library.
- **The watch is a peer.** Its own store and its own sync, so it works with the phone out of reach, with no WatchConnectivity code to keep in step.
- **Encrypted payloads.** The model's JSON sits in the record's encrypted values: not even Apple can read it.
- **Generated project, generated copy.** `project.yml` and `Copy/copy.tsv` are reviewable text; a copy key typo is a compile error.
- **Headless verification.** Launch arguments reach every state, `Scripts/sim-shot.sh` screenshots it, and nothing takes over the screen.

## Placeholders to replace

- `design/icon/`: the icon.
- `SPEC.md`, `FUTURE.md`, the first paragraph of `CLAUDE.md`.
- The Item model, its screens, its Library article, its copy rows and its CloudKit record type.
- `spec/DESIGN-STYLE.md`, "Visual direction": the palette, and the accent in the asset catalogues.
- `MARKETING_VERSION` in `project.yml`.
