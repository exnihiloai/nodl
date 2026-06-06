import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const MIME_OPTIONS = [
  { mimeType: "audio/webm;codecs=opus", extension: "webm" },
  { mimeType: "audio/ogg;codecs=opus", extension: "ogg" },
  { mimeType: "audio/mp4", extension: "m4a" },
  { mimeType: "audio/aac", extension: "aac" }
]

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
    maxDurationSeconds: Number,
    durationLimitText: String
  }

  connect() {
    this.chunks = []
    this.seconds = 0
    this.smoothedLevel = 0
    this.fastPreviewText = ""
    this.slowPreviewText = ""
    this.isRecording = false
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.mimeOption = this.supportedMimeOption()
    if (!this.mimeOption) {
      this.recordButtonTarget.disabled = true
      this.updateStatus(this.unsupportedTextValue)
    }
  }

  disconnect() {
    this.stopTimer()
    this.stopVisualizer()
    this.stopRealtimeTranscription()
    this.cancelLivePreviewRender()
    this.stopStream()
    this.unsubscribeFromLiveStream()
    if (this.rowObserver) {
      this.rowObserver.disconnect()
      this.rowObserver = null
    }
  }

  async start() {
    if (!this.mimeOption) return

    try {
      this.chunks = []
      this.fastPreviewText = ""
      this.slowPreviewText = ""
      this.sourceKindTarget.value = "microphone"
      this.resetLivePanel()
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
      await this.startRealtimeTranscription()
      this.updateStatus("")
    } catch (_error) {
      this.updateStatus(this.startErrorTextValue)
      this.isRecording = false
      this.stopRealtimeTranscription()
      this.stopStream()
      if (this.hasLivePanelSlotTarget) this.livePanelSlotTarget.classList.add("hidden")
      this.unsubscribeFromLiveStream()
    }
  }

  stop() {
    if (!this.recorder || this.recorder.state === "inactive") return

    this.isRecording = false
    this.stopRealtimeTranscription()
    this.recorder.stop()
    this.stopTimer()
    this.stopVisualizer()
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
    const filename = `microphone-recording-${Date.now()}.${this.mimeOption.extension}`
    const file = new File([blob], filename, { type: this.mimeOption.mimeType })
    this.finalizeRecording(file)
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

  async finalizeRecording(file) {
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

      if (!response.ok) throw new Error("Finalize failed.")
    } catch (_error) {
      this.updateStatus(this.finalizeErrorTextValue)
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
    if (!this.hasStageTarget || !this.stream) return

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

    this.stageTarget.style.setProperty("--voice-level", this.smoothedLevel.toFixed(3))

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
    } else if (data.type === "slow_delta" && data.text) {
      this.slowPreviewText += data.text
      this.scheduleLivePreviewRender()
    } else if (data.type === "error") {
      this.updateStatus(this.previewStoppedTextValue)
      this.stopRealtimeTranscription()
    }
  }

  scheduleLivePreviewRender() {
    if (this.livePreviewFrameId) return

    this.livePreviewFrameId = window.requestAnimationFrame(() => {
      this.livePreviewFrameId = null
      this.renderLivePreview()
    })
  }

  renderLivePreview() {
    const panel = document.getElementById("live_transcript_segments")
    if (!panel) return

    const placeholder = panel.querySelector("[data-live-placeholder]")
    if (placeholder) placeholder.remove()

    let transcript = panel.querySelector("[data-live-transcript-wrapper]")
    if (!transcript) {
      transcript = document.createElement("div")
      transcript.dataset.liveTranscriptWrapper = "true"
      transcript.className = "whitespace-pre-wrap text-sm leading-6"
      transcript.innerHTML = [
        "<span data-live-stable class=\"text-base-content\"></span>",
        "<span data-live-fast class=\"voice-live-text\"></span>"
      ].join("")
      panel.appendChild(transcript)
    }

    const stable = transcript.querySelector("[data-live-stable]")
    const fast = transcript.querySelector("[data-live-fast]")
    const { confirmed, provisional } = this.splitPreview()
    stable.textContent = confirmed
    fast.textContent = provisional
    panel.scrollTop = panel.scrollHeight
  }

  // The slow stream is the refined, confident transcript and is rendered in
  // the solid base text colour; the fast stream runs ahead with a provisional
  // guess. We show the confirmed words solid and only the still-unconfirmed
  // tail of the fast text in the animated voice gradient, so confirmation
  // fills in left-to-right instead of the live line vanishing and reappearing.
  splitPreview() {
    const slowWords = this.tokenizePreview(this.slowPreviewText)
    const fastWords = this.tokenizePreview(this.fastPreviewText)
    const confirmed = (this.slowPreviewText || "").replace(/\s+$/, "")
    const tail = fastWords.slice(slowWords.length)
    const provisional = tail.length ? `${confirmed ? " " : ""}${tail.join(" ")}` : ""
    return { confirmed, provisional }
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
        // Mark it as animated so we don't process it multiple times
        targetRow.dataset.animated = "true"

        const elapsed = Date.now() - (this.stopClickedTime || Date.now())
        const remainingCollapseTime = Math.max(0, 1000 - elapsed)

        // Make sure the row is hidden initially (before repaint)
        targetRow.style.opacity = "0"
        targetRow.style.maxHeight = "0"
        targetRow.style.paddingTop = "0"
        targetRow.style.paddingBottom = "0"

        // Delay the grow animation until the vertical collapse of the live transcript panel finishes
        setTimeout(() => {
          targetRow.style.opacity = ""
          targetRow.style.maxHeight = ""
          targetRow.style.paddingTop = ""
          targetRow.style.paddingBottom = ""
          targetRow.classList.add("dashboard-row-grow")
        }, remainingCollapseTime)

        // We found our target, so disconnect the observer
        this.rowObserver.disconnect()
        this.rowObserver = null
      }
    })

    this.rowObserver.observe(document.body, { childList: true, subtree: true })
  }
}
