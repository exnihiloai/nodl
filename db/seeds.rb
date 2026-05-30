# Guard: only run demo seeds in development or when explicitly opted in.
# This prevents predictable credentials from being created in production or staging.
unless Rails.env.development? || ENV["ALLOW_DEMO_SEEDS"] == "1"
  puts "Skipping demo seed users (not development and ALLOW_DEMO_SEEDS is not set)."
  return
end

def ensure_user_with_workspace!(email:, password:, role:)
  user = User.find_or_initialize_by(email:)
  user.role = role
  user.active = true
  user.preferred_language = "en"
  user.password = password
  user.password_confirmation = password
  user.save!

  workspace = Workspace.find_or_create_by!(slug: "#{email.split('@').first.parameterize}-workspace") do |w|
    w.name = "#{email.split('@').first.titleize} Workspace"
    w.subscription_status = "inactive"
    w.subscription_plan = "free"
    w.subscription_billing_cycle = "monthly"
    w.usage_limits = { scans: 1000, storage_mb: 1024 }
    w.usage_consumption = { scans: 0, storage_mb: 0 }
  end

  Membership.find_or_create_by!(user:, workspace:) do |membership|
    membership.role = :owner
  end
end

admin_password = SecureRandom.hex(12)
demo_password  = SecureRandom.hex(12)

ensure_user_with_workspace!(email: "admin@example.com", password: admin_password, role: :admin)
ensure_user_with_workspace!(email: "demo@example.com",  password: demo_password,  role: :user)

puts "\n=== Demo seed credentials (this run only — not stored anywhere) ==="
puts "  admin@example.com  password: #{admin_password}"
puts "  demo@example.com   password: #{demo_password}"
puts "====================================================================\n\n"
