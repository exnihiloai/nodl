import { Controller } from "@hotwired/stimulus"

// Copies the rendered document to the clipboard with formatting preserved.
// Writes both text/html (so paste into Word/Docs keeps headings, bold, lists)
// and text/plain (fallback for plain-text targets). Falls back to plain-text
// copy when the rich Clipboard API is unavailable (e.g. insecure context).
export default class extends Controller {
  static targets = ["source", "label", "copyIcon", "checkIcon"]
  static values = {
    resetDelay: { type: Number, default: 2000 },
    copyText: { type: String, default: "Copy" },
    copiedText: { type: String, default: "Copied" }
  }

  async copy() {
    const html = this.sourceTarget.innerHTML
    const text = this.sourceTarget.innerText

    try {
      if (navigator.clipboard && window.ClipboardItem) {
        const item = new ClipboardItem({
          "text/html": new Blob([html], { type: "text/html" }),
          "text/plain": new Blob([text], { type: "text/plain" })
        })
        await navigator.clipboard.write([item])
      } else if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(text)
      } else {
        this.legacyCopy(text)
      }
      this.showCopied()
    } catch (error) {
      try {
        this.legacyCopy(text)
        this.showCopied()
      } catch {
        // Leave the button untouched so the user can retry.
      }
    }
  }

  legacyCopy(text) {
    const area = document.createElement("textarea")
    area.value = text
    area.setAttribute("readonly", "")
    area.style.position = "absolute"
    area.style.left = "-9999px"
    document.body.appendChild(area)
    area.select()
    document.execCommand("copy")
    document.body.removeChild(area)
  }

  showCopied() {
    if (this.hasLabelTarget) this.labelTarget.textContent = this.copiedTextValue
    if (this.hasCopyIconTarget) this.copyIconTarget.classList.add("hidden")
    if (this.hasCheckIconTarget) this.checkIconTarget.classList.remove("hidden")

    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => this.reset(), this.resetDelayValue)
  }

  reset() {
    if (this.hasLabelTarget) this.labelTarget.textContent = this.copyTextValue
    if (this.hasCopyIconTarget) this.copyIconTarget.classList.remove("hidden")
    if (this.hasCheckIconTarget) this.checkIconTarget.classList.add("hidden")
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }
}
