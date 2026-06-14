import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "enabled",
    "timeZone",
    "timeField",
    "messageField",
    "error",
    "submitButton"
  ]

  static values = {
    vapidPublicKey: String,
    subscribeUrl: String,
    permissionDeniedText: String,
    unsupportedText: String,
    subscribeFailedText: String
  }

  connect() {
    this.captureTimeZone()
  }

  captureTimeZone() {
    if (!this.hasTimeZoneTarget) return

    try {
      const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
      if (zone) this.timeZoneTarget.value = zone
    } catch (_error) {
      // Best-effort; server validation catches missing timezone when enabled.
    }
  }

  async submit(event) {
    if (!this.enabledTarget.checked) {
      return
    }

    if (!this.pushSupported()) {
      event.preventDefault()
      this.showError(this.unsupportedTextValue)
      return
    }

    event.preventDefault()
    this.clearError()
    this.setSubmitting(true)

    try {
      await this.ensurePushSubscription()
      this.element.requestSubmit()
    } catch (error) {
      this.showError(error.message || this.subscribeFailedTextValue)
    } finally {
      this.setSubmitting(false)
    }
  }

  pushSupported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  async ensurePushSubscription() {
    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      throw new Error(this.permissionDeniedTextValue)
    }

    const registration = await navigator.serviceWorker.register("/service-worker")
    await navigator.serviceWorker.ready

    let subscription = await registration.pushManager.getSubscription()
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKeyValue)
      })
    }

    const response = await fetch(this.subscribeUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify({
        push_subscription: this.serializeSubscription(subscription)
      })
    })

    if (!response.ok) {
      throw new Error(this.subscribeFailedTextValue)
    }
  }

  serializeSubscription(subscription) {
    const json = subscription.toJSON()

    return {
      endpoint: json.endpoint,
      p256dh_key: json.keys.p256dh,
      auth_key: json.keys.auth
    }
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; i++) {
      outputArray[i] = rawData.charCodeAt(i)
    }

    return outputArray
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  showError(message) {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  setSubmitting(submitting) {
    if (!this.hasSubmitButtonTarget) return

    this.submitButtonTarget.disabled = submitting
  }
}
