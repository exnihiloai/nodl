# User Story: Data Encryption

As a user who stores sensitive recordings, transcripts, and documents in Nodl,
I want Nodl to encrypt all my data in transit and at rest,
so that unauthorized parties cannot read or intercept my content if network traffic is observed or storage is accessed without permission.

## Acceptance Criteria

### In transit
- All connections between my browser and Nodl use encrypted transport.
- All connections between Nodl and third-party services that process my data use encrypted transport.
- Live transcription and other real-time channels use encrypted transport.

### At rest
- Data stored in Nodl's primary database is encrypted at rest.
- Uploaded audio files and other user-uploaded blobs are encrypted at rest.
- Encryption covers tenant-scoped user content: recordings, transcripts, documents, and workspace-related settings I provide.

### Operational expectations
- Encryption does not block authorized workspace members from using normal product flows to view and download their own data.
- Nodl documents which categories of data are encrypted and at which layers, without exposing secrets or weakening security.

## Out of Scope

- End-to-end encryption where only I hold the keys and Nodl cannot process transcripts or documents, as this would significantly reduce the usability and user experience of the app.
- Customer-managed encryption keys (bring-your-own-key) in the first release.
- Encrypting operational telemetry or audit logs beyond existing privacy and access controls.

## Edge Cases

- Health and readiness checks remain reachable for operations without breaking encrypted access for users.
- Failed or abandoned uploads do not leave readable sensitive fragments in durable storage.
- Key rotation or credential updates do not permanently lock users out of their data.
