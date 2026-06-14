namespace :web_push do
  desc "Print VAPID key pair for Web Push (add to private/.env or deployment env)"
  task :vapid_keys do
    vapid = WebPush.generate_key

    puts <<~OUTPUT
      Add these to your environment (e.g. private/.env):

      VAPID_PUBLIC_KEY=#{vapid.public_key}
      VAPID_PRIVATE_KEY=#{vapid.private_key}
      VAPID_SUBJECT=mailto:hello@example.com
    OUTPUT
  end
end
