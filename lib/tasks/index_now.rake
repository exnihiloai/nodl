namespace :indexnow do
  desc "Submit every sitemap URL to IndexNow (Bing et al.). Usage: bin/rails indexnow:submit"
  task submit: :environment do
    host = ENV.fetch("INDEXNOW_HOST", "nodl.now")
    urls = Sitemap.entries(
      base_url: "https://#{host}",
      url_helpers: Rails.application.routes.url_helpers
    ).map(&:loc)

    report(IndexNow.submit(urls, host:), urls)
  end

  desc "Submit specific URLs. Usage: bin/rails 'indexnow:urls[https://nodl.now/a,https://nodl.now/b]'"
  task :urls, [ :list ] => :environment do |_t, args|
    host = ENV.fetch("INDEXNOW_HOST", "nodl.now")
    urls = args[:list].to_s.split(",").map(&:strip).reject(&:empty?)
    abort "Pass URLs as a comma-separated list." if urls.empty?

    report(IndexNow.submit(urls, host:), urls)
  end

  def report(result, urls)
    puts "IndexNow: #{result.submitted} URL(s) submitted"
    puts "  HTTP #{result.code} — #{result.message}"
    if IndexNow.success?(result)
      urls.first(5).each { |u| puts "    #{u}" }
      puts "    … and #{urls.size - 5} more" if urls.size > 5
    else
      abort "  Submission failed."
    end
  end
end
