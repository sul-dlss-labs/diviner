# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/diviner/query_examples'

RSpec.describe Diviner::QueryExamples do
  it 'defines canonical examples for the main report families' do
    expect(described_class::TITLE_MATCH_WITH_COCINA).to include('$.title.**.value')
    expect(described_class::INVALID_URI_AGGREGATE).to include('array_agg(DISTINCT invalid_uri)')
    expect(described_class::DISTINCT_VALUE_ANOMALY).to include('COUNT(DISTINCT date_type) > 1')
    expect(described_class::FILE_COUNT_AND_SIZE).to include('SUM((file_json ->>')
    expect(described_class::PROPERTY_PRESENCE_WITH_AGGREGATE).to include('parallel_contributor_hits')
  end

  it 'keeps recursive JSON-path examples in strict mode where needed' do
    expect(described_class::INVALID_URI_AGGREGATE).to include('strict $.**.language.**.uri')
    expect(described_class::DISTINCT_VALUE_ANOMALY).to include('strict $.event')
    expect(described_class::PROPERTY_PRESENCE_WITH_AGGREGATE).to include('strict $.contributor.**.parallelContributor')
  end
end
