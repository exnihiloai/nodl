# User Story: Delete Recordings

As a user, who creates voice notes using Nodl, I want to be able to delete recordings from the dash board, so that I can remove unwanted recordings and keep my data clean.


## Acceptance Criteria

- The delete function is available for the "Recent" recordings on the dashboard.
- Each entry in that list has an ellipsis menu on the right side of each entry.
  - The menu has a tooltip "Actions".
  - Clicking on the ellipsis icon opens a menu which has one entry "Delete" with a trashcan icon.
  - A confirmation modal asks the user to confirm before the deletion.
- When the user is on mobile: Swiping left will delete the recoding. 
  - A red backdrop and a animated trashcan icon signal the user that they are about to delete something.
  - A user can abort the deletion by stopping the swipe until a stop point or by undoing the swipe.
  - A confirmation modal asks the user to confirm before the deletion.
- When a recording is deleted, it deletes
  - The original audio and all derives audio files.
  - The transcript and any derived information from it.
  - Integrity certificates associated with it.
  - The document associated with it.
  - All other information that is derives from the recording.
  - The deletion is permanent, and not just a soft delete.
