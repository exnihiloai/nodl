import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const MIME_OPTIONS = [
  { mimeType: "audio/webm;codecs=opus", extension: "webm" },
  { mimeType: "audio/ogg;codecs=opus", extension: "ogg" },
  { mimeType: "audio/mp4", extension: "m4a" },
  { mimeType: "audio/aac", extension: "aac" }
]
const RECORDING_CHUNK_MS = 1000
// How many words back from the live (right) edge it takes for a provisional
// word to fully age into the default text colour. Colour is keyed to this
// distance-from-edge so confirming a word at the front never recolours the rest.
const LIVE_AGE_STEPS = 4
// Per-character stagger (ms) for the live transcript reveal, so newly arrived
// letters fade in one after another like typing instead of all at once.
const LIVE_CHAR_STAGGER_MS = 31
// After this long with no new transcript delta (i.e. the speaker has paused),
// settle every still-live-coloured word to the confirmed/default colour. The
// trailing words stay accent-coloured only briefly after speech stops.
const LIVE_SETTLE_MS = 1200
// Phantom word: a never-sharp, decorative guess shown past the live edge while
// the user is audibly speaking, to mask recognition latency. It appears once
// the smoothed audio level crosses SHOW and hides once it drops below HIDE
// (hysteresis avoids flicker around the threshold).
const PHANTOM_SHOW_LEVEL = 0.12
const PHANTOM_HIDE_LEVEL = 0.06
// Each phantom picks a random base length N (PHANTOM_BASE_MIN..MAX, all > 3),
// then its displayed length jitters within [N-1, N+2] and re-rolls every
// PHANTOM_LENGTH_INTERVAL_MS so the guess feels alive rather than static.
const PHANTOM_BASE_MIN_CHARS = 4
const PHANTOM_BASE_MAX_CHARS = 8
const PHANTOM_LENGTH_INTERVAL_MS = 1000
// Throttle the audio visualizer/aura loop to ~30fps instead of the display's
// native (usually 60fps) rate. The FFT read + CSS updates every frame are a
// steady CPU/GPU cost over a long recording; halving the rate roughly halves
// that draw with no perceptible difference to the smoothed halo.
const AURA_FRAME_INTERVAL_MS = 1000 / 30

export default class extends Controller {
  static targets = [
    "recordButton",
    "stopButton",
    "status",
    "timer",
    "recordInput",
    "uploadInput",
    "sourceKind",
    "timeZone",
    "submitButton",
    "stage",
    "livePanelSlot",
    "options"
  ]
  static values = {
    createUrl: String,
    workletUrl: String,
    unsupportedText: String,
    startErrorText: String,
    uploadingText: String,
    sessionErrorText: String,
    transcriptLabel: String,
    listeningText: String,
    finalizeErrorText: String,
    previewStoppedText: String,
    wakeLockUnavailableText: String,
    interruptedSavingText: String,
    interruptedNoAudioText: String,
    maxDurationSeconds: Number,
    durationLimitText: String
  }

  connect() {
    this.captureTimeZone()
    this.chunks = []
    this.seconds = 0
    this.smoothedLevel = 0
    this.fastPreviewText = ""
    this.slowPreviewText = ""
    this.isRecording = false
    this.stopContext = { interrupted: false }
    this.handleVisibilityChange = () => this.visibilityChanged()
    this.handlePageHide = () => this.interruptRecording()
    this.handleWakeLockRelease = () => this.wakeLockReleased()
    this.handleTrackMute = () => this.trackMuted()
    this.handleTrackUnmute = () => this.clearTrackMuteTimer()
    this.handleTrackEnded = () => this.interruptRecording()
    this.handleRecorderError = () => this.interruptRecording()
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.mimeOption = this.supportedMimeOption()
    if (!this.mimeOption) {
      this.recordButtonTarget.disabled = true
      this.updateStatus(this.unsupportedTextValue)
    }
  }

  // Record the browser's IANA time zone (e.g. "Europe/Vienna") so generated
  // documents can resolve "today"/"right now" to the speaker's local wall clock
  // instead of the server's UTC. Best-effort: a missing API just falls back to
  // the app default zone server-side.
  captureTimeZone() {
    if (!this.hasTimeZoneTarget) return

    try {
      const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
      if (zone) this.timeZoneTarget.value = zone
    } catch (_error) {
      // Leave the field blank; the server falls back to the default zone.
    }
  }

