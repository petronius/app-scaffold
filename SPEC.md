# Scaffold – product spec

<!-- The binding product spec. Replace every comment with the app's own content; delete a section only when it cannot apply. Keep requirements numbered (F1, F2, ...) so code, docs and commits can cite them. -->

## 1. Product vision

<!-- What the app does, for whom, and the one thing it does better than anything else. Three to five sentences. -->

### Target user

<!-- Who uses it, on which devices, in which situations. -->

### Explicit non-goals

<!-- What the app will not do, so a feature request can be checked against it. -->

## 2. Design principles

<!-- The rules no feature may break, each one testable. For example: -->

- **Local-first.** Every feature works offline and with iCloud off. Sync carries changes between the user's devices; nothing waits on it.
- **Private by default.** The user's data stays on their devices and in their own iCloud account. No analytics, no accounts, no server of our own.
- **Every element carries information.** See `spec/DESIGN-STYLE.md`.

## 3. Platforms

| Device | Role |
|---|---|
| iPhone | <!-- the main app --> |
| iPad | <!-- the same app, sidebar and split columns in regular width --> |
| Apple Watch | <!-- what the watch app and complications do; a peer that syncs on its own --> |
| Widgets | <!-- what the Home Screen and Lock Screen widgets show --> |

## 4. Features

<!-- One subsection per feature: what the user can do, what they see, the rules and edge cases. Example: -->

### F1 – Items

The user keeps a list of items, each with a title and optional notes, on every device they own. (The scaffold's example feature: replace it.)

- Add, edit and delete an item on iPhone, iPad and Apple Watch.
- A deletion reaches every device.
- The widget and the complication show the count of items and the newest titles.

## 5. Architecture

### 5.1 Local-first, no backend

Each device keeps the user's data in a local SQLite store (`AppData`), the source of truth on that device. iCloud sync (`AppSync`, `CKSyncEngine` over the private CloudKit database) carries changes between devices. `spec/capabilities/CloudSync/README.md` holds the design.

### 5.2 Data model

<!-- The app's records: what each holds, which sync, which are derived on each device. -->

| Record | Holds | Synced |
|---|---|---|
| Item | title, notes, created | yes |

### 5.3 Privacy and data handling

<!-- What the app reads (Health, location, contacts...), why, where it is kept, and the usage strings it shows. -->

### 5.4 Time and time zones

Absolute instants for elapsed time; the user's current time zone for calendar concepts.

## 6. Screens

<!-- One subsection per screen or tab: what it shows, in what order, and its empty and loading states. Include the iPad layout and the watch app. -->

## 7. Open questions

<!-- Decisions not yet made, each with its options. Move a question into the spec once it is decided. -->
