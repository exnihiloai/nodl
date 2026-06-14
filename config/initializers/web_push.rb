# Web Push requires VAPID keys in every environment that sends or registers
# push subscriptions. In development we persist generated keys under tmp/ so
# local and Docker testing works without manual setup.
Rails.application.config.after_initialize do
  next if WebPushConfig.configured?

  case Rails.env
  when "development"
    path = Rails.root.join("tmp/vapid_development_keys.env")
    if path.file?
      path.read.each_line do |line|
        key, value = line.strip.split("=", 2)
        next if key.blank? || value.blank?
        next unless key.start_with?("VAPID_")

        ENV[key] = value
      end
    else
      vapid = WebPush.generate_key
      path.parent.mkpath
      path.write(<<~ENV)
        VAPID_PUBLIC_KEY=#{vapid.public_key}
        VAPID_PRIVATE_KEY=#{vapid.private_key}
        VAPID_SUBJECT=mailto:dev@localhost
      ENV
      ENV["VAPID_PUBLIC_KEY"] = vapid.public_key
      ENV["VAPID_PRIVATE_KEY"] = vapid.private_key
      ENV["VAPID_SUBJECT"] = "mailto:dev@localhost"
      Rails.logger.info { "Generated development VAPID keys at #{path}" }
    end
  when "test"
    # test_helper.rb sets ephemeral keys when the suite boots.
  else
    Rails.logger.warn "Web Push is not configured: set VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, and VAPID_SUBJECT"
  end
end