  disconnect() {
    this.stopTimer()
    this.stopVisualizer()
    this.stopRealtimeTranscription()
    this.cancelLivePreviewRender()
    this.removeRecordingGuards()
    this.releaseWakeLock()
    this.stopStream()
    this.unsubscribeFromLiveStream()
    if (this.rowObserver) {
      this.rowObserver.disconnect()
      this.rowObserver = null
    }
  }

  async start() {
    if (!this.mimeOption) return

    this.chunks = []
    this.fastPreviewText = ""
    this.slowPreviewText = ""
    this.confirmedWordCount = 0
    this.phantomBaseWordCount = -1
    this.sourceKindTarget.value = "microphone"
    this.resetLivePanel()

    // Acquire the microphone BEFORE creating any server-side session. If the
    // user denies/revokes the permission, getUserMedia throws here and we bail
    // without ever creating a row — so a denied prompt can't leave an orphaned
    // "recording" session stuck on the dashboard.
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (_error) {
      this.updateStatus(this.startErrorTextValue)
      return
    }

    try {
      this.liveSession = await this.createRecordingSession()
    } catch (error) {
      this.updateStatus(error.message || this.sessionErrorTextValue)
      this.stopStream()
      return
    }

    try {
      this.subscribeToLiveStream(this.liveSession.live_stream_name)
      this.showLivePanel()

      this.recorder = new MediaRecorder(this.stream, {
        mimeType: this.mimeOption.mimeType,
        audioBitsPerSecond: 64000
      })
      this.recorder.addEventListener("dataavailable", (event) => {
        if (event.data.size > 0) this.chunks.push(event.data)
      })
      this.recorder.addEventListener("stop", () => this.finishRecording())
      this.recorder.addEventListener("error", this.handleRecorderError)
      if (this.chunkedRecordingSupported()) {
        this.recorder.start(RECORDING_CHUNK_MS)
      } else {
        this.recorder.start()
      }
      this.isRecording = true
      this.installRecordingGuards()
      const wakeLockAcquired = await this.requestWakeLock()
      this.recordButtonTarget.classList.add("hidden")
      this.stopButtonTarget.classList.remove("hidden")
      this.stopButtonTarget.disabled = false
      this.timerTarget.classList.remove("hidden")
      this.setOptionsHidden(true)
      this.startTimer()
      this.startVisualizer()
      await this.startRealtimeTranscription()
      if (wakeLockAcquired) this.updateStatus("")
    } catch (_error) {
      this.updateStatus(this.startErrorTextValue)
      this.isRecording = false
      this.stopRealtimeTranscription()
      this.removeRecordingGuards()
      this.releaseWakeLock()
      this.stopStream()
      if (this.hasLivePanelSlotTarget) this.livePanelSlotTarget.classList.add("hidden")
      this.unsubscribeFromLiveStream()
    }
  }

  stop() {
    if (!this.recorder || this.recorder.state === "inactive") return

    this.isRecording = false
    this.stopContext = { interrupted: this.interruptedStopRequested === true }
    this.interruptedStopRequested = false
    this.flushRecorderData()
    this.stopRealtimeTranscription()
    this.recorder.stop()
    this.stopTimer()
    this.stopVisualizer()
    this.removeRecordingGuards()
    this.releaseWakeLock()
    this.stopStream()

    // Disable and show record button, hide stop button and timer
    this.stopButtonTarget.disabled = true
    this.stopButtonTarget.classList.add("hidden")
    this.timerTarget.classList.add("hidden")
    this.recordButtonTarget.classList.remove("hidden")
    this.recordButtonTarget.disabled = true // lock the button for 3 seconds
    this.setOptionsHidden(false)

    this.stopClickedTime = Date.now()

    // Start vertical collapse animation of the live transcript panel slot
    if (this.hasLivePanelSlotTarget) {
      this.livePanelSlotTarget.classList.add("live-panel-collapse")
      
      // After 1 second (1000ms), hide the slot completely and clean up
      setTimeout(() => {
        this.livePanelSlotTarget.classList.add("hidden")
        this.livePanelSlotTarget.classList.remove("live-panel-collapse")
        this.unsubscribeFromLiveStream()
      }, 1000)
    } else {
      this.unsubscribeFromLiveStream()
    }

    // Observe the DOM to animate the newly inserted dashboard list item
    this.startNewRowObserver()

    // Unlock the record button after 3 seconds
    setTimeout(() => {
      this.recordButtonTarget.disabled = false
    }, 3000)
  }

  setOptionsHidden(hidden) {
    if (this.hasOptionsTarget) this.optionsTarget.classList.toggle("hidden", hidden)
  }

  useUpload() {
    if (this.uploadInputTarget.files.length === 0) return

    this.recordInputTarget.value = ""
    this.sourceKindTarget.value = "upload"
    this.updateStatus(this.uploadingTextValue)
    this.submit()
  }

