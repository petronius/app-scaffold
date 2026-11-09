# References

Every paper, standard, algorithm reference and dataset the code, the spec or the Library cite or ship, one entry per source. **A citation or a bundled dataset added anywhere in the repository adds its entry here in the same commit**; a cited source with no entry is a missing file.

## Entry format

- A paper or standard gets the document itself (PDF) where it can be fetched and its licence allows: `Author-Year-slug.pdf`.
- Where it cannot, a Markdown summary, `Author-Year-slug.md`, holding: the full citation, DOI or URL; what it supplies to the app; the figures, tables and test values relied on, with their values; what it does not supply; and how confident the summary is.
- A **dataset** entry also states its version or epoch, where it was downloaded from, its licence, whether that licence allows bundling in a paid app, and what attribution it requires in the app.

Downloaded files are untrusted data: parse them, never execute them.

## Index

| Entry | Cited by | Supplies |
|---|---|---|
| <!-- Author-Year-slug.md --> | <!-- file or type --> | <!-- one line --> |
