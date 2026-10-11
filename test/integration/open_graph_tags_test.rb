require "test_helper"

class OpenGraphTagsTest < ActionDispatch::IntegrationTest
  setup do
    @private_views = Rails.root.join("tmp/open_graph_tags_test/#{SecureRandom.hex(8)}/views")
    @private_views.join("content/de").mkpath
    @private_views.join("content/de/tagebuch-diktieren.html.erb").write(<<~ERB)
      <% content_for :title, "Tagebuch diktieren & sprechen – Nodl" %>
      <% content_for :head do %>
        <meta name="description" content="So diktierst du dein Tagebuch &amp; behältst den Überblick." />
      <% end %>
      <h1>Artikel</h1>
    ERB
  end

  teardown do
    FileUtils.rm_rf(@private_views.dirname)
  end

  test "articles expose title, description, url and image for link previews" do
    with_private_view_root(@private_views) do
      get "/artikel/tagebuch-diktieren"

      assert_select "meta[property='og:type'][content=article]"
      assert_select "meta[property='og:title'][content=?]", "Tagebuch diktieren & sprechen – Nodl"
      assert_select "meta[property='og:description'][content=?]", "So diktierst du dein Tagebuch & behältst den Überblick."
      assert_select "meta[property='og:url'][content=?]", "https://nodl.now/artikel/tagebuch-diktieren"
      assert_select "meta[property='og:image'][content=?]", "https://nodl.now/og-image.png"
      assert_select "meta[property='og:locale'][content=de_DE]"
      assert_select "meta[name='twitter:card'][content=summary_large_image]"
    end
  end

  test "pages without a meta description still get the basic preview tags" do
    get register_path

    assert_select "meta[property='og:type'][content=website]"
    assert_select "meta[property='og:image']"
  end

  test "the preview image is served" do
    assert Rails.public_path.join("og-image.png").file?
  end
end
