import { Controller } from "@hotwired/stimulus"

// Turns the example-document field into a drag-and-drop zone and previews the
// chosen filenames. Dropping files assigns them to the underlying file input so
// they submit with the form like an ordinary upload — no extra wiring needed.
export default class extends Controller {
  static targets = ["input", "dropzone", "list"]
  static classes = ["active"]

  connect() {
    this.renderNames()
  }

  open() {
    this.inputTarget.click()
  }

  over(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add(...this.activeClasses)
  }

  leave(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove(...this.activeClasses)
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove(...this.activeClasses)

    const dropped = event.dataTransfer?.files
    if (!dropped || dropped.length === 0) return

    // Merge any files already chosen with the dropped ones.
    const data = new DataTransfer()
    for (const file of this.inputTarget.files) data.items.add(file)
    for (const file of dropped) data.items.add(file)
    this.inputTarget.files = data.files

    this.renderNames()
  }

  renderNames() {
    if (!this.hasListTarget) return

    const names = Array.from(this.inputTarget.files).map((file) => file.name)
    this.listTarget.innerHTML = ""

    for (const name of names) {
      const item = document.createElement("li")
      item.className = "truncate text-sm text-base-content/70"
      item.textContent = name
      this.listTarget.appendChild(item)
    }
  }
}
