import { Controller } from "@hotwired/stimulus"

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
    "submitButton"
  ]

  connect() {
    this.chunks = []
    this.seconds = 0
    this.mimeOption = this.supportedMimeOption()
    if (!this.mimeOption) {
      this.recordButtonTarget.disabled = true
      this.updateStatus("Recording isn't supported in this browser — use “or upload audio” instead.")
    }
  }

  disconnect() {
    this.stopTimer()
    this.stopStream()
  }

  async start() {
    if (!this.mimeOption) return

    try {
      this.chunks = []
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
      this.sourceKindTarget.value = "microphone"
      this.recordButtonTarget.classList.add("hidden")
      this.stopButtonTarget.classList.remove("hidden")
      this.stopButtonTarget.disabled = false
      this.timerTarget.classList.remove("hidden")
      this.submitButtonTarget.disabled = true
      this.startTimer()
      this.updateStatus("Recording… speak naturally, then press Stop.")
    } catch (_error) {
      this.updateStatus("We couldn't access your microphone. Check your browser permissions and try again.")
      this.stopStream()
    }
  }

  stop() {
    if (!this.recorder || this.recorder.state === "inactive") return

    this.recorder.stop()
    this.stopTimer()
    this.stopStream()
    this.stopButtonTarget.disabled = true
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
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.recordInputTarget.files = transfer.files
    this.uploadInputTarget.value = ""
    this.updateStatus("Got it — structuring your notes…")
    this.submit()
  }

  submit() {
    if (this.submitting) return

    this.submitting = true
    this.submitButtonTarget.disabled = true
    this.element.requestSubmit()
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

  updateStatus(message) {
    this.statusTarget.textContent = message
  }
}
