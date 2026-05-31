## User Story

As an engineer, bootstrapping this project, I want a simple and basic first implementation of an audio file to markdown document transformation pipeline, so that I can start experimenting and have the main functions working before creating a user interface for it.

## Acceptance Criteria

- The prototype shall be inspired by the pipeline described in doc/domain/domain-model-pipeline.md
- The pipeline shall be implemented as a modular console application with meaningfully scoped modules.
- The console application receives the path for an audio file as input.
  - .mp3 must work
- The application turns the audio into a transcript that is saved on disk in a working directory.
- The user can organize instructions and templates to construct transformers simply with files and folders in the local filesystem.
- The pipeline uses an LLM to transform the audio transcript given a transformer into a markdown document.

## Additional Information

- A successfull outcome of this user story would be if a fullstack engineer, tasked with creating a user interface for an MVP around the main flow of the application sees the code of the prototype, nodds with the head and thinks this can quite easilly be used.
- For testing the audio file in private/test-data can be used. It might be wise to cut the long audio file to just 30 seconds for a fast and cost efficient iteration and feedback loop.
- Use the existing tech stack and docker container for implementation.
- A research spike helps with technology and model vendor selection: doc/design-input/spikes/spike-pipeline-prototype.md

## Design Decisions 

- The Gemini API shall be used for both text transformation LLM (transformer) and for speech to text (STT).
- We want to use a version of Gemini 3.1 Flash.
- The GEMINI_API_KEY, the GEMINI_PROJECT_NAME, and GEMINI_PROJECT_NUMBER are available in the .env file in folder ./private. A first test already worked and confirmed the gemini API can be invoked.

## Out of Scope

- Snapshotting is not in scope
- Document Identity and Versioning is not in scope
- Templates as PDF or Word is out of scope. text files such as markdown is enough.
