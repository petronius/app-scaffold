# Library style guide

How the articles in the Library (`docs/`) are written and organised. Internal: this file is not bundled into the app. It applies to every file under `docs/`, new or changed. `STYLE_GUIDE.md` and `CLAUDE.md` "Writing style" apply as well; where they overlap, this file is the more specific.

## Purpose of the Library

The Library is the app's manual, on its own tab and bundled into every build, so it works offline. It answers two kinds of question:

- **How does the app do this?** An **app article** covers one system of the app: what it reads, how it decides, what the figures mean, how accurate they are. iCloud sync, a widget, a calculation.
- **What is this?** A **reference article** covers one concept from the app's domain that the app shows or uses. `SPEC.md` sets which concepts get one.

A reader arrives with one question, finds the article, and leaves. Articles are short and easy to read. Every rule below serves that.

## One article per topic

- A **topic** is one thing a reader might ask about on its own: one system of the app, or one concept. One article each.
- If an article needs a "Part 1 / Part 2", it is two topics. If two articles say the same thing, one of them links to the other instead. An app article that rests on a concept links to the reference article for it rather than explaining it again.
- Articles sit one level down, in a section folder: `docs/{section}/{article}.md`, both lowercase, words separated by hyphens (`docs/devices-and-sync/icloud-sync.md`). The folder name is the section's title, read as sentence case by the in-app list (`devices-and-sync` shows as "Devices and sync"), so a folder is named the way a heading would be. App articles and reference articles go in separate sections; a new section is a new folder, and it earns its place only with several articles. An article never nests deeper than its section. `docs/README.md` is the index, the only file at the root and the only file that lists everything.
- A link between articles is relative to the linking file: `other.md` inside the same section, `../section/other.md` across sections, `section/other.md` from the index.
- An article owns its definitions and formulas. Another article that needs one links to it rather than repeating it.

## Shape of an article

Every article has the same skeleton, in this order:

1. **Title** (`#`): the topic's name as the app names it. One title per file; the in-app browser reads it as the document's title.
2. **Summary**: one paragraph of two to four sentences saying what the topic is and what it is for. A reader who stops here has the answer to the common question.
3. **Sections** (`##`) in reading order. For an app article: what it reads, what it does, what the reader sees, then the detail (formulas, accuracy, edge cases). For a reference article: what it is, how it is defined or measured, how it relates to its neighbours, then the detail. Subsections (`###`) only inside a section that has three or more parts. No `####`.
4. **In this app**: where the topic shows up, as a short list: the screen, tab, widget, complication or setting it lives on.
5. **Related**: links to the articles a reader of this one is likely to want next, one line each saying why.
6. **Sources**, when the article rests on a standard or published work: author or body, year, one line on what it contributes. Every source has its entry in `references/`.

The viewer sets In this app, Related and Sources apart from the body by their headings, so they keep those exact names.

Length: 200 to 800 words. Under 200 words it is probably a section of another article; over 800 it is probably two topics.

## Structure over prose

- A paragraph is at most four sentences. Two or three is usual.
- A list of things is a list, not a sentence with commas. Use bullets for unordered facts, numbers for steps or ranks.
- A rule with conditions, or a comparison of related things, is a table: one row per case. Keep tables to four columns or fewer; the in-app viewer fits a table to the phone's width, so every further column narrows every cell.
- A formula is an `equation` block: a fenced code block whose language is `equation`, the formula on the first lines, a blank line, then the variables named one per line with their units. The app renders it as a box with the variables under the formula; an editor shows it as code. Never an inline formula in running text.

```equation
v = d / t

v: average speed, in kilometres per hour
d: distance, in kilometres
t: elapsed time, in hours
```

- A constant is stated with its value and unit in the sentence that uses it, and once, in the article that owns it.
- A worked example uses real inputs and gives the result the app would show, so a reader can check the app against it.
- Headings are nouns or noun phrases ("Turning sync off", "When two devices change the same item"), never questions.

## Diagrams

Use a diagram when the thing being explained is a flow, a sequence, a hierarchy, a geometry or a timeline. Do not use one for a list or a single rule.

Diagrams are text, in a fenced code block, drawn with plain characters so they render in the in-app viewer and in a plain text editor:

```
this device ──(save)──▶ iCloud ──(fetch)──▶ others
```

Keep a diagram under 12 lines and 50 characters wide, so it fits the phone's width in a monospaced face. Label every part with the same words the article uses. A diagram is followed by one sentence saying what it shows. Nothing in a diagram is said only in the diagram.

