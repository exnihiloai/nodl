import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "bar", "percentage", "label" ]
  static values = {
    startedAt: String,
    duration: Number,
    analyzingText: String,
    transcribingText: String,
    structuringText: String
  }

  connect() {
    this.startedTime = new Date(this.startedAtValue).getTime()
    this.audioDuration = this.durationValue || 0
    this.expectedTotalSeconds = this.calculateExpectedTime(this.audioDuration)

    this.updateProgress()
    this.timer = setInterval(() => this.updateProgress(), 250)
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  calculateExpectedTime(duration) {
    const points = [
      { d: 0, t: 3 },
      { d: 120, t: 7 },
      { d: 300, t: 10 },
      { d: 600, t: 15 },
      { d: 1200, t: 23 },
      { d: 2400, t: 32 },
      { d: 3600, t: 35 },
      { d: 5400, t: 54 },
      { d: 7200, t: 66 }
    ]

    if (duration <= 0) return points[0].t

    for (let i = 0; i < points.length - 1; i++) {
      const p1 = points[i]
      const p2 = points[i+1]
      if (duration >= p1.d && duration <= p2.d) {
        const fraction = (duration - p1.d) / (p2.d - p1.d)
        return p1.t + fraction * (p2.t - p1.t)
      }
    }

    const last = points[points.length - 1]
    return last.t + (duration - last.d) * 0.0067
  }

  updateProgress() {
    const now = Date.now()
    const elapsedSeconds = (now - this.startedTime) / 1000.0

    const progressPercent = (elapsedSeconds / this.expectedTotalSeconds) * 100.0

    let displayPercent
    if (progressPercent < 90) {
      displayPercent = progressPercent
    } else {
      // Decelerate asymptotically as it approaches 99%
      const excess = progressPercent - 90
      displayPercent = 90 + 9 * (1 - Math.exp(-excess * 0.05))
    }

    displayPercent = Math.max(0, Math.min(99, displayPercent))
    const displayPercentRounded = Math.round(displayPercent)

    if (this.hasBarTarget) {
      this.barTarget.style.width = `${displayPercent.toFixed(1)}%`
    }

    if (this.hasPercentageTarget) {
      this.percentageTarget.textContent = `${displayPercentRounded}%`
    }

    // Set appropriate label text depending on progress
    if (this.hasLabelTarget) {
      if (displayPercentRounded < 8) {
        this.labelTarget.textContent = this.analyzingTextValue
      } else if (displayPercentRounded < 85) {
        this.labelTarget.textContent = this.transcribingTextValue
      } else {
        this.labelTarget.textContent = this.structuringTextValue
      }
    }
  }
}
