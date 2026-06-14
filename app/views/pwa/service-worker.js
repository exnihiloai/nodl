// Service worker for Web Push daily reminder notifications.

self.addEventListener("push", async (event) => {
  if (!event.data) return

  const { title, options } = await event.data.json()
  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()

  const path = event.notification.data?.path || "/dashboard"

  event.waitUntil(
    clients.matchAll({ type: "window" }).then((clientList) => {
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i]
        const clientPath = new URL(client.url).pathname

        if (clientPath === path && "focus" in client) {
          return client.focus()
        }
      }

      if (clients.openWindow) {
        return clients.openWindow(path)
      }
    })
  )
})
