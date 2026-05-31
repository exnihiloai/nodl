# NODL Prototype Technology Spike

## Executive recommendation

For the first prototype, I would build it **Ruby-only inside the Rails Docker container**.

Use:

* **Ruby CLI / console application**
* **Gemini Developer API via REST**
* **Gemini for both transcription and markdown transformation**
* **Filesystem-based transformers**
* **No Python unless local Whisper becomes necessary**
* **No heavy framework, no queue, no DB needed for the first prototype**

This is the simplest path that matches your constraints: cheap, fast, Google-first, German-capable enough to test, and easy for a Rails/fullstack engineer to understand.

The key architectural decision: keep **transcription** and **document transformation** as separate modules, even if both are initially implemented through Gemini. That keeps the prototype simple now, but lets you later replace only the transcriber with Google Cloud Speech-to-Text or another ASR provider.

---

# 1. Transcription options

## Option A — Gemini Developer API for transcription

This is my recommended prototype choice.

Gemini supports audio input and can generate text responses from audio. Google’s audio docs show uploading an `.mp3` file and calling `generateContent` with that file. The docs also include a REST example, which matters because Ruby is not one of the first-class Gemini SDK languages. ([Google AI for Developers][1])

Why it fits:

* Uses your existing Gemini API key.
* Supports `.mp3`.
* No second provider.
* No Python.
* Very low integration overhead.
* Good enough to validate the pipeline.
* Cheap for short test clips.

Downside:

* Gemini is not a dedicated speech-to-text engine.
* Quality for German dictation needs to be tested.
* Not the strongest production compliance story if using the Developer API directly.

My take: **start here**. Do not over-optimize before you know the actual quality bottleneck.

---

## Option B — Google Cloud Speech-to-Text V2 / Chirp 3

This is the better later production-grade STT option.

Google’s Cloud Speech-to-Text offers dedicated transcription models, including Chirp 3, which Google describes as an enhanced multilingual transcription model. It is the more serious ASR product compared to using Gemini as a general multimodal model. ([Google Cloud Documentation][2])

Why it matters later:

* Better ASR-specific feature set.
* More control over recognition settings.
* More natural path for production transcription.
* Google documents EU regional endpoints for Speech-to-Text. ([Google Cloud Documentation][3])

Downside for the prototype:

* More setup.
* More Google Cloud config.
* Possibly Cloud Storage workflows for longer files.
* Less KISS.

My take: **do not start here unless Gemini transcription is bad**. Keep the interface clean so this can replace the Gemini transcriber later.

---

## Option C — Deepgram

Deepgram is worth knowing as a fallback, especially because it has EU-oriented options and strong speech-to-text positioning. Its pricing page exposes STT products and EU endpoint information. ([Deepgram][4])

Why it could be interesting:

* Strong speech-to-text provider.
* EU endpoint story.
* Often fast and developer-friendly.

Why I would not start with it:

* It adds a second AI provider.
* You already prefer Google.
* It complicates the early architecture without clear need.

My take: good fallback, not the default.

---

## Option D — local faster-whisper

`faster-whisper` is a Python-based local transcription option using CTranslate2. It can transcribe audio files and is attractive if you want local processing or no variable API cost. ([GitHub][5])

Why it is tempting:

* Local.
* No cloud audio upload.
* No per-minute API cost.
* Full control.

Why I would avoid it for now:

* Adds Python.
* Adds model downloads.
* Adds runtime complexity.
* May add CPU/GPU performance headaches.
* Makes the Rails container less clean.

My take: only use this if cloud transcription becomes unacceptable for privacy, cost, or quality reasons.

---

# 2. LLM transformation option

Use **Gemini** for transcript-to-markdown transformation.

This is the easy decision. Your transformation step is exactly the kind of task Gemini is suitable for: take messy text, apply instructions and templates, output structured Markdown.

For the first model, use the cheapest/fastest Gemini model that gives acceptable quality. The research pointed toward a Flash/Flash-Lite style model for cheap iteration. Google’s pricing page should be checked at implementation time because model names and prices can change. ([Google AI for Developers][6])

Recommended initial setup:

```text
TRANSCRIBER_MODEL=gemini-2.5-flash-lite or current cheap Gemini Flash model
TRANSFORMER_MODEL=gemini-2.5-flash-lite or current cheap Gemini Flash model
```

Use stable model IDs, not `latest`, once you settle on the prototype.

Upgrade path:

```text
Cheap model for transcription/transform first.
If markdown quality is weak, upgrade only the transformation model.
If transcription quality is weak, replace only the transcriber.
```

---

# 3. Ruby vs Python

My recommendation: **Ruby-only for now**.

Reason:

* The future app is Rails.
* The prototype should be understandable to the future fullstack engineer.
* Gemini can be called via REST.
* Ruby standard library is enough for CLI, filesystem, and HTTP.
* Adding Python now does not buy enough to justify the complexity.

