# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.frame_ancestors :none
    policy.object_src :none
    policy.script_src :self, "https://js.stripe.com"
    policy.style_src :self, :unsafe_inline
    policy.img_src :self, :https, :data
    policy.font_src :self, :data
    policy.connect_src :self, :https
    policy.form_action :self, "https://accounts.google.com"
    policy.frame_src :self, "https://js.stripe.com", "https://hooks.stripe.com", "https://checkout.stripe.com"
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  # Only nonce script-src. Nonce-ing style-src would make the browser ignore the
  # 'unsafe_inline' declared above (per the CSP spec), which blocks every
  # JS-driven inline style we rely on — the voice aura's --voice-level, the
  # bouncy button tilt, the theme toggle, and the processing progress bar.
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_nonce_auto = true
end
