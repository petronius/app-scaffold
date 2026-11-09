# Design style guide

How Scaffold's screens, widgets and complications look and move. Prose rules are in `STYLE_GUIDE.md`, copy rules in `CLAUDE.md` ("Writing style"), Library articles in `DOCS-STYLE.md`. Scaffold follows Apple's design language and the Human Interface Guidelines (HIG). Where this guide and the HIG disagree, the HIG wins, and the system's own controls, fonts, materials and transitions come before anything custom.

## The rule

Every element on a screen carries information the user can read or act on. An element that only decorates comes out. When two designs show the same facts, the one with fewer parts is right.

## Type

- **System fonts by default.** SF Pro and SF Compact, through the text styles (`.headline`, `.body`, `.caption`), so Dynamic Type and Bold Text work. A custom face, if the visual direction adds one, is registered against the same text styles and stated below.
- **Regular to Bold.** No Ultralight, Thin or Light weights: they fade at small sizes.
- **No tracking changes.** The system font sets its own tracking at every size.
- **Sentence case for every element**, buttons included ("Sync now"). No hand-made capitals (`.uppercased()`, `.textCase(.uppercase)`) for subtitles, labels or overlines.
- **No italics in the UI.** Emphasis comes from weight or size. The Library's reader keeps the emphasis an article's author wrote, and its equation boxes set variables in a serif italic, so a formula reads as mathematics rather than as interface copy.
- **No full stop at the end of a title**, header, button or one-line label. Body sentences keep theirs.
- **Titles wrap cleanly.** A title may take two lines. Check it at the largest Dynamic Type size: no key word truncated, no single word left alone on the last line where a shorter title would fit.
- **Stack at accessibility sizes.** When `dynamicTypeSize.isAccessibilitySize`, a row's secondary items (a time, a glyph, a value) move under its text rather than crowd it. The most important element stays at the top.

## Colour

