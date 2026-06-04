class AudioPcmWorklet extends AudioWorkletProcessor {
  constructor() {
    super()
    this.targetSampleRate = 16000
    this.frameSampleCount = 640
    this.pendingSamples = []
  }

  process(inputs) {
    const input = inputs[0]?.[0]
    if (!input || input.length === 0) return true

    const ratio = sampleRate / this.targetSampleRate
    const outputLength = Math.floor(input.length / ratio)
    if (outputLength <= 0) return true

    const pcm = new Int16Array(outputLength)
    for (let i = 0; i < outputLength; i += 1) {
      const sampleIndex = Math.floor(i * ratio)
      const sample = Math.max(-1, Math.min(1, input[sampleIndex]))
      pcm[i] = sample < 0 ? sample * 0x8000 : sample * 0x7fff
    }

    this.pendingSamples.push(...pcm)
    while (this.pendingSamples.length >= this.frameSampleCount) {
      const frame = new Int16Array(this.pendingSamples.slice(0, this.frameSampleCount))
      this.pendingSamples = this.pendingSamples.slice(this.frameSampleCount)
      this.port.postMessage(frame.buffer, [frame.buffer])
    }

    return true
  }
}

registerProcessor("audio-pcm-worklet", AudioPcmWorklet)
