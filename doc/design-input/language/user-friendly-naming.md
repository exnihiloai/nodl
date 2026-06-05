# Guide: Use User Friendly Naming and Wording

Users are everyday people: doctors, teachers, lawyers, students, office workers, consultants, founders, and others.

Most users are non-technical. The language in the application should be clear, friendly, and instantly understandable. It should not sound like machine learning infrastructure, software engineering, or internal system design.

The product should describe what the user is doing and what they are getting, not how the system technically works behind the scenes.

## Naming Convention for Transformer

While the terms Transformer and Transformation are technically accurate, they should only be used internally, in code, and in technical documentation.

In the user interface, the recommended term for Transformer is:

Format

A format describes what kind of document the user wants to create from a recording.

Examples:

- Meeting Notes
- Blog Post
- Task List
- Client Summary
- Lecture Notes
- Email Draft
- Medical Note
- Legal Memo

Instead of:

> Choose a transformer.

Use:

> Choose a format.

Instead of:

> Run transformation.

Use:

> Generate document.

## Naming Mapping

| Internal / Technical Term | User-Facing Term | Example UI Wording |
|---|---|---|
| Transformer | Format | Choose a format |
| Transformer handle | Format name | Format name: Meeting Notes |
| Transformation | Generate document | Generate document |
| Transformation run | Document generation | Document generation started |
| Instructions | Guidelines | Add guidelines |
| User-specific instructions | Custom guidelines | Add custom guidelines |
| Default instructions | Default guidelines | Default guidelines help NODL create a clean document |
| Templates | Examples | Add examples |
| Template document | Example document | Add an example document |
| Raw transcript | Transcript | View transcript |
| Audio file | Recording | Listen to recording |
| Recording session | Recording | Your recording is ready |
| Document | Document | Your document is ready |
| Document version | Version | Version 2 created |
| Transformer snapshot | Saved generation settings | Settings used for this version |
| Prompt | Request | NODL uses your guidelines and examples |
| LLM | AI | NODL uses AI to create your document |

## Preferred User Flow

1. Record audio
2. Create transcript
3. Choose a format
4. Generate document
5. Edit or export document

Example:

> Record your thoughts, choose a format, and NODL turns them into a clean document.

## UI Copy Examples

### Choosing a Format

Good:

> Choose a format for your document.

Also good:

> What do you want to create from this recording?

Avoid:

> Select transformer.

> Choose transformation pipeline.

### Creating a Format

Good:

> Create a new format.

Also good:

> Create your own format for documents you use often.

Avoid:

> Create transformer.

### Guidelines

Good:

> Add guidelines for how the document should be written.

Also good:

> Tell NODL what to pay attention to.

Avoid:

> Configure LLM behavior.

### Examples

Good:

> Add examples of documents you like.

Also good:

> Add examples so NODL can follow your preferred structure and style.

Avoid:

> Add few-shot examples.

### Generating

Good:

> Generate document.

Also good:

> Create document.

Avoid:

> Run transformation.

> Execute transformer.

## Example Format Cards

Meeting Notes  
Turns your recording into structured notes with topics, decisions, and action items.

Blog Post  
Turns your recording into a polished article draft.

Task List  
Extracts todos, next steps, owners, and deadlines.

Client Summary  
Creates a clean summary of a client conversation.

Lecture Notes  
Turns a lecture recording into organized study notes.

Email Draft  
Turns spoken thoughts into a clear email draft.

## Short Help Text

Format  
A format tells NODL what kind of document to create.

Guidelines  
Guidelines tell NODL how the document should be written.

Examples  
Examples show NODL what a good result should look like.

Transcript  
The transcript is the written version of your recording.

Document  
The document is the cleaned result created from your recording.

## Rule

Use technical terms internally.  
Use friendly terms in the product.

| Internal | External |
|---|---|
| Transformer | Format |
| Transformation | Generate document |
| Instructions | Guidelines |
| Templates | Examples |