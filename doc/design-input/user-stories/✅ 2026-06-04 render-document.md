# User Story: Render Document

As a logged-in user who opens a generated document after transcription,
I want the document shown as readable, well-typeset content,
so that I can read my notes like an article, not decipher Markdown or other markup in the source.

## Acceptance Criteria

- On the document page, headings, lists, emphasis, links, and paragraphs appear as formatted content.
- The layout uses clear typography (comfortable line length, spacing, and hierarchy) so long documents are easy to scan and read.
- If rendering fails for part of the content, the page still shows a safe fallback (e.g. plain text) rather than broken markup or an empty view.
