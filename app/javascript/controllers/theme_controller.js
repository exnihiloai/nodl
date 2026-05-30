import { Controller } from "@hotwired/stimulus"

const THEME_STORAGE_KEY = "theme_preference"
const LIGHT_THEME = "light"
const DARK_THEME = "dark"

export default class extends Controller {
  static targets = ["toggle", "lightIcon", "darkIcon"]

  connect() {
    this.applyTheme(this.resolveThemePreference())
  }

  toggle(event) {
    const theme = event.target.checked ? DARK_THEME : LIGHT_THEME
    localStorage.setItem(THEME_STORAGE_KEY, theme)
    this.applyTheme(theme)
  }

  resolveThemePreference() {
    const savedTheme = localStorage.getItem(THEME_STORAGE_KEY)
    if (savedTheme === LIGHT_THEME || savedTheme === DARK_THEME) return savedTheme

    if (window.matchMedia("(prefers-color-scheme: dark)").matches) return DARK_THEME
    return LIGHT_THEME
  }

  applyTheme(theme) {
    const darkModeEnabled = theme === DARK_THEME
    document.documentElement.setAttribute("data-theme", theme)

    this.toggleTargets.forEach((toggle) => {
      toggle.checked = darkModeEnabled
      toggle.setAttribute("aria-checked", darkModeEnabled ? "true" : "false")
    })

    this.lightIconTargets.forEach((icon) => {
      icon.style.color = darkModeEnabled ? "var(--color-base-content)" : "var(--color-warning)"
      icon.style.opacity = darkModeEnabled ? "0.45" : "1"
    })

    this.darkIconTargets.forEach((icon) => {
      icon.style.color = darkModeEnabled ? "var(--color-info)" : "var(--color-base-content)"
      icon.style.opacity = darkModeEnabled ? "1" : "0.45"
    })
  }
}
