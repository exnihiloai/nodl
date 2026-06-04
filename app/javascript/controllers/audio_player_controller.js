import { Controller } from "@hotwired/stimulus"

// Audio player for a completed recording session: waveform (speaker-tinted),
// play/seek/volume, and two-way sync with the transcript — click a word to
// seek, and the spoken word is highlighted as it plays.
export default class extends Controller {
  static targets = [
    "audio",
    "playButton",
    "playIcon",
    "pauseIcon",
    "waveform",
    "currentTime",
    "duration",
    "volume",
    "transcript",
    "cue"
  ]
  static values = {
    audioUrl: String,
    multiSpeaker: Boolean,
    colors: Object,
    timeline: Array,
    peaks: Array,
    duration: Number
  }

  connect() {
    if (!this.hasAudioTarget) return

    // Prefer server-precomputed peaks/duration: the waveform draws on the first
    // frame with no audio download or decode. Fall back to client-side decoding
    // only for older recordings that have no stored peaks.
    this.peaks = this.peaksValue.length > 0 ? this.peaksValue : null
    this.duration = this.durationValue > 0 ? this.durationValue : 0
    this.activeCue = null
    this.cues = this.cueTargets
      .map((el) => ({ el, start: parseFloat(el.dataset.start), end: parseFloat(el.dataset.end) }))
      .filter((cue) => Number.isFinite(cue.start))
      .sort((a, b) => a.start - b.start)
    this.scrollContainer = this.hasTranscriptTarget ? this.transcriptTarget.closest(".overflow-y-auto") : null

    this.onMetadata = () => this.handleMetadata()
    this.onTimeUpdate = () => this.handleTimeUpdate()
    this.onPlayState = () => this.syncPlayIcon()

    this.audioTarget.addEventListener("loadedmetadata", this.onMetadata)
    this.audioTarget.addEventListener("timeupdate", this.onTimeUpdate)
    this.audioTarget.addEventListener("play", this.onPlayState)
    this.audioTarget.addEventListener("pause", this.onPlayState)
    this.audioTarget.addEventListener("ended", this.onPlayState)

    if (this.hasVolumeTarget) this.audioTarget.volume = parseFloat(this.volumeTarget.value)

    this.resizeObserver = new ResizeObserver(() => this.renderWaveform())
    this.resizeObserver.observe(this.waveformTarget)

    if (this.hasDurationTarget && this.duration > 0) this.durationTarget.textContent = this.formatTime(this.duration)
    if (this.audioTarget.readyState >= 1) this.handleMetadata()

    if (this.peaks) this.renderWaveform()
    else this.loadWaveform()
  }

  disconnect() {
    if (!this.hasAudioTarget) return

    this.audioTarget.removeEventListener("loadedmetadata", this.onMetadata)
    this.audioTarget.removeEventListener("timeupdate", this.onTimeUpdate)
    this.audioTarget.removeEventListener("play", this.onPlayState)
    this.audioTarget.removeEventListener("pause", this.onPlayState)
    this.audioTarget.removeEventListener("ended", this.onPlayState)
    if (this.resizeObserver) this.resizeObserver.disconnect()
  }

  togglePlay() {
    if (this.audioTarget.paused) this.audioTarget.play()
    else this.audioTarget.pause()
  }

  setVolume() {
    this.audioTarget.volume = parseFloat(this.volumeTarget.value)
  }

  seekToCue(event) {
    const start = parseFloat(event.currentTarget.dataset.start)
    if (!Number.isFinite(start)) return

    this.audioTarget.currentTime = start
    this.handleTimeUpdate()
  }