  finishRecording() {
    const blob = new Blob(this.chunks, { type: this.mimeOption.mimeType })
    if (!this.usableRecordingBlob(blob)) {
      this.updateStatus(this.interruptedNoAudioTextValue)
      return
    }

    const filename = `microphone-recording-${Date.now()}.${this.mimeOption.extension}`
    const file = new File([blob], filename, { type: this.mimeOption.mimeType })
    this.finalizeRecording(file, this.stopContext)
  }

  submit() {
    if (this.submitting) return

    this.submitting = true
    if (this.hasSubmitButtonTarget) this.submitButtonTarget.disabled = true
    this.element.requestSubmit()
  }

  async createRecordingSession() {
    const formData = new FormData(this.element)
    formData.delete("recording_session[original_audio]")
    formData.set("recording_session[source_kind]", "microphone")

    const response = await window.fetch(this.createUrlValue, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: formData
    })

    if (!response.ok) {
      const payload = await response.json().catch(() => ({}))
      throw new Error(payload.error || this.sessionErrorTextValue)
    }

    return response.json()
  }

  async finalizeRecording(file, context = { interrupted: false }) {
    if (!this.liveSession) {
      this.finishRecordingWithForm(file)
      return
    }

    const formData = new FormData()
    formData.set("recording_session[source_kind]", "microphone")
    formData.set("recording_session[transformer_handle]", this.selectedTransformerHandle())
    formData.set("recording_session[original_audio]", file)

    try {
      const response = await window.fetch(this.liveSession.finalize_url, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: formData
      })

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}))
        throw new Error(payload.error || this.finalizeErrorTextValue)
      }
    } catch (error) {
      this.updateStatus(error.message || this.finalizeErrorTextValue)
      return
    }

    if (context.interrupted) {
      this.updateStatus(this.interruptedSavingTextValue)
    }
  }

  finishRecordingWithForm(file) {
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.recordInputTarget.files = transfer.files
    this.uploadInputTarget.value = ""
    this.submit()
  }

  supportedMimeOption() {
    if (!window.MediaRecorder || !navigator.mediaDevices) return null

    return MIME_OPTIONS.find((option) => MediaRecorder.isTypeSupported(option.mimeType))
  }

  startTimer() {
    this.seconds = 0
    this.renderTimer()
    this.timerId = window.setInterval(() => {
      this.seconds += 1
      this.renderTimer()
      if (this.maxDurationSecondsValue > 0 && this.seconds >= this.maxDurationSecondsValue) {
        this.updateStatus(this.durationLimitTextValue)
        this.stop()
      }
    }, 1000)
  }

  stopTimer() {
    if (!this.timerId) return

    window.clearInterval(this.timerId)
    this.timerId = null
  }

  flushRecorderData() {
    if (!this.recorder || this.recorder.state === "inactive") return
    if (!this.chunkedRecordingSupported()) return

    try {
      this.recorder.requestData()
    } catch (_error) {
      // Some WebKit builds throw if requestData races with a pending stop.
    }
  }

  usableRecordingBlob(blob) {
    return blob && blob.size > 0
  }

  chunkedRecordingSupported() {
    return this.mimeOption && /audio\/(webm|ogg)/.test(this.mimeOption.mimeType)
  }

  renderTimer() {
    const minutes = Math.floor(this.seconds / 60).toString().padStart(2, "0")
    const seconds = (this.seconds % 60).toString().padStart(2, "0")
    this.timerTarget.textContent = `${minutes}:${seconds}`
  }

  stopStream() {
    if (!this.stream) return

    this.stream.getTracks().forEach((track) => track.stop())
    this.stream = null
  }

  installRecordingGuards() {
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
    window.addEventListener("pagehide", this.handlePageHide)
    this.guardedAudioTracks = this.stream ? this.stream.getAudioTracks() : []
    this.guardedAudioTracks.forEach((track) => {
      track.addEventListener("mute", this.handleTrackMute)
      track.addEventListener("unmute", this.handleTrackUnmute)
      track.addEventListener("ended", this.handleTrackEnded)
    })
  }

  removeRecordingGuards() {
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    window.removeEventListener("pagehide", this.handlePageHide)
    this.clearTrackMuteTimer()
    if (this.guardedAudioTracks) {
      this.guardedAudioTracks.forEach((track) => {
        track.removeEventListener("mute", this.handleTrackMute)
        track.removeEventListener("unmute", this.handleTrackUnmute)
        track.removeEventListener("ended", this.handleTrackEnded)
      })
    }
    this.guardedAudioTracks = []
  }

  visibilityChanged() {
    if (!this.isRecording) return

    if (document.visibilityState === "hidden") {
      this.interruptRecording()
    } else {
      this.requestWakeLock({ reportUnavailable: false })
    }
  }

  trackMuted() {
    this.clearTrackMuteTimer()
    this.trackMuteTimer = window.setTimeout(() => {
      if (this.isRecording) this.interruptRecording()
    }, 1000)
  }

  clearTrackMuteTimer() {
    if (!this.trackMuteTimer) return

    window.clearTimeout(this.trackMuteTimer)
    this.trackMuteTimer = null
  }

  interruptRecording() {
    if (!this.recorder || this.recorder.state === "inactive") return

    this.interruptedStopRequested = true
    this.updateStatus(this.interruptedSavingTextValue)
    this.stop()
  }

  async requestWakeLock({ reportUnavailable = true } = {}) {
    if (this.wakeLock) return true

    if (!("wakeLock" in navigator)) {
      if (reportUnavailable) this.updateStatus(this.wakeLockUnavailableTextValue)
      return false
    }

    try {
      this.wakeLock = await navigator.wakeLock.request("screen")
      this.wakeLock.addEventListener("release", this.handleWakeLockRelease)
      return true
    } catch (_error) {
      if (reportUnavailable) this.updateStatus(this.wakeLockUnavailableTextValue)
      return false
    }
  }

  wakeLockReleased() {
    this.wakeLock = null
    if (!this.isRecording) return

    if (document.visibilityState === "visible") {
      this.requestWakeLock({ reportUnavailable: false })
    } else {
      this.interruptRecording()
    }
  }

  releaseWakeLock() {
    if (!this.wakeLock) return

    const lock = this.wakeLock
    this.wakeLock = null
    lock.removeEventListener("release", this.handleWakeLockRelease)
    lock.release().catch(() => {})
  }

  startVisualizer() {
    if (!this.hasStageTarget || !this.stream) return

    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext
      this.audioContext = new AudioContextClass()
      if (this.audioContext.state === "suspended") this.audioContext.resume()

      this.analyser = this.audioContext.createAnalyser()
      // 256 time-domain samples is plenty for a single heavily-smoothed level;
      // a larger window just burns CPU in the per-frame RMS loop for no visible
      // difference.
      this.analyser.fftSize = 256
      this.analyser.smoothingTimeConstant = 0.85
      this.sourceNode = this.audioContext.createMediaStreamSource(this.stream)
      this.sourceNode.connect(this.analyser)
      this.levelData = new Uint8Array(this.analyser.fftSize)
      this.smoothedLevel = 0
      this.lastAuraFrame = 0
      this.lastVoiceLevel = null

      this.stageTarget.style.setProperty("--voice-level", "0")
      this.stageTarget.classList.add("is-recording")
      this.renderAura()
    } catch (_error) {
      this.stopVisualizer()
    }
  }

  // Pushes a single, heavily smoothed audio level (0..1) onto the stage as
  // --voice-level. All of the premium halo/edge visuals are derived from it in
  // CSS, so the box stays calm when idle and only blooms when the user speaks.
  renderAura() {
    if (!this.analyser) return

    // Throttle to ~30fps: keep the rAF cadence (so it pauses when hidden) but
    // skip the FFT read + style writes on frames that arrive too soon.
    const now = performance.now()
    if (this.lastAuraFrame && now - this.lastAuraFrame < AURA_FRAME_INTERVAL_MS) {
      this.auraFrameId = window.requestAnimationFrame(() => this.renderAura())
      return
    }
    this.lastAuraFrame = now

    this.analyser.getByteTimeDomainData(this.levelData)
    let sumSquares = 0
    for (let i = 0; i < this.levelData.length; i += 1) {
      const sample = (this.levelData[i] - 128) / 128
      sumSquares += sample * sample
    }
    const rms = Math.sqrt(sumSquares / this.levelData.length)
    const target = Math.min(1, rms * 5.5)

    // Fast attack, slow release: the halo pops the instant the user speaks and
    // eases back down, so voice is clearly the thing driving the bloom rather
    // than any ambient animation.
    const coeff = target > this.smoothedLevel ? 0.45 : 0.12
    this.smoothedLevel += (target - this.smoothedLevel) * coeff

    // Only write the custom property when the rounded value actually changes,
    // so steady/silent stretches don't trigger redundant style recalcs.
    const voiceLevel = this.smoothedLevel.toFixed(3)
    if (voiceLevel !== this.lastVoiceLevel) {
      this.stageTarget.style.setProperty("--voice-level", voiceLevel)
      this.lastVoiceLevel = voiceLevel
    }
    this.updatePhantom()

    this.auraFrameId = window.requestAnimationFrame(() => this.renderAura())
  }

  stopVisualizer() {
    this.clearPhantom()
    if (this.auraFrameId) {
      window.cancelAnimationFrame(this.auraFrameId)
      this.auraFrameId = null
    }
    if (this.sourceNode) {
      this.sourceNode.disconnect()
      this.sourceNode = null
    }
    if (this.analyser) {
      this.analyser.disconnect()
      this.analyser = null
    }
    if (this.audioContext) {
      this.audioContext.close()
      this.audioContext = null
    }
    if (this.hasStageTarget) {
      this.stageTarget.classList.remove("is-recording")
      this.stageTarget.style.setProperty("--voice-level", "0")
    }
  }

  async startRealtimeTranscription() {
    if (!this.liveSession || !this.stream || !this.realtimeSupported()) return

    try {
      this.consumer ||= createConsumer()
      this.realtimeSubscription = this.consumer.subscriptions.create(
        {
          channel: this.liveSession.realtime_channel,
          recording_session_id: this.liveSession.id
        },
        {
          received: (data) => this.handleRealtimeMessage(data)
        }
      )

      const AudioContextClass = window.AudioContext || window.webkitAudioContext
      this.pcmContext = new AudioContextClass()
      if (this.pcmContext.state === "suspended") await this.pcmContext.resume()

      await this.pcmContext.audioWorklet.addModule(this.workletUrlValue)
      this.pcmSourceNode = this.pcmContext.createMediaStreamSource(this.stream)
      this.pcmWorkletNode = new AudioWorkletNode(this.pcmContext, "audio-pcm-worklet")
      this.pcmMuteNode = this.pcmContext.createGain()
      this.pcmMuteNode.gain.value = 0
      this.pcmWorkletNode.port.onmessage = (event) => {
        if (!this.realtimeSubscription || !this.isRecording) return

        this.realtimeSubscription.send({
          type: "audio",
          audio: this.arrayBufferToBase64(event.data)
        })
      }
      this.pcmSourceNode.connect(this.pcmWorkletNode)
      this.pcmWorkletNode.connect(this.pcmMuteNode)
      this.pcmMuteNode.connect(this.pcmContext.destination)
    } catch (_error) {
      this.stopRealtimeTranscription()
    }
  }

  realtimeSupported() {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext
    return Boolean(AudioContextClass && "AudioWorkletNode" in window)
  }

  stopRealtimeTranscription() {
    this.cancelLivePreviewRender()
    this.cancelLiveSettle()
    if (this.realtimeSubscription) {
      this.realtimeSubscription.send({ type: "stop" })
      this.consumer.subscriptions.remove(this.realtimeSubscription)
      this.realtimeSubscription = null
    }
    if (this.pcmSourceNode) {
      this.pcmSourceNode.disconnect()
      this.pcmSourceNode = null
    }
    if (this.pcmWorkletNode) {
      this.pcmWorkletNode.disconnect()
      this.pcmWorkletNode.port.onmessage = null
      this.pcmWorkletNode = null
    }
    if (this.pcmMuteNode) {
      this.pcmMuteNode.disconnect()
      this.pcmMuteNode = null
    }
    if (this.pcmContext) {
      this.pcmContext.close()
      this.pcmContext = null
    }
  }

  cancelLivePreviewRender() {
    if (!this.livePreviewFrameId) return

    window.cancelAnimationFrame(this.livePreviewFrameId)
    this.livePreviewFrameId = null
  }

  handleRealtimeMessage(data) {
    if (data.type === "fast_delta" && data.text) {
      this.fastPreviewText += data.text
      this.scheduleLivePreviewRender()
      this.scheduleLiveSettle()
    } else if (data.type === "slow_delta" && data.text) {
      this.slowPreviewText += data.text
      this.scheduleLivePreviewRender()
      this.scheduleLiveSettle()
    } else if (data.type === "error") {
      this.updateStatus(this.previewStoppedTextValue)
      this.stopRealtimeTranscription()
    }
  }

  // Each new transcript delta resets the settle timer; if it ever fires, the
  // speaker has paused, so every shown word is faded to the confirmed colour.
  scheduleLiveSettle() {
    this.cancelLiveSettle()
    this.liveSettleTimer = window.setTimeout(() => {
      this.liveSettleTimer = null
      this.settleLiveWords()
    }, LIVE_SETTLE_MS)
  }

  cancelLiveSettle() {
    if (!this.liveSettleTimer) return

    window.clearTimeout(this.liveSettleTimer)
    this.liveSettleTimer = null
  }

  // Mark every currently shown word as confirmed (default colour). Bumping the
  // confirmed count keeps the model consistent, so words that resume after the
  // pause are still coloured as live while these stay settled.
  settleLiveWords() {
    if (!this.wordEntries) return

    this.confirmedWordCount = this.wordEntries.length
    this.wordEntries.forEach((entry) => {
      entry.el.classList.remove("is-live")
      entry.el.removeAttribute("data-age")
    })
  }

  scheduleLivePreviewRender() {
    if (this.livePreviewFrameId) return

    this.livePreviewFrameId = window.requestAnimationFrame(() => {
      this.livePreviewFrameId = null
      this.renderLivePreview()
    })
  }

  // Word-level reconciler for the live transcript. Each word is its own span
  // that we only ever append to — confirming a word at the front never rewrites
  // or recolours the rest, which kills the colour "wobble" and word-jumping the
  // old whole-string rerender caused. The fast stream supplies the live word
  // sequence; the slow stream's word count drives the confirmed boundary.
  renderLivePreview() {
    const panel = document.getElementById("live_transcript_segments")
    if (!panel) return

    const placeholder = panel.querySelector("[data-live-placeholder]")
    if (placeholder) placeholder.remove()

    let container = panel.querySelector("[data-live-words]")
    if (!container) {
      container = document.createElement("div")
      container.dataset.liveWords = "true"
      container.className = "voice-live-words whitespace-pre-wrap text-sm leading-6"
      panel.appendChild(container)
      this.wordEntries = []
    }
    this.wordEntries ||= []
    this.wordsContainer = container

    const words = this.tokenizePreview(this.fastPreviewText)
    // Confirmed boundary is monotonic (only grows) and never exceeds the words
    // we actually have, so a word can never flip back to provisional.
    const confirmedCount = Math.min(
      Math.max(this.confirmedWordCount || 0, this.tokenizePreview(this.slowPreviewText).length),
      words.length
    )
    this.confirmedWordCount = confirmedCount

    for (let i = 0; i < words.length; i += 1) {
      const word = words[i]
      let entry = this.wordEntries[i]

      if (!entry) {
        const el = document.createElement("span")
        el.className = "voice-word"
        container.appendChild(el)
        entry = this.wordEntries[i] = { el, text: "" }
      }

      if (entry.text !== word) {
        // Pure growth (e.g. "Spielh" → "Spielhälfte") only fades in the new
        // suffix; otherwise rebuild the word. Either way fresh characters ease
        // in via CSS instead of popping.
        if (entry.text && word.startsWith(entry.text)) {
          this.appendLiveFragment(entry.el, word.slice(entry.text.length))
        } else {
          entry.el.textContent = ""
          this.appendLiveFragment(entry.el, word)
        }
        entry.text = word
      }

      const confirmed = i < confirmedCount
      entry.el.classList.toggle("is-live", !confirmed)
      if (confirmed) {
        entry.el.removeAttribute("data-age")
      } else {
        // Colour by distance from the live (right) edge — newest word = accent,
        // ageing toward the default colour. A word only ages as *newer* words
        // arrive, so confirming a word at the front leaves the rest's colour
        // untouched. The CSS colour transition makes the ageing smooth.
        entry.el.dataset.age = String(Math.min(words.length - 1 - i, LIVE_AGE_STEPS))
      }
    }

    // Fast only ever grows, but guard against a shrink so stale spans go away.
    while (this.wordEntries.length > words.length) {
      this.wordEntries.pop().el.remove()
    }

    // Keep the phantom guess trailing the newest real word, and refresh its
    // random shape whenever a real word lands so it reads as a fresh guess.
    if (this.phantomEl && this.phantomEl.parentNode === container) {
      if (words.length !== this.phantomBaseWordCount) {
        this.phantomEl.textContent = this.phantomText(this.randomPhantomLength())
        this.phantomBaseWordCount = words.length
      }
      container.appendChild(this.phantomEl)
    }

    panel.scrollTop = panel.scrollHeight
  }

  // Append text one character at a time so newly arrived letters sharpen out of
  // a blur in sequence (typing feel) rather than the whole chunk popping at
  // once. Each character is its own blurred span with a staggered
  // transition-delay; flipping them all visible on the next frame starts the
  // cascade. Array.from splits by code point so multi-byte characters stay
  // intact.
  //
  // Crucially, once a letter finishes its blur transition we flatten its span
  // back into a plain text node. A 4-minute recording is thousands of letters;
  // leaving each as a filtered, layer-promoted span accumulates thousands of
  // GPU compositing layers that peg the GPU and overheat the device. Flattening
  // means only the handful of currently-animating letters ever carry a filter.
  appendLiveFragment(wordEl, text) {
    if (!text) return

    const spans = Array.from(text).map((char, index) => {
      const span = document.createElement("span")
      span.className = "voice-frag"
      span.textContent = char
      span.style.transitionDelay = `${index * LIVE_CHAR_STAGGER_MS}ms`
      wordEl.appendChild(span)

      const flatten = () => {
        if (span.parentNode) span.replaceWith(document.createTextNode(span.textContent))
      }
      span.addEventListener("transitionend", flatten, { once: true })
      // Fallback if transitionend never fires (interrupted, tab backgrounded,
      // word rebuilt): flatten after the transition's delay + duration + slack.
      window.setTimeout(flatten, index * LIVE_CHAR_STAGGER_MS + 900)

      return span
    })
    window.requestAnimationFrame(() => {
      spans.forEach((span) => span.classList.add("is-in"))
    })
  }

  // The phantom word is a deliberately fake, never-sharp guess shown just past
  // the newest real word while the user is audibly speaking. It masks the
  // recognition latency ("we're already on the word you're saying right now")
  // and disappears in silence to signal that we know nobody is speaking. It is
  // decorative only — aria-hidden, random letters — and never part of the saved
  // transcript. Driven by the smoothed audio level from the visualizer loop.
  updatePhantom() {
    // Use the container cached by renderLivePreview instead of querying the DOM
    // every frame; isConnected guards against it having been replaced.
    const container = this.wordsContainer
    if (!container || !container.isConnected) {
      this.clearPhantom()
      return
    }

    const level = this.smoothedLevel || 0
    const active = this.phantomEl && !this.phantomHideTimer
    const shouldShow = active ? level > PHANTOM_HIDE_LEVEL : level > PHANTOM_SHOW_LEVEL

    if (shouldShow) {
      this.showPhantom(container)
    } else {
      this.hidePhantom()
    }
  }

  showPhantom(container) {
    if (this.phantomHideTimer) {
      window.clearTimeout(this.phantomHideTimer)
      this.phantomHideTimer = null
    }

    if (!this.phantomEl) {
      const el = document.createElement("span")
      el.className = "voice-phantom"
      el.setAttribute("aria-hidden", "true")
      // Pick a fresh base length N for this appearance; the displayed length
      // jitters around it (see randomPhantomLength) and re-rolls every second.
      this.phantomBaseLength = this.randomBetween(PHANTOM_BASE_MIN_CHARS, PHANTOM_BASE_MAX_CHARS)
      el.textContent = this.phantomText(this.randomPhantomLength())
      container.appendChild(el)
      this.phantomEl = el
      this.phantomBaseWordCount = this.wordEntries ? this.wordEntries.length : 0
      window.requestAnimationFrame(() => {
        if (this.phantomEl === el) el.classList.add("is-on")
      })
    } else {
      this.phantomEl.classList.add("is-on")
      if (this.phantomEl !== container.lastChild) container.appendChild(this.phantomEl)
    }

    this.startPhantomLengthTimer()
  }

  // Re-roll the phantom's length once a second so it feels like it is actively
  // re-guessing, rather than a static blob.
  startPhantomLengthTimer() {
    if (this.phantomLengthTimer) return

    this.phantomLengthTimer = window.setInterval(() => {
      if (this.phantomEl) this.phantomEl.textContent = this.phantomText(this.randomPhantomLength())
    }, PHANTOM_LENGTH_INTERVAL_MS)
  }

  stopPhantomLengthTimer() {
    if (!this.phantomLengthTimer) return

    window.clearInterval(this.phantomLengthTimer)
    this.phantomLengthTimer = null
  }

  hidePhantom() {
    if (!this.phantomEl || this.phantomHideTimer) return

    this.stopPhantomLengthTimer()
    const el = this.phantomEl
    el.classList.remove("is-on")
    this.phantomHideTimer = window.setTimeout(() => {
      el.remove()
      if (this.phantomEl === el) this.phantomEl = null
      this.phantomHideTimer = null
    }, 240)
  }

  clearPhantom() {
    this.stopPhantomLengthTimer()
    if (this.phantomHideTimer) {
      window.clearTimeout(this.phantomHideTimer)
      this.phantomHideTimer = null
    }
    if (this.phantomEl) {
      this.phantomEl.remove()
      this.phantomEl = null
    }
  }

  randomBetween(min, max) {
    return min + Math.floor(Math.random() * (max - min + 1))
  }

  // Length jitters within [N-1, N+2] around the base N, floored at 3 so it
  // always reads as a word.
  randomPhantomLength() {
    const base = this.phantomBaseLength || PHANTOM_BASE_MIN_CHARS
    return Math.max(3, this.randomBetween(base - 1, base + 2))
  }

  // Plausible-looking but random word: alternating consonants/vowels so the
  // blurred silhouette reads like a real word rather than noise.
  phantomText(length) {
    const consonants = "bcdfghklmnprstvwz"
    const vowels = "aeiou"
    let text = ""
    for (let i = 0; i < length; i += 1) {
      const set = i % 2 === 0 ? consonants : vowels
      text += set[Math.floor(Math.random() * set.length)]
    }
    return text
  }

  tokenizePreview(text) {
    const trimmed = (text || "").trim()
    return trimmed ? trimmed.split(/\s+/) : []
  }

  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    for (let i = 0; i < bytes.byteLength; i += 1) {
      binary += String.fromCharCode(bytes[i])
    }
    return window.btoa(binary)
  }

  updateStatus(message) {
    this.statusTarget.textContent = message
  }

  subscribeToLiveStream(signedStreamName) {
    if (!signedStreamName || !window.customElements) return

    this.unsubscribeFromLiveStream()
    this.liveStreamSource = document.createElement("turbo-cable-stream-source")
    this.liveStreamSource.setAttribute("channel", "Turbo::StreamsChannel")
    this.liveStreamSource.setAttribute("signed-stream-name", signedStreamName)
    document.body.appendChild(this.liveStreamSource)
  }

  unsubscribeFromLiveStream() {
    if (!this.liveStreamSource) return

    this.liveStreamSource.remove()
    this.liveStreamSource = null
  }

  showLivePanel() {
    if (this.hasLivePanelSlotTarget) this.livePanelSlotTarget.classList.remove("hidden")
  }

  resetLivePanel() {
    const statusContainer = document.getElementById("live_transcript_status")
    if (statusContainer) {
      statusContainer.innerHTML = `
        <div class="flex items-center justify-between gap-3">
          <h2 class="text-sm font-semibold">${this.transcriptLabelValue}</h2>
        </div>
      `
    }

    const segmentsContainer = document.getElementById("live_transcript_segments")
    if (segmentsContainer) {
      segmentsContainer.innerHTML = `<p class="text-sm italic text-base-content/60" data-live-placeholder>${this.listeningTextValue}</p>`
    }

    // The word container lives inside the segments markup we just replaced, so
    // drop the stale references before the next render rebuilds them.
    this.wordEntries = null
    this.wordsContainer = null
    this.confirmedWordCount = 0
    this.cancelLiveSettle()
    this.clearPhantom()
  }

  selectedTransformerHandle() {
    const field = this.element.querySelector("[name='recording_session[transformer_handle]']")
    return field ? field.value : "default"
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  startNewRowObserver() {
    if (!this.liveSession || !this.liveSession.id) return

    if (this.rowObserver) {
      this.rowObserver.disconnect()
    }

    const targetId = `dashboard_row_recording_session_${this.liveSession.id}`

    this.rowObserver = new MutationObserver((mutations) => {
      const targetRow = document.getElementById(targetId)
      if (targetRow && !targetRow.dataset.animated) {
        const surface = targetRow.querySelector("[data-swipe-delete-target='surface']")
        if (!surface) return

        // Mark it as animated so we don't process it multiple times
        targetRow.dataset.animated = "true"

        const elapsed = Date.now() - (this.stopClickedTime || Date.now())
        const remainingCollapseTime = Math.max(0, 1000 - elapsed)

        // Make sure the surface is hidden initially (before repaint)
        surface.style.opacity = "0"
        surface.style.maxHeight = "0"
        surface.style.paddingTop = "0"
        surface.style.paddingBottom = "0"

        // Delay the grow animation until the vertical collapse of the live transcript panel finishes
        setTimeout(() => {
          surface.style.opacity = ""
          surface.style.maxHeight = ""
          surface.style.paddingTop = ""
          surface.style.paddingBottom = ""
          surface.classList.add("dashboard-row-grow")
        }, remainingCollapseTime)

        // We found our target, so disconnect the observer
        this.rowObserver.disconnect()
        this.rowObserver = null
      }
    })

    this.rowObserver.observe(document.body, { childList: true, subtree: true })
  }
}