Important detail: Google’s Gemini SDK documentation lists official SDKs for languages such as Python, JavaScript, Go, Java, and C#, but not Ruby as a first-class SDK. However, the docs show REST usage, so Ruby can call Gemini directly over HTTP. ([Google AI for Developers][1])

So the Ruby implementation should use:

* `OptionParser` for CLI arguments
* `FileUtils` for working-directory creation
* `Net::HTTP` or a tiny HTTP gem if you prefer
* plain files/folders for transformers
* JSON parsing with Ruby stdlib

I would not add Python until there is a concrete need, like local `faster-whisper`.

---

# 4. EU production implications

For the prototype, Gemini Developer API is fine.

For production, I would be more careful.

The clean Google production path is probably:

```text
Transformation:
Vertex AI / Gemini Enterprise Agent Platform with EU-appropriate region

Transcription:
Google Cloud Speech-to-Text with EU regional endpoint
```

Google documents data residency behavior for Gemini Enterprise Agent Platform / Vertex-style usage, including the idea that data residency and ML processing depend on the selected location and feature. ([Google Cloud Documentation][7])

For Speech-to-Text, Google documents supported regional endpoints, including EU-related endpoints. ([Google Cloud Documentation][3])

My take:

* **Prototype:** Gemini Developer API is okay.
* **Production MVP with sensitive data:** move toward Vertex AI/Gemini Enterprise + Cloud Speech-to-Text EU endpoint.
* **Do not promise EU residency from the prototype setup.**

---

# 5. Recommended prototype architecture

Keep it stupid simple, but modular.

Suggested structure:

```text
bin/
  nodl

lib/nodl/
  cli.rb
  pipeline.rb

  audio_input.rb
  working_directory.rb

  transcription/
    transcriber.rb
    gemini_transcriber.rb

  transformation/
    transformer_repository.rb
    document_transformer.rb
    gemini_document_transformer.rb

  providers/
    gemini_client.rb

transformers/
  default/
    instructions.md
    templates/
      example.md

work/
  sessions/
    <timestamp-or-id>/
      audio.mp3
      transcript.md
      document.md
      metadata.json
```

Basic command:

```text
bin/nodl path/to/audio.mp3 --transformer default
```

I would support only one happy-path command first:

```text
audio.mp3 -> transcript.md -> document.md
```

Later you can split it into:

```text
nodl transcribe ...
nodl transform ...
nodl run ...
```

But for the first prototype, one command is better.

---

# 6. Filesystem transformer format

Use this:

```text
transformers/
  meeting-notes/
    instructions.md
    templates/
      example-1.md
      example-2.md
```

No YAML config unless needed.

The transformer handle is the folder name:

```text
meeting-notes
```

That is KISS and maps nicely to the domain model.

The prompt can be constructed like this:

```text
Default system instructions
+
Transformer instructions.md
+
All templates/*.md
+
Raw transcript
```

For now, only Markdown/plain text templates. PDF and Word are out of scope.

---

# 7. Concrete first implementation choice

Final recommendation:

```text
Language:
Ruby

Runtime:
Rails Docker container

Transcription:
Gemini Developer API via REST

Transformation:
Gemini Developer API via REST

Audio input:
.mp3

Transformer storage:
local folders and markdown files

Working output:
local work/ directory

Production upgrade path:
Google Cloud Speech-to-Text EU endpoint + Vertex AI/Gemini Enterprise in EU-compatible region
```

This is the cleanest low-cost prototype path.

The only thing I am not 100% sure about is whether Gemini transcription quality will be good enough for your German dictation use case. The docs confirm Gemini can process audio and generate text, but they do not prove quality for your specific audio style. That should be the first thing tested with a 30-second German clip.

[1]: https://ai.google.dev/gemini-api/docs/audio "Gemini API  |  Google AI for Developers"
[2]: https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3 "Chirp 3 Transcription: Enhanced multilingual accuracy  |  Cloud Speech-to-Text  |  Google Cloud Documentation"
[3]: https://docs.cloud.google.com/speech-to-text/docs/v1/endpoints "Supported regional endpoints  |  Cloud Speech-to-Text  |  Google Cloud Documentation"
[4]: https://deepgram.com/pricing "Deepgram Pricing | Scalable Speech-to-Text, Text-to-Speech & Voice Agent APIs"
[5]: https://github.com/SYSTRAN/faster-whisper "GitHub - SYSTRAN/faster-whisper: Faster Whisper transcription with CTranslate2 · GitHub"
[6]: https://ai.google.dev/gemini-api/docs/pricing "Gemini Developer API pricing  |  Gemini API  |  Google AI for Developers"
[7]: https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/data-residency "Data residency  |  Gemini Enterprise Agent Platform  |  Google Cloud Documentation"
