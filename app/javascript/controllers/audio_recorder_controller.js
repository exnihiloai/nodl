import { Controller } from "@hotwired/stimulus"

const MIME_OPTIONS = [
  { mimeType: "audio/webm;codecs=opus", extension: "webm" },
  { mimeType: "audio/ogg;codecs=opus", extension: "ogg" },
  { mimeType: "audio/mp4", extension: "m4a" },
  { mimeType: "audio/aac", extension: "aac" }
]

const SEGMENT_MIN_MS = 500
const SEGMENT_MAX_MS = 4000
const SEGMENT_SILENCE_HANGOVER_MS = 200
const SEGMENT_SPEECH_LEVEL = 0.05

export default class extends Controller {
  static targets = [
    "recordButton",
    "stopButton",
    "status",
    "timer",
    "recordInput",
    "uploadInput",
    "sourceKind",
    "submitButton",
    "aura",
    "livePanelSlot",
    "options"
  ]
  static values = {
    createUrl: String
  }

  connect() {
    this.chunks = []
    this.seconds = 0
    this.smoothedLevel = 0
    this.segmentIndex = 0
    this.isRecording = false
    this.segmentStopping = false
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.mimeOption = this.supportedMimeOption()
    if (!this.mimeOption) {
      this.recordButtonTarget.disabled = true
      this.updateStatus("Recording isn't supported in this browser — use “or upload audio” instead.")
    }
  }

  disconnect() {
    this.stopTimer()
    this.stopVisualizer()
    this.stopSegmentRecorder({ forceUpload: false, restart: false })
    this.stopStream()
    this.unsubscribeFromLiveStream()
  }

  async start() {
    if (!this.mimeOption) return

    try {
      this.chunks = []
      this.segmentIndex = 0
      this.segmentStopping = false
      this.sourceKindTarget.value = "microphone"
      this.liveSession = await this.createRecordingSession()
      this.subscribeToLiveStream(this.liveSession.live_stream_name)
      this.showLivePanel()

      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.recorder = new MediaRecorder(this.stream, {
        mimeType: this.mimeOption.mimeType,
        audioBitsPerSecond: 64000
      })
      this.recorder.addEventListener("dataavailable", (event) => {
        if (event.data.size > 0) this.chunks.push(event.data)
      })
      this.recorder.addEventListener("stop", () => this.finishRecording())
      this.recorder.start()
      this.isRecording = true
      this.recordButtonTarget.classList.add("hidden")
      this.stopButtonTarget.classList.remove("hidden")
      this.stopButtonTarget.disabled = false
      this.timerTarget.classList.remove("hidden")
      this.setOptionsHidden(true)
      this.startTimer()
      this.startVisualizer()
      this.updateStatus("Recording… speak naturally, then press Stop.")
    } catch (_error) {
      this.updateStatus("We couldn't start recording. Check your microphone permissions and try again.")
      this.isRecording = false
      this.stopStream()
      if (this.hasLivePanelSlotTarget) this.livePanelSlotTarget.classList.add("hidden")
      this.unsubscribeFromLiveStream()
    }
  }

  stop() {
    if (!this.recorder || this.recorder.state === "inactive") return

    this.isRecording = false
    this.stopSegmentRecorder({ forceUpload: true, restart: false, reason: "stop" })
    this.recorder.stop()
    this.stopTimer()
    this.stopVisualizer()
    this.stopStream()
    this.resetRecordingControls()
  }

  resetRecordingControls() {
    this.stopButtonTarget.disabled = true
    this.stopButtonTarget.classList.add("hidden")
    this.timerTarget.classList.add("hidden")
    this.recordButtonTarget.classList.remove("hidden")
    this.setOptionsHidden(false)
  }

  setOptionsHidden(hidden) {
    if (this.hasOptionsTarget) this.optionsTarget.classList.toggle("hidden", hidden)
  }

  useUpload() {
    if (this.uploadInputTarget.files.length === 0) return

    this.recordInputTarget.value = ""
    this.sourceKindTarget.value = "upload"
    this.updateStatus("Uploading your audio…")
    this.submit()
  }

  finishRecording() {
    const blob = new Blob(this.chunks, { type: this.mimeOption.mimeType })
    const filename = `microphone-recording-${Date.now()}.${this.mimeOption.extension}`
    const file = new File([blob], filename, { type: this.mimeOption.mimeType })
    this.finalizeRecording(file)
  }

