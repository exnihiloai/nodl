# User Story: Prevent Screen Lock

As a logged-in smartphone user,
I want Nodl to keep the screen awake while I record,
so my recording is not interrupted by auto-lock.

## Acceptance Criteria

- While recording, Nodl prevents screen lock when the browser supports it.
- If the app is backgrounded or interrupted, Nodl stops and saves captured audio.
- Users never see raw ffmpeg errors for interrupted recordings.

## Additional Information

Yesterday, a user tried Nodl on their iPhone and the screen locked after a short while. When the user unlocked the phone and returned to the app, the following error surfaced on the dashboard:

```
Audio could not be normalized with ffmpeg: ffmpeg version 7.1.4-0+deb13u1 Copyright (c) 2000-2026 the FFmpeg developers built with gcc 14 (Debian 14.2.0-19) configuration: --prefix=/usr --extra-version=0+deb13u1 --toolchain=hardened --libdir=/usr/lib/x86_64-linux-gnu --incdir=/usr/include/x86_64-linux-gnu --arch=amd64 --enable-gpl --disable-stripping --disable-libmfx --disable-omx --enable-gnutls --enable-libaom --enable-libass --enable-libbs2b --enable-libcdio --enable-libcodec2 --enable...
```