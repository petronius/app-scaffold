# App icon

**Placeholder.** A 3 × 3 grid of rounded squares, the centre one in the accent colour, on a slate background. It marks the app as unbranded; replace it before the first TestFlight build.

| File | Use |
|---|---|
| `AppIcon.svg` / `.png` | The default iPhone and iPad icon, and the watch icon |
| `AppIcon-dark.svg` / `.png` | iOS dark appearance: transparent background, the system supplies it |
| `AppIcon-tinted.svg` / `.png` | iOS tinted appearance: greyscale on transparent, the system tints by luminance |

`generate.py` draws all three SVGs; the sizes and colours are the constants at its top. To rebuild and copy the PNGs into `App/Assets.xcassets/AppIcon.appiconset` (all three) and `WatchApp/Assets.xcassets/AppIcon.appiconset` (the default):

```bash
Scripts/make-icon.sh
```

To use hand-made artwork instead, replace the three SVGs (1024 × 1024, no transparency in the default one) and run `Scripts/make-icon.sh --keep-svg`.

## Rules for the real icon

- One 1024 × 1024 square per variant. The system applies the corner mask on iOS and the circle on watchOS, so keep the artwork inside the central circle of radius 512 and draw no corners or shadow of your own.
- The dark variant has a transparent background; the tinted variant is greyscale on transparent.
- Few elements and two or three colours, legible at 40 pt on the Home Screen and on the watch.
- Icon Composer (`.icon`) files from Xcode 26 and later can replace the asset catalogue set; if adopted, record the change here and in `project.yml`.
