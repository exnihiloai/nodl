require "test_helper"

class PrivateViewsTailwindSourceTest < ActiveSupport::TestCase
  test "tailwind entry scans private marketing views for utility classes" do
    css = Rails.root.join("app/assets/tailwind/application.css").read

    assert_includes css, '@source "../../../private/views"',
                    "Add @source for private/views in app/assets/tailwind/application.css — " \
                    "otherwise responsive utilities in marketing templates are missing from tailwind.css"
  end
end
