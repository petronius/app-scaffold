# Prose style guide

These rules apply to all writing in this project: the Library, UI copy, specs, commit messages, PR descriptions and replies to Michael. `CLAUDE.md` "Writing style" adds the rules for UI copy, and `spec/DOCS-STYLE.md` the rules for Library articles.

## General rules for all writing

- Write in simple sentences as much as possible. "Simple" here means single-clause sentences without adverbial phrases.
- Avoid metaphor, idiom and purple prose, unless an explanatory metaphor is strictly needed. Literal verbs and adjectives are always preferred.
- Extreme conciseness is valuable. A concise text needs little repetition, extra emphasis or further explanation, so cut them.
- When writing structured text, or designing documents or UI elements, state each piece of information once. The same information repeated in different places in different ways adds confusion.
- Avoid the passive voice.
- Write a rate with "per": "3 sessions per week", "100 items per page", not "3 sessions a week".
- No em dashes. Use en dashes sparingly; a comma, a colon or a full stop usually does the job.

## English prose style, after Hemingway

- Use one-syllable words more often than not.
- Use short sentences.
- Use positive language ("I am telling the truth" rather than "I am not lying").
- Avoid adverbs.

## Rules for interacting with the user

- Avoid emotional language, and do not address the user's perceived emotional state ("I can see you are frustrated"). Solve the problem and move on, with a clear statement of priority ("First priority is XYZ...").
- Identify jargon, terminology, scientific or formal concepts, academic language and other technical language as such, and explain it on first use, always. "Simpson's paradox, a phenomenon identified in statistics in which a trend appears in several groups of data but disappears or reverses when the groups are combined, shows that ...". Do not assume the user has expertise in a field unless the conversation or prompt has already established it.
- In the same way, identify *internal* jargon and references as such, and cite them on first use in conversation. This covers anything specific to the task, the code base, the documents under analysis, or other context of the task. ("The doFooBar() method, which comes from the FizzBuzz module and quxxes the data, should be refactored into a pure function to enable better testing.") Do not assume the user is an expert or recalls all of the context you have been given.
- Avoid casual jargon as well. An ordered list of build tasks is a "build order", not a "landing order". Prefer specific, correct use of basic verbs and nouns over colloquial or in-group speech. "The commits landed in the following order" is a specific and normal phrase; a list of build tasks is not a "landing order". This includes words and phrases like "lock in" for focusing.

## Examples of what to avoid

- Over-explanation. On a final step in a flowchart, one agent wrote "Save the item and return; nothing else runs". Better: "Save the item and return", or better still "Save the item".
- "It's not X, it's Y", and any phrasing built the same way. Say what it is, and leave it at that.
- "Load-bearing", "delving", "how it hangs together" and other common metaphorical words. "Important" or "critical" is often more correct than "load-bearing"; "a closer look" or "deeper investigation" rather than "delving".
- Oversimplification to the point of information loss. "Apple's App Store Review Guideline 5.1.1 requires that..." is more specific and informative than "Apple says you must...".
