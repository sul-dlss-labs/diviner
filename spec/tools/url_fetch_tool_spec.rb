# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm'
require_relative '../../app/tools/url_fetch_tool'

RSpec.describe UrlFetchTool do
  it 'returns a bounded preview for successful fetches' do
    uri = instance_double(URI::HTTPS, scheme: 'https')
    allow(uri).to receive(:open).and_return(StringIO.new('a' * 500))
    allow(URI).to receive(:parse).with('https://example.com').and_return(uri)

    result = described_class.new.execute(url: 'https://example.com', max_chars: 250)

    expect(result[:url]).to eq('https://example.com')
    expect(result[:content_preview].length).to eq(250)
    expect(result[:truncated]).to be(true)
  end

  it 'rejects non-http schemes' do
    result = described_class.new.execute(url: 'ftp://example.com')

    expect(result).to eq(error: 'Only http/https URLs are allowed', url: 'ftp://example.com')
  end

  it 'returns an error payload when fetching fails' do
    uri = instance_double(URI::HTTPS, scheme: 'https')
    allow(uri).to receive(:open).and_raise(StandardError, 'timeout')
    allow(URI).to receive(:parse).with('https://example.com').and_return(uri)

    result = described_class.new.execute(url: 'https://example.com')

    expect(result).to eq(error: 'timeout', url: 'https://example.com')
  end
end
