require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "google provider uid pair must be unique" do
    User.create!(
      email: unique_email("google-primary"),
      password: "Valid123",
      password_confirmation: "Valid123",
      provider: "google_oauth2",
      uid: "google-uid-123"
    )

    duplicate = User.new(
      email: unique_email("google-duplicate"),
      password: "Valid123",
      password_confirmation: "Valid123",
      provider: "google_oauth2",
      uid: "google-uid-123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uid], "has already been taken"
  end
end