## Language

- Simple words. "Use" not "utilise", "about" not "approximately", "start" not "commence".
- Short sentences. One idea each. If a sentence needs a semicolon, it is two sentences.
- Present tense, second person: "the list shows your items newest first". The app is "Scaffold" or "the app", never "we".
- No metaphors, no rhetorical flourishes, no jokes, no reassurance. State the fact and stop.
- No sentence exists to say why a fact is interesting. A clause earns its place by adding a fact the reader can use.
- Define a term the first time an article uses it, in the same sentence or the next, even if another article defined it too. Then use the same term throughout. The app's own word wins, and a term in the Library matches the label the app shows.
- Spell out each acronym at its first use in an article, with the acronym after it in brackets, and use the acronym alone after that.
- Numbers as digits with units: "15 cm", "3 items". A negative value takes the minus sign "−1.5", not a hyphen. Ranges as "1 to 3 days", not with a dash.
- No en dashes, no em dashes. A comma, a colon or a full stop does the job.
- State accuracy plainly where it limits what the reader can do. Never claim more precision than the app has.
- No code: no identifiers, file names, setting keys, type names or function names. The Library describes behaviour and concepts; `CLAUDE.md` and `spec/` describe the code.

## Linking

- Link the first mention of another topic in each article, with the link text being that topic's name: `[iCloud sync](../devices-and-sync/icloud-sync.md)`.
- Every article is linked from `README.md` and from at least one other article's Related section. An article nothing links to is not findable. `LibraryCatalogTests` checks both, and that every link resolves.
- Link to an article, not to a heading inside it. Headings move; files do not.
- A link replaces repetition. If a paragraph is about to restate another article's rule, it says the rule in one clause and links.
- A screen links a value or setting to its article with an `InfoButton`.

## The index

`docs/README.md` is a map, not an essay: one paragraph on what the Library holds, then the articles under one heading per section folder, the heading being the folder's title and the sections in the order the app should list them, one line each, the line saying what question the article answers. It lists every article and nothing else. The index is what orders the in-app list, so an article's line goes under the heading of the folder it is in.

A long section is split into groups with `###` headings in the index, each a few related articles under a short plain title. The in-app list shows each group as a list section under the section's title. Groups exist only in the index: the articles stay in their section folder, and a section is grouped throughout or not at all.

## Release notes

The `release-notes` section is written by a script from the git history, and most rules above do not apply to it. It holds one article per TestFlight build, `build-<build number>.md`, which `Scripts/testflight.sh` writes when it uploads the build (`Scripts/release-notes.sh`), from the commits since the build before. Nobody writes one by hand; a wrong line is corrected in place.

- The title is "Build" and the build number, the number About shows. The summary is one sentence: the version and the date of the upload.
- Then `## New features`, one line per `feat` commit; `## Fixes`, one line per `fix` commit; and `## Other changes`, holding the one line "Maintenance and performance improvements" when the build has any other commit. A heading with nothing under it is left out, and nothing else follows.
- No In this app, Related or Sources, and no length or linking rules: the index lists every build under its last heading, newest first, and that is how a reader finds one. The Library shows the newest three there, then "See all", which opens the list of every build.
- A line is the commit's summary as written, so a `feat` or `fix` subject follows the Language rules above: what a tester can now do or will see differently, never how the code changed (`CLAUDE.md`, "Git practice").

## Keeping it current

- The commit that changes how the app works changes the app article that describes it. There is no later documentation pass.
- Adding a system adds an app article, a line in `README.md`, and Related links from the articles it touches.
- Removing a system removes its article and every link to it in the same commit.
- A change a tester can notice is committed as `feat` or `fix`, its subject written for the tester (Release notes, above).
- Before committing, read the article once as a reader would: one question in mind, scanning headings. If the answer is not findable in under a minute, restructure before adding words.

## Checklist

- One topic, one file, title matches the app's name for it.
- Summary paragraph first; In this app and Related at the end.
- 200 to 800 words; no paragraph over four sentences; no `####`.
- Lists are lists, rules and comparisons are tables, formulas are equation blocks, flows are diagrams.
- Terms defined at first use; acronyms spelled out at first use in every article; constants stated with units, once, in the owning article.
- Present tense, second person, simple words, no metaphors, no dashes, no code; accuracy stated where it matters.
- First mention of every other topic linked; the file is linked from `README.md` and one sibling; every source has a `references/` entry.
