# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/diviner/content_type_resolver'

RSpec.describe Diviner::ContentTypeResolver do
  describe '.resolve' do
    it 'passes through content type URIs' do
      uri = 'https://cocina.sul.stanford.edu/models/image'

      expect(described_class.resolve(uri)).to eq(uri)
    end

    it 'resolves plain content type names to canonical URIs' do
      expect(described_class.resolve('image')).to eq('https://cocina.sul.stanford.edu/models/image')
      expect(described_class.resolve('curated collection')).to eq('https://cocina.sul.stanford.edu/models/curated-collection')
    end
  end

  describe '.hints_for_request' do
    it 'returns direct URI passthrough hints and resolved string hints' do
      hints = described_class.hints_for_request('Report content types image and https://cocina.sul.stanford.edu/models/map')

      expect(hints[:uris]).to include('https://cocina.sul.stanford.edu/models/map')
      expect(hints[:resolved]).to include(
        {
          input: 'image',
          uri: 'https://cocina.sul.stanford.edu/models/image'
        }
      )
    end

    it 'does not attempt alias resolution when request is not about content types' do
      hints = described_class.hints_for_request('Show all images in 2024')

      expect(hints).to eq(uris: [], resolved: [])
    end
  end
end
