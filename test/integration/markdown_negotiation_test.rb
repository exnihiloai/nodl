require "test_helper"

class MarkdownNegotiationTest < ActionDispatch::IntegrationTest
  test "homepage returns markdown when Accept: text/markdown is sent" do
    get root_path, headers: { "Accept" => "text/markdown" }

    assert_response :success
    assert_equal "text/markdown; charset=utf-8", response.content_type
    assert_includes response.body, "Nodl"
    assert response.headers["x-markdown-tokens"].to_i > 0, "x-markdown-tokens must be a positive integer"
  end

  test "homepage still returns html for normal browser requests" do
    get root_path

    assert_response :success
    assert response.content_type.include?("text/html")
  end

  test "markdown response body does not contain raw html tags" do
    get root_path, headers: { "Accept" => "text/markdown" }

    assert_response :success
    assert_no_match(/<html|<head|<script/, response.body)
  end

  test "other pages also negotiate markdown" do
    get login_path, headers: { "Accept" => "text/markdown" }

    assert_response :success
    assert_equal "text/markdown; charset=utf-8", response.content_type
  end
end
