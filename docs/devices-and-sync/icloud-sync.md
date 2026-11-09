# iCloud sync

Scaffold keeps your data on your device first, and uses your own iCloud account to keep your other devices up to date. The app works the same with sync off or with no connection; sync only carries changes between devices. Nothing goes to any server other than Apple's iCloud.

## Where your data lives

Each device holds a full copy of your items. The app reads and writes that copy, so it opens at once and works offline. When sync is on, each change also goes to a private area of your iCloud account that only your devices can read. Other people cannot see it, and neither can the app's developer.

Your notes and titles are end-to-end encrypted. The key is in your iCloud Keychain, so not even Apple can read them.

## How a change travels

```
this device ──▶ your iCloud ──▶ other devices
```

The diagram shows one change moving from the device you used, through iCloud, to every other device on your account.

1. You change an item. The device saves it at once.
2. A moment later the app sends the change to iCloud.
3. iCloud tells your other devices that something changed.
4. Each device fetches the change the next time the app runs, or at once if it is open.

A device without a connection keeps its changes and sends them when it is back online.

## When two devices change the same item

Each change carries the time you made it. When two devices change the same item before they sync, the later change wins on both devices. The whole item takes the later version, title and notes together.

A deletion counts as a change too. If you delete an item on one device and edit it later on another, the later edit brings it back. If the deletion is later, the item goes from both.

## Turning sync off

Sync is on when you first open the app, if you are signed in to iCloud. You can turn it off in Settings, under iCloud. Your items stay on this device. Turning it on again sends any changes you made while it was off.

If you delete the app's data from iCloud (in the Settings app, under your name, iCloud, then Manage Storage), Scaffold turns sync off on each device and keeps the copy there. Turn sync on again on a device to upload its items.

## Status

The Status row in Settings shows what the sync is doing:

| Status | Meaning |
|---|---|
| Synced at a time | The last sync finished at that time. |
| Syncing | A sync is running now. |
| Waiting for the first sync | Sync is on and has not finished a pass yet. |
| No iCloud account | The device is not signed in to iCloud. |
| Sync failed | The last sync failed; iCloud's own reason follows. The app tries again on its own. |

## In this app

- Settings, under iCloud: the switch, the status and Sync now.
- Pull down on the Items list to sync at once.

## Related

- [Items](../using-the-app/items.md): what syncs
- [Apple Watch](apple-watch.md): how the watch syncs without the phone
