# User Story: Audio Recording Accessible in App

As a logged-in user,
I want to play back my voice recordings directly within the app
So that I can quickly listen to what I said and verify the transcript's accuracy.

## Acceptance Criteria

### Audio Player
- Located as a full-width block below the Transcript and Document cards on the recording session page.
- Controls: Start/Stop playback, volume adjustment, and a seekable timeline.

### Bi-directional Sync
- **Text to Audio:** Clicking any word in the transcript jumps the audio playback to that word's timestamp.
- **Audio to Text:** Playing or seeking through the audio highlights the corresponding word/segment in the transcript in real-time.

### Transcript Layout & Speaker Styling
- **Compact Layout:** Shown as a dense, readable paragraph block (not split into one line per sentence).
- **Multiple Speakers (>1):** 
  - Each speaker has a distinct color.
  - Speaker segments are underlined in their respective color (no "Speaker N" labels).
  - The timeline/waveform reflects these speaker colors for their active ranges.
- **Single Speaker (1):** Shown as plain text without speaker colors, underlines, or labels.