  scrub(event) {
    if (!this.duration) return

    const rect = this.waveformTarget.getBoundingClientRect()
    const ratio = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width))
    this.audioTarget.currentTime = ratio * this.duration
    this.handleTimeUpdate()
  }

  handleMetadata() {
    const reported = this.audioTarget.duration
    if (Number.isFinite(reported) && reported > 0) this.duration = reported
    if (this.hasDurationTarget) this.durationTarget.textContent = this.formatTime(this.duration)
    this.renderWaveform()
  }

  handleTimeUpdate() {
    const current = this.audioTarget.currentTime
    if (this.hasCurrentTimeTarget) this.currentTimeTarget.textContent = this.formatTime(current)
    this.highlightCue(current)
    this.renderWaveform()
  }

  highlightCue(time) {
    const cue = this.cueAt(time)
    if (cue === this.activeCue) return

    if (this.activeCue) this.clearHighlight(this.activeCue.el)
    this.activeCue = cue
    if (cue) {
      this.applyHighlight(cue.el)
      this.scrollCueIntoView(cue.el)
    }
  }

  applyHighlight(el) {
    el.classList.add("cue-active")
    const color = el.dataset.color
    if (color) el.style.backgroundColor = `color-mix(in oklab, ${color} 30%, transparent)`
  }

  clearHighlight(el) {
    el.classList.remove("cue-active")
    el.style.backgroundColor = ""
  }

  cueAt(time) {
    let fallback = null
    for (const cue of this.cues) {
      if (time >= cue.start && (!Number.isFinite(cue.end) || time < cue.end)) return cue
      if (cue.start <= time) fallback = cue
      else break
    }
    return fallback
  }

  scrollCueIntoView(el) {
    const container = this.scrollContainer
    if (!container) return

    const cr = container.getBoundingClientRect()
    const er = el.getBoundingClientRect()
    if (er.top < cr.top || er.bottom > cr.bottom) {
      container.scrollTop += er.top - cr.top - container.clientHeight / 2 + er.height / 2
    }
  }

  async loadWaveform() {
    try {
      const response = await fetch(this.audioUrlValue)
      const buffer = await response.arrayBuffer()
      const AudioContextClass = window.AudioContext || window.webkitAudioContext
      const context = new AudioContextClass()
      const audioBuffer = await context.decodeAudioData(buffer)
      this.peaks = this.computePeaks(audioBuffer, 320)
      if (audioBuffer.duration > 0) this.duration = audioBuffer.duration
      if (this.hasDurationTarget) this.durationTarget.textContent = this.formatTime(this.duration)
      context.close()
    } catch (_error) {
      this.peaks = null // fall back to a flat, still-seekable timeline
    }
    this.renderWaveform()
  }

  computePeaks(audioBuffer, bars) {
    const data = audioBuffer.getChannelData(0)
    const block = Math.floor(data.length / bars) || 1
    const peaks = new Array(bars)
    let max = 0.0001
    for (let i = 0; i < bars; i += 1) {
      let sum = 0
      const offset = i * block
      for (let j = 0; j < block; j += 1) {
        const sample = data[offset + j] || 0
        sum += sample * sample
      }
      const rms = Math.sqrt(sum / block)
      peaks[i] = rms
      if (rms > max) max = rms
    }
    return peaks.map((peak) => peak / max)
  }

  renderWaveform() {
    const canvas = this.waveformTarget
    const dpr = window.devicePixelRatio || 1
    const cssWidth = canvas.clientWidth || 1
    const cssHeight = canvas.clientHeight || 64
    const width = Math.floor(cssWidth * dpr)
    const height = Math.floor(cssHeight * dpr)
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width
      canvas.height = height
    }

    const ctx = canvas.getContext("2d")
    ctx.clearRect(0, 0, width, height)

    const bars = this.peaks ? this.peaks.length : 160
    const barWidth = width / bars
    const playedRatio = this.duration ? this.audioTarget.currentTime / this.duration : 0

    for (let i = 0; i < bars; i += 1) {
      const amplitude = this.peaks ? this.peaks[i] : 0.45
      const barHeight = Math.max(2 * dpr, amplitude * height * 0.9)
      const x = i * barWidth
      const y = (height - barHeight) / 2
      const time = ((i + 0.5) / bars) * (this.duration || 0)
      const played = i / bars < playedRatio

      ctx.globalAlpha = played ? 1 : 0.3
      ctx.fillStyle = this.barColor(time)
      ctx.fillRect(x, y, Math.max(1, barWidth - dpr), barHeight)
    }
    ctx.globalAlpha = 1
  }

  barColor(time) {
    if (this.multiSpeakerValue) {
      const color = this.colorAt(time)
      if (color) return color
    }
    return this.accentColor()
  }

  // Color for a moment in time. In the gaps between segments we carry the
  // previous speaker's color forward (and use the first speaker's color before
  // the first segment) so silent stretches blend in instead of flashing the
  // fallback accent color.
  colorAt(time) {
    if (this.timelineValue.length === 0) return null

    let carried = this.colorsValue[this.timelineValue[0].speaker] || null
    for (const segment of this.timelineValue) {
      if (segment.start > time) break
      carried = this.colorsValue[segment.speaker] || carried
      if (time < segment.end) return this.colorsValue[segment.speaker]
    }
    return carried
  }

  accentColor() {
    if (!this._accentColor) {
      const value = getComputedStyle(this.element).getPropertyValue("--color-primary").trim()
      this._accentColor = value || "#6366f1"
    }
    return this._accentColor
  }

  syncPlayIcon() {
    const playing = !this.audioTarget.paused
    if (this.hasPlayIconTarget) this.playIconTarget.classList.toggle("hidden", playing)
    if (this.hasPauseIconTarget) this.pauseIconTarget.classList.toggle("hidden", !playing)
  }

  formatTime(seconds) {
    if (!Number.isFinite(seconds)) return "0:00"

    const minutes = Math.floor(seconds / 60)
    const remainder = Math.floor(seconds % 60).toString().padStart(2, "0")
    return `${minutes}:${remainder}`
  }
}
