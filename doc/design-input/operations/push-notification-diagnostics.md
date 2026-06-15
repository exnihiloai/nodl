# Push Notification Diagnostics

Use this checklist when a user says a daily reminder was saved but no push notification arrived. The goal is to classify the problem by layer before changing code.

## 1. Check user eligibility

Run this in the production Rails console with the affected user's email:

```ruby
user = User.find_by!(email: "user@example.com")
now = Time.current

{
  enabled: user.daily_reminder_enabled?,
  time: user.daily_reminder_at&.strftime("%H:%M"),
  time_zone: user.time_zone,
  due_now: user.reminder_due_at?(now: now),
  nodled_today: user.nodled_today?,
  already_sent_today: user.reminder_already_sent_today?(now: now),
  last_sent_on: user.daily_reminder_last_sent_on,
  push_subscriptions: user.push_subscriptions.count
}
```

Interpretation:

- `enabled: false`, missing `time`, or missing `time_zone`: settings did not persist.
- `push_subscriptions: 0`: browser subscription did not persist or was reassigned to another account.
- `due_now: false` at the expected local minute: time zone or saved time is wrong.
- `nodled_today: true`: reminder was intentionally skipped.
- `already_sent_today: true`: reminder was already sent for that local day.

## 2. Check Solid Queue

```ruby
SolidQueue::RecurringTask.find_by(key: "dispatch_daily_reminders")

SolidQueue::Process.order(last_heartbeat_at: :desc).limit(5)
  .pluck(:kind, :name, :last_heartbeat_at)

SolidQueue::Job.where(class_name: "DispatchDailyRemindersJob")
  .order(created_at: :desc).limit(10)
  .pluck(:id, :created_at, :finished_at)

SolidQueue::FailedExecution.joins(:job)
  .where(solid_queue_jobs: { class_name: %w[DispatchDailyRemindersJob SendDailyReminderPushJob] })
  .order(created_at: :desc).limit(5)
  .pluck("solid_queue_jobs.class_name", "solid_queue_failed_executions.error")
```

Interpretation:

- No recent `DispatchDailyRemindersJob`: scheduler or Solid Queue supervisor problem.
- Dispatch runs but no send job is enqueued: user eligibility problem.
- Send job fails: VAPID, network, or push-gateway problem.

## 3. Check Web Push delivery

```ruby
WebPushConfig.configured?
user.push_subscriptions.pluck(:id, :user_agent, :created_at, :updated_at)

DailyReminderPushSender.call(user)
```

Interpretation:

- `WebPushConfig.configured?` is false: production VAPID configuration is missing.
- `DailyReminderPushSender.call(user)` returns `false`: all subscriptions failed or Web Push is not configured.
- It returns `true` but the user sees nothing: classify as browser/OS notification layer and check device notification settings, focus mode, and whether iPhone is using the Home-Screen PWA.

## 4. ActiveSupport notification events

The push pipeline emits these events for logs, metrics, or private telemetry subscribers:

- `daily_reminders.dispatch`: `users_scanned`, `jobs_enqueued`, `skipped`
- `daily_reminders.send`: `user_id`, `subscription_id`, `endpoint_host`, `success`, `expired`, `error_class`, `status`
- `daily_reminders.send_skipped`: `user_id`, `reason`

Never log full endpoint URLs, VAPID keys, or auth keys. Endpoint URLs are bearer-like tokens.

## 5. Manual device matrix

After server checks pass, validate only these outcomes per device:

- Settings persisted.
- Subscription count is at least one for the affected account.
- Immediate send test displays a notification.
- Scheduled minute test displays a notification.

Primary setups:

- iPhone Home-Screen PWA
- Chrome on macOS browser tab
- Chrome on macOS installed PWA

If server send succeeds but the notification is not visible, inspect browser permission, macOS/iOS notification settings, and focus mode before changing application code.
