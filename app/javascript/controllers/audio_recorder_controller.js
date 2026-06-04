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
    "aura",
    "livePanelSlot",
    "options"
  ]
  static values = {
    createUrl: String,
    workletUrl: String
  }

  connect() {
    this.chunks = []
    this.seconds = 0
    this.smoothedLevel = 0
    this.fastPreviewText = ""
    this.slowPreviewText = ""
    this.fastPreviewSinceStable = ""
    this.isRecording = false
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
    this.stopRealtimeTranscription()
    this.cancelLivePreviewRender()
    this.stopStream()
    this.unsubscribeFromLiveStream()
  }

  async start() {
    if (!this.mimeOption) return

    try {
      this.chunks = []
      this.fastPreviewText = ""
      this.slowPreviewText = ""
      this.fastPreviewSinceStable = ""
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
      await this.startRealtimeTranscription()
      this.updateStatus(this.realtimeSubscription ? "Recording… live preview is streaming." : "Recording… live preview is unavailable in this browser.")
    } catch (_error) {
      this.updateStatus("We couldn't start recording. Check your microphone permissions and try again.")
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
      this.fastPreviewSinceStable += data.text
      this.scheduleLivePreviewRender()
    } else if (data.type === "slow_delta" && data.text) {
      this.slowPreviewText += data.text
      this.fastPreviewSinceStable = ""
      this.scheduleLivePreviewRender()
    } else if (data.type === "error") {
      this.updateStatus("Live preview stopped; the final transcript will still be generated.")
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
        "<span data-live-fast class=\"text-warning\"></span>"
      ].join("")
      panel.appendChild(transcript)
    }

    const stable = transcript.querySelector("[data-live-stable]")
    const fast = transcript.querySelector("[data-live-fast]")
    const stableText = this.slowPreviewText || ""
    stable.textContent = stableText
    fast.textContent = this.provisionalPreviewText()
    panel.scrollTop = panel.scrollHeight
  }

  provisionalPreviewText() {
    if (this.slowPreviewText) return this.fastPreviewSinceStable || ""

    return this.fastPreviewText || ""
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

  selectedTransformerHandle() {
    const field = this.element.querySelector("[name='recording_session[transformer_handle]']")
    return field ? field.value : "default"
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
