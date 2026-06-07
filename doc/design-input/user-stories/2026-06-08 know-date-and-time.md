# User Story: Know Date and Time

As a user who references the current date and time without explicitly stating it in a recording, 
I want Nodl to know what date, day of the week, and time it is when the recording got created, 
so that the generated document can mention and reference this data correctly.

## Acceptance Criteria

- When the user says in a recording "Today and right now I am speaking these words", and
  - when the Transformer (Format) is instructed to summarize while mentioning date and time explicitly in the final document, then
  - the output document will reference the exact date and time of the recording and day of the week if needed.
  