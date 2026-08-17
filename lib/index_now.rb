# Submits URLs to the IndexNow endpoint so Bing (and the other participating
# engines) learn about new or changed pages without waiting for a crawl. This
# matters beyond Bing: ChatGPT's web search reads the Bing index, so a page that
# is not there is invisible to it.
#
# The protocol authenticates by key file: a plain text file at the site root
# whose name and contents are both the key. Generate one with
# `openssl rand -hex 16`, drop it in public/, and the key is discovered from
# there — no credential handling and nothing secret involved.
require "json"
require "net/http"

class IndexNow
  ENDPOINT = URI("https://api.indexnow.org/indexnow").freeze
  MAX_URLS = 10_000

  Result = Data.define(:code, :message, :submitted)

  # IndexNow answers 200 for accepted and 202 for "accepted, key still being
  # validated". Both mean the submission landed.
  SUCCESS_CODES = %w[200 202].freeze

  EXPLANATIONS = {
    "400" => "Bad request — malformed payload.",
    "403" => "Key not valid: the key file was not found or did not match.",
    "422" => "URLs do not belong to the host, or the key does not match the host.",
    "429" => "Too many requests — try again later."
  }.freeze

  class MissingKeyError < StandardError; end

  class << self
    # Finds the key file in public/. Returns [key, key_location].
    def key(host:, root: Rails.root.join("public"))
      candidates = Dir[root.join("*.txt").to_s].select do |path|
        base = File.basename(path, ".txt")
        base.match?(/\A[a-f0-9]{8,128}\z/i) && File.read(path).strip == base
      end

      if candidates.empty?
        raise MissingKeyError,
              "No IndexNow key file in #{root}. Create one with: " \
              "KEY=$(openssl rand -hex 16); printf '%s' \"$KEY\" > public/$KEY.txt"
      end

      found = File.basename(candidates.first, ".txt")
      [ found, "https://#{host}/#{found}.txt" ]
    end

    def payload(host:, urls:, key:, key_location:)
      {
        host: host,
        key: key,
        keyLocation: key_location,
        urlList: urls
      }
    end

    def submit(urls, host: "nodl.now")
      urls = Array(urls).uniq
      raise ArgumentError, "no URLs to submit" if urls.empty?
      raise ArgumentError, "IndexNow accepts at most #{MAX_URLS} URLs per request" if urls.size > MAX_URLS

      found_key, key_location = key(host: host)
      body = JSON.generate(payload(host:, urls:, key: found_key, key_location:))

      request = Net::HTTP::Post.new(ENDPOINT, "Content-Type" => "application/json; charset=utf-8")
      request.body = body

      response = Net::HTTP.start(ENDPOINT.hostname, ENDPOINT.port, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
        http.request(request)
      end

      Result.new(
        code: response.code,
        message: EXPLANATIONS.fetch(response.code, response.message.to_s),
        submitted: urls.size
      )
    end

    def success?(result)
      SUCCESS_CODES.include?(result.code)
    end
  end
end
