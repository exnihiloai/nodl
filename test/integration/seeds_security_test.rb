require "test_helper"

# Regression test for S-001: predictable seed credentials.
# Verifies that db/seeds.rb is a no-op in non-development environments
# unless ALLOW_DEMO_SEEDS=1 is explicitly set.
class SeedsSecurityTest < ActionDispatch::IntegrationTest
  SEED_EMAILS = %w[admin@example.com demo@example.com].freeze

  setup do
    # Remove any leftover seed users so counts are clean.
    User.where(email: SEED_EMAILS).destroy_all
    @original_flag = ENV.delete("ALLOW_DEMO_SEEDS")
  end

  teardown do
    ENV["ALLOW_DEMO_SEEDS"] = @original_flag if @original_flag
    User.where(email: SEED_EMAILS).destroy_all
  end

  test "seeds do not create demo users in non-development environment without opt-in flag" do
    # test env is not development — seeding must be a no-op.
    assert_not Rails.env.development?, "This test must run in a non-development environment"

    assert_no_difference "User.count" do
      load Rails.root.join("db/seeds.rb")
    end

    SEED_EMAILS.each do |email|
      assert_nil User.find_by(email:), "Seed must not create #{email} outside development"
    end
  end

  test "seeds create demo users when ALLOW_DEMO_SEEDS=1 is set" do
    ENV["ALLOW_DEMO_SEEDS"] = "1"

    assert_difference "User.count", 2 do
      load Rails.root.join("db/seeds.rb")
    end

    SEED_EMAILS.each do |email|
      assert User.find_by(email:), "Seed should create #{email} when ALLOW_DEMO_SEEDS=1"
    end
  end
end
