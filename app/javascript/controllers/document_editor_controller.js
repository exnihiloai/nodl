import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"
import TurndownService from "turndown"

// WYSIWYG document editor: contenteditable surface with a formatting toolbar.
// Persists Markdown in a hidden textarea so exports and rendering stay unchanged.
export default class extends Controller {
  static targets = ["viewPanel", "editPanel", "viewActions", "content", "surface", "toolbar"]
  static values = { editing: Boolean, linkPrompt: String }

  connect() {
    this.turndown = new TurndownService({ headingStyle: "atx", bulletListMarker: "-" })
    this.turndown.addRule("strikethrough", {
      filter: [ "del", "s", "strike" ],
      replacement: (content) => `~~${content}~~`
    })
    marked.setOptions({ gfm: true, breaks: false })

    if (this.editingValue) {
      this.populateEditor()
    }

    this.sync()
  }

  edit() {
    this.populateEditor()
    this.editingValue = true
  }

  cancel() {
    this.editingValue = false
  }

  keepFocus(event) {
    event.preventDefault()
  }

  syncBeforeSubmit() {
    this.syncMarkdownToInput()
  }

  format(event) {
    event.preventDefault()
    const { command } = event.params
    this.surfaceTarget.focus()

    switch (command) {
      case "bold":
        document.execCommand("bold")
        break
      case "italic":
        document.execCommand("italic")
        break
      case "strikethrough":
        document.execCommand("strikeThrough")
        break
      case "code":
        this.wrapSelection("code")
        break
      case "link": {
        const url = window.prompt(this.linkPromptValue)
        if (url?.trim()) {
          document.execCommand("createLink", false, url.trim())
        }
        break
      }
      case "h1":
        document.execCommand("formatBlock", false, "H1")
        break
      case "h2":
        document.execCommand("formatBlock", false, "H2")
        break
      case "h3":
        document.execCommand("formatBlock", false, "H3")
        break
      case "paragraph":
        document.execCommand("formatBlock", false, "P")
        break
      case "code_block":
        document.execCommand("formatBlock", false, "PRE")
        break
      case "ul":
        document.execCommand("insertUnorderedList")
        break
      case "ol":
        document.execCommand("insertOrderedList")
        break
      case "blockquote":
        document.execCommand("formatBlock", false, "BLOCKQUOTE")
        break
      case "hr":
        document.execCommand("insertHorizontalRule")
        break
      case "undo":
        document.execCommand("undo")
        break
      case "redo":
        document.execCommand("redo")
        break
      default:
        break
    }
  }

  wrapSelection(tagName) {
    const selection = window.getSelection()
    if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return

    const range = selection.getRangeAt(0)
    const wrapper = document.createElement(tagName)
    wrapper.appendChild(range.extractContents())
    range.insertNode(wrapper)
    selection.removeAllRanges()
    const nextRange = document.createRange()
    nextRange.selectNodeContents(wrapper)
    nextRange.collapse(false)
    selection.addRange(nextRange)
  }

  populateEditor() {
    const markdown = this.contentTarget.value
    this.surfaceTarget.innerHTML = markdown.trim() === "" ? "<p></p>" : marked.parse(markdown)
  }

  syncMarkdownToInput() {
    const markdown = this.turndown.turndown(this.surfaceTarget.innerHTML).trim()
    this.contentTarget.value = markdown
  }

  editingValueChanged() {
    this.sync()
  }

  sync() {
    const editing = this.editingValue

    this.viewPanelTarget.classList.toggle("hidden", editing)
    this.editPanelTarget.classList.toggle("hidden", !editing)
    this.viewActionsTarget.classList.toggle("hidden", editing)

    if (editing) {
      this.surfaceTarget.focus()
    }
  }
}
