# User Story: Live Transcription with Speaker Attribution

As a logged in user into Nodl, who records audio to turn it into a document,
I want to
  - see the transcript appear live while I am still recording,
  - still upload an audio file and have it transcribed after the fact,
  - have multiple speakers told apart and labelled (Person 1, Person 2, Person 3, …),
So that recording feels responsive, and conversations like interviews or podcasts come back attributed to who said what.

## Acceptance Criteria

- While recording from the microphone, a live transcript builds up on screen within a few seconds of speaking.
- The live transcript is a preview: when I stop, it is replaced by a clean, final transcript.
- Uploading an audio file still works and produces a transcript (no live needed).
- When a recording has multiple speakers, the final transcript attributes each part to a numbered speaker.
- A single-speaker recording has no speaker labels.
- If live transcription fails for any reason, I still get my final transcript and document.
- The user interface shall be in english.

## Notes

- Design and build approach: [../live-transcription/design.md](../live-transcription/design.md), [../live-transcription/implementation-plan.md](../live-transcription/implementation-plan.md).
