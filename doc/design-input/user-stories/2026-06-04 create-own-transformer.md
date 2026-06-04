# User Story: Create Own Transformer

As a logged in user, who is not satisfied with the default transformer and has specific needs,
I want to create, define, and save my own transformer, so I can select it for use later and instruct the AI how it should transform the audio transcription into a document. 

## Additional Information

- For the technical architecture and specifications, see the [Design Document: Custom Transformers](../custom-transformers/design.md).

## Acceptance Criteria

- A user can give instructions to the AI how the transcribed text shall be transformed in a document and into what kind of documents.
- A user can upload up to 3 example files that the AI receives as additional information and context to understand better what the user wants as output.
  - Supported document types are: .docx (Microsoft Word), .odt (Open Office), .pdf, .md, .txt

## Out of Scope (Future)

- Before the instructions and examples are stored, they are scanned to protect against prompt injection.