- **One colour, one meaning.** The accent (`Palette.accent`, the asset catalogue's `AccentColor`) marks the primary action and the selection. `Palette.attention` means a warning, and nothing else. A colour added for a kind of thing names that thing everywhere and nothing else; it goes in `Palette` and in the table under Visual direction.
- **Never colour alone.** A state that a colour shows also has a word, a shape or a symbol, for users who cannot tell the colours apart, and for the tinted widget and complication renderings.
- **Named colours only.** A colour comes from `Palette`, the asset catalogue or the system's semantic colours, never a literal in a view. Each named colour has a light and a dark value.
- **Few tints.** A colour's background wash takes a shared opacity, `Palette.wash` behind a chip or a tile and `Palette.strongWash` behind a chosen one, not a value picked per view.
- **No gradient behind content.** A gradient is allowed only where it encodes data, such as a chart's scale.
- **Backgrounds are the system's.** `systemGroupedBackground` and `secondarySystemGroupedBackground`, no tinted page grounds.
- **Contrast first.** Text is `.primary` or `.secondary`. Coloured caption text on its own tint fails contrast: a chip keeps primary text and puts the colour in a dot or the wash. `.tertiary` is for the least important text only, never a figure the user reads.
- **Light and dark.** Every screen works in both appearances. Check both before a screen ships.

## Surfaces and shape

- **A card is a fill or a border, never both.**
- **One level of nesting, alternating.** A small filled card may sit inside a bordered card, or a bordered one inside a filled card. Never a fill inside a fill, a border inside a border, or a third level.
- **Group with spacing.** Related items sit closer together than unrelated ones. A grouped `List` separates its sections and draws its own row separators. Add a `Divider` only between groups that spacing cannot separate.
- **Concentric corners.** An inner shape's radius is the outer radius less the padding between them. A card flush in a list row draws no corners of its own (`CLAUDE.md`, "An unstyled container carries no corner radius").
- **Glass is for controls.** Liquid Glass is the layer of controls and navigation above the content. Tab bars, toolbars, sheets and system controls take it on their own. Never put it on content: cards, rows and backgrounds use the standard materials or the grouped background colours. A custom control that floats over content may take `glassEffect`, sparingly and in the regular variant.
- **Targets of 44 pt** on iPhone and iPad, and the HIG minimum on the watch. Every tappable element has a hit region at least that size, whatever its drawn size.

## Icons

- SF Symbols only. One concept takes one symbol everywhere: phone, iPad, widget, watch and complication.
- One weight and scale per context. A symbol beside text takes the text's style, so the weights match.
- Hierarchical rendering gives a symbol depth. Variable colour shows a value that changes, never depth.

## iPad

- **Both widths.** Compact width is the iPhone layout. Regular width shows the tabs as a sidebar and a list beside its detail. Split View on iPad lands in whichever width it gets, so every screen works in both.
- **A detail has a resting state.** With nothing selected, the detail column says what to do ("Select an item"), never stays blank.
- **Readable widths.** Running text in a wide column stops at about 680 pt, as the Library's articles do.

## Widgets and complications

- **A widget or complication is a screen.** The one-figure-one-place rule in `CLAUDE.md` applies inside it: a figure, a label or a unit appears once.
- **Only what fits.** One figure or one glyph and its context. Detail goes in the app it opens.
- **Every rendering.** Full colour, the tinted (`accented`) rendering and the vibrant Lock Screen rendering. Which parts take the accent is set with `widgetAccentable`, never left to chance.
- **Same source as the app.** A widget reads the same summary function the app would, so the two never disagree (`ItemsSummary`).

## Content

- **Show the fact.** A card states its one figure and what the user can do with it. Extra readouts go on the detail screen.
- **The main element is the largest.** Each screen has one primary element; the rest step down.
- **No redundant labels.** A figure whose unit or neighbour already names it takes no label. A heading that repeats the navigation title goes.
- **Pills carry values.** A chip shows a figure or a state. No filler badges such as New, Beta or Smart.
- **Specific headings.** "Items added this week", not "Insights".
- **One prominent action.** A screen has at most one `.borderedProminent` button, for its most likely action. Other actions are plain or sit in a menu. Buttons offered as a set are the same size. A bar button (Done, Cancel, Save) keeps the system's tinted text.
- **No eyebrows, section numbers or breadcrumbs.** The navigation title says where the user is.
- **Real views in figures and previews.** Library figures and widget previews render the app's own views with sample data, not drawings of them.

## Numbers and states

- **Tabular figures.** Every number that changes or sits in a column takes `.monospacedDigit()`, so digits do not shift width.
- **One formatting.** Every figure goes through `AppText.Format` (see `CLAUDE.md`).
- **Units always.** Every figure shows its unit or a symbol that names it.
- **Precision follows accuracy.** A figure shows no more digits than its data supports.
- **Data age is visible.** Where a figure depends on fetched or synced data, its age is one tap away, and stale data is marked in the figure's own place.
- **Every read has a loading state.** Show something at once: a placeholder the size of the final content, or a `ProgressView` where the wait has no shape. The layout does not jump when the data arrives.
- **Every list has an empty state** that says what fills it, as the next step the user can take (`ContentUnavailableView`).

## Motion

Motion explains a change: where something came from, where it went, or that an action worked. Motion that explains nothing comes out. System controls animate themselves, so custom motion is for custom elements only.

- **Brief and precise.** Feedback motion is short and tied to the one thing that changed.
- **Little on frequent actions.** An interaction the user repeats many times a day gets the least motion that still shows the change.
- **Never blocking.** No animation holds up input. A tap during an animation acts at once, and the animation gives way.
- **Never the only signal.** Information that motion shows is also in the final state, a haptic or the text.
- **Reduce Motion.** Under `accessibilityReduceMotion`, a move, scale or stagger becomes a fade, and nothing blinks.

### Timing

| Use | Curve | Duration |
|---|---|---|
| An element appears | `.easeOut` | 200 to 250 ms |
| An element leaves | `.easeIn` | about 20% shorter than its entrance |
| An element moves on screen | `.easeInOut` or `.smooth` | 250 to 350 ms |
| A menu or panel opens | `.easeOut` | 150 to 250 ms |
| Everyday controls | a spring with no bounce (`.spring(bounce: 0)`) | system default |

- **No bounce on everyday UI.** Bounce belongs only to a release after direct manipulation.
- **Asymmetric transitions** give the shorter exit: `.asymmetric(insertion:removal:)` with each side's own animation.

### Entrances and exits

- **From the trigger.** A popover, menu or expanding card grows from the control that opened it, and closes toward the same point.
- **One element, one identity.** An element that moves between two layouts keeps one `matchedGeometryEffect` id, so it moves rather than fades out and in.
- **Overlap old and new.** The old state fades out while the new one fades in. A changing figure uses `.contentTransition(.numericText())`; a symbol swap `.contentTransition(.symbolEffect(.replace))`.

### Direct manipulation and feedback

- **Exact while held.** During a drag, a pinch or a Digital Crown turn the value follows the input with no easing. Animate only after release.
- **Press feedback.** System button styles give their own. A custom tappable card scales to 0.97 while pressed, with no delay on release.
- **Haptics with meaning.** A haptic accompanies a visible change, uses the system feedback that names it (success, warning, selection), and is kept for events that matter. No haptic on scroll or on every tap.
- **A pulsing dot means live.** Only something running right now pulses. Never as decoration.

## Not used

These are fashions that date a design and carry no information: dithering, ASCII art, pixel loaders, marquees, infinite canvases, painted art, animated logos, rows of three icon cards, text wrapped around shapes, dark gradient headers.

## Visual direction

Not set yet. The first design review decides it and records it here as rules, with mockups in `design/mockups/`. Until then the app uses the system's own look: the default palette below, system fonts, grouped lists.

| Name | Light | Dark | Meaning |
|---|---|---|---|
| accent | #3B75E5 | #5C94F6 | The primary action, the selection, links |
| attention | #D97706 | #FF9F0A | A warning |

Still to be decided, and not to be borrowed from another app:

- the palette beyond the accent, and whether the app has a fixed appearance
- a custom typeface, if any
- the icon (the repository ships a placeholder, `design/icon/README.md`)

When a decision is made, it goes in this file as a rule.

## Review checklist

Before a screen, widget or complication ships, check that:

1. Every element carries information or an action.
2. There is one accent, one prominent action and one largest element.
3. No card has both a fill and a border, nesting stops at one alternating level, and inner corners are concentric.
4. Figures use `.monospacedDigit()`, `Format`, a unit, and no more precision than the data has.
5. Titles have no full stop, no hand-made capitals and no italics.
6. Loading and empty states exist, and every target meets the minimum size.
7. Each animation explains a change, never blocks input, and Reduce Motion turns moves into fades.
8. No colour carries a meaning alone, and no glass sits on content.
9. The screen works at the largest Dynamic Type size, in light and dark, and on iPhone and iPad in both widths.
10. Widgets and complications read correctly in full colour, tinted and on the Lock Screen.