  submit() {
    if (this.submitting) return

    this.submitting = true
    this.submitButtonTarget.disabled = true
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
      throw new Error(payload.error || "Recording session could not be created.")
    }

    return response.json()
  }

  async finalizeRecording(file) {
    if (!this.liveSession) {
      this.finishRecordingWithForm(file)
      return
    }

    const formData = new FormData()
    formData.set("recording_session[source_kind]", "microphone")
    formData.set("recording_session[transformer_handle]", this.selectedTransformerHandle())
    formData.set("recording_session[original_audio]", file)

    this.updateStatus("Got it — finalizing the clean transcript and document…")

    try {
      const response = await window.fetch(this.liveSession.finalize_url, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: formData
      })

      if (!response.ok) throw new Error("Finalize failed.")
      // The live panel now owns finalizing/done status; clear the transient line.
      this.updateStatus("")
    } catch (_error) {
      this.updateStatus("We couldn't finalize this recording. Please try recording again.")
    }
  }

  finishRecordingWithForm(file) {
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.recordInputTarget.files = transfer.files
    this.uploadInputTarget.value = ""
    this.updateStatus("Got it — structuring your notes…")
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
    }, 1000)
  }

  stopTimer() {
    if (!this.timerId) return

    window.clearInterval(this.timerId)
    this.timerId = null
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

  startVisualizer() {
    if (!this.hasAuraTarget || !this.stream) return

    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext
      this.audioContext = new AudioContextClass()
      if (this.audioContext.state === "suspended") this.audioContext.resume()

      this.analyser = this.audioContext.createAnalyser()
      this.analyser.fftSize = 1024
      this.analyser.smoothingTimeConstant = 0.85
      this.sourceNode = this.audioContext.createMediaStreamSource(this.stream)
      this.sourceNode.connect(this.analyser)
      this.levelData = new Uint8Array(this.analyser.fftSize)
      this.smoothedLevel = 0

      this.auraTarget.classList.remove("hidden")
      this.auraTarget.classList.add("is-active")
      this.renderAura()
    } catch (_error) {
      // Visualization is non-essential; recording continues without it.
      this.stopVisualizer()
    }
  }

  renderAura() {
    if (!this.analyser) return

    this.analyser.getByteTimeDomainData(this.levelData)
    let sumSquares = 0
    for (let i = 0; i < this.levelData.length; i += 1) {
      const sample = (this.levelData[i] - 128) / 128
      sumSquares += sample * sample
    }
    const rms = Math.sqrt(sumSquares / this.levelData.length)
    const target = Math.min(1, rms * 4)
    this.handleVoiceActivity(target)

    // Heavy exponential smoothing: gentle, breathing response — no nervous motion.
    this.smoothedLevel += (target - this.smoothedLevel) * 0.08

    if (this.reduceMotion) {
      this.auraTarget.style.setProperty("--aura-scale", "1")
      this.auraTarget.style.setProperty("--aura-opacity", (0.18 + this.smoothedLevel * 0.3).toFixed(3))
    } else {
      this.auraTarget.style.setProperty("--aura-scale", (0.85 + this.smoothedLevel * 0.5).toFixed(3))
      this.auraTarget.style.setProperty("--aura-opacity", (0.25 + this.smoothedLevel * 0.5).toFixed(3))
    }

    this.auraFrameId = window.requestAnimationFrame(() => this.renderAura())
  }

  stopVisualizer() {
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
    if (this.hasAuraTarget) {
      this.auraTarget.classList.add("hidden")
      this.auraTarget.classList.remove("is-active")
      this.auraTarget.style.setProperty("--aura-opacity", "0")
    }
  }

  updateStatus(message) {
    this.statusTarget.textContent = message
  }

  handleVoiceActivity(level) {
    if (!this.isRecording || !this.liveSession) return

    const now = Date.now()
    if (level >= SEGMENT_SPEECH_LEVEL) {
      this.lastSpeechAt = now
      if (!this.segmentRecorder && !this.segmentStopping) {
        this.startSegmentRecorder()
      }
      this.segmentHadSpeech = true
    }

    if (!this.segmentRecorder || this.segmentRecorder.state !== "recording") return

    const segmentAge = now - this.segmentStartedAt
    const silenceAge = now - (this.lastSpeechAt || now)
    if (this.segmentHadSpeech && segmentAge >= SEGMENT_MIN_MS && silenceAge >= SEGMENT_SILENCE_HANGOVER_MS) {
      this.stopSegmentRecorder({ forceUpload: true, restart: false, reason: "silence" })
    } else if (segmentAge >= SEGMENT_MAX_MS) {
      this.stopSegmentRecorder({ forceUpload: this.segmentHadSpeech, restart: this.isRecording, reason: "max_length" })
    }
  }

  startSegmentRecorder() {
    if (!this.stream || !window.MediaRecorder) return

    try {
      this.segmentChunks = []
      this.segmentHadSpeech = false
      this.segmentStopping = false
      this.segmentStartedAt = Date.now()
      this.segmentPerformanceStartedAt = window.performance.now()
      this.segmentRecorder = new MediaRecorder(this.stream, {
        mimeType: this.mimeOption.mimeType,
        audioBitsPerSecond: 64000
      })
      this.segmentRecorder.addEventListener("dataavailable", (event) => {
        if (event.data.size > 0) this.segmentChunks.push(event.data)
      })
      this.segmentRecorder.addEventListener("stop", () => this.finishSegment())
      this.segmentRecorder.start()
      this.logLiveTiming("segment_started", { index: this.segmentIndex })
    } catch (_error) {
      this.segmentRecorder = null
    }
  }

  stopSegmentRecorder({ forceUpload, restart, reason = "manual" }) {
    if (!this.segmentRecorder || this.segmentRecorder.state === "inactive" || this.segmentStopping) return

    this.segmentStopping = true
    this.segmentForceUpload = forceUpload
    this.segmentRestartAfterStop = restart
    this.segmentStopReason = reason
    this.logLiveTiming("segment_stopping", {
      index: this.segmentIndex,
      reason,
      ageMs: Math.round(Date.now() - this.segmentStartedAt)
    })
    this.segmentRecorder.stop()
  }

  finishSegment() {
    const shouldUpload = this.segmentForceUpload && this.segmentHadSpeech && this.segmentChunks.length > 0
    const shouldRestart = this.segmentRestartAfterStop
    const stopReason = this.segmentStopReason
    const segmentDurationMs = this.segmentPerformanceStartedAt
      ? Math.round(window.performance.now() - this.segmentPerformanceStartedAt)
      : null
    this.segmentForceUpload = false
    this.segmentRestartAfterStop = false
    this.segmentStopReason = null

    if (shouldUpload) {
      const blob = new Blob(this.segmentChunks, { type: this.mimeOption.mimeType })
      this.logLiveTiming("segment_ready", {
        index: this.segmentIndex,
        reason: stopReason,
        durationMs: segmentDurationMs,
        bytes: blob.size
      })
      this.uploadSegment(blob, this.segmentIndex)
      this.segmentIndex += 1
    } else {
      this.logLiveTiming("segment_discarded", {
        index: this.segmentIndex,
        reason: stopReason,
        durationMs: segmentDurationMs
      })
    }

    this.segmentChunks = []
    this.segmentRecorder = null
    this.segmentHadSpeech = false
    this.segmentStopping = false
    this.segmentPerformanceStartedAt = null

    if (shouldRestart) this.startSegmentRecorder()
  }

  uploadSegment(blob, index) {
    if (!this.liveSession || blob.size === 0) return

    const formData = new FormData()
    const filename = `recording-segment-${index}.${this.mimeOption.extension}`
    formData.set("index", index.toString())
    formData.set("segment", new File([blob], filename, { type: this.mimeOption.mimeType }))

    const uploadStartedAt = window.performance.now()
    this.logLiveTiming("segment_upload_started", { index, bytes: blob.size })

    window.fetch(this.liveSession.segments_url, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: formData
    }).then((response) => {
      this.logLiveTiming("segment_upload_finished", {
        index,
        status: response.status,
        durationMs: Math.round(window.performance.now() - uploadStartedAt)
      })
    }).catch((error) => {
      this.logLiveTiming("segment_upload_failed", {
        index,
        durationMs: Math.round(window.performance.now() - uploadStartedAt),
        error: error.message
      })
    })
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

  selectedTransformerHandle() {
    const field = this.element.querySelector("[name='recording_session[transformer_handle]']")
    return field ? field.value : "default"
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  logLiveTiming(event, details = {}) {
    if (!window.console?.info) return

    window.console.info("[live-transcript]", event, {
      sessionId: this.liveSession?.id,
      ...details
    })
  }
}
