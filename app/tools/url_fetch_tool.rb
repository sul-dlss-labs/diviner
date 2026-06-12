# frozen_string_literal: true

require 'open-uri'

class UrlFetchTool < RubyLLM::Tool
  description 'Fetch content from a URL and return text excerpt.'

  param :url, type: 'string', required: true, desc: 'HTTP/HTTPS URL to fetch'
  param :max_chars, type: 'integer', required: false, desc: 'Maximum characters to return (default 4000)'

  def execute(url:, max_chars: 4000)
    uri = URI.parse(url)
    raise ArgumentError, 'Only http/https URLs are allowed' unless %w[http https].include?(uri.scheme)

    content = uri.open(read_timeout: 10, open_timeout: 10, ssl_verify_mode: OpenSSL::SSL::VERIFY_PEER).read
    {
      url: url,
      content_preview: content.to_s[0...max_chars.to_i.clamp(200, 20_000)],
      truncated: content.to_s.length > max_chars.to_i
    }
  rescue StandardError => e
    { error: e.message, url: url }
  end
end
