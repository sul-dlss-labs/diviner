# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm'
require_relative '../../app/services/diviner/cocina_context'
require_relative '../../app/services/diviner/content_type_resolver'
require_relative '../../app/services/diviner/dor_services_schema'
require_relative '../../app/services/diviner/query_examples'
require_relative '../../app/services/diviner/dor_services_facts'
require_relative '../../app/tools/model_tool'

RSpec.describe ModelTool do
  before do
    stub_const('Diviner::DorServicesSchema', class_double(Diviner::DorServicesSchema, snapshot: 'schema'))
    stub_const('Diviner::CocinaContext', class_double(Diviner::CocinaContext, for_request: 'context'))
  end

  it 'returns expanded canonical examples and SQL-first guidance' do
    payload = described_class.new.execute(query: 'find invalid uris')

    expect(payload[:dor_services_schema]).to eq('schema')
    expect(payload[:cocina_context]).to eq('context')
    expect(payload[:sql_guidance][:canonical_examples]).to include(
      :title_match_with_cocina,
      :invalid_uri_aggregate,
      :distinct_value_anomaly,
      :file_count_and_size,
      :property_presence_with_aggregate
    )
    expect(payload[:sql_guidance][:preferred_patterns]).to include(
      'Aggregate offending values and counts in SQL so the final result is already one row per object'
    )
    expect(payload[:sql_guidance][:json_path_recipes][:files]).to eq('$.contains[*].structural.contains[*]')
    expect(payload[:sql_guidance][:grouped_output_example]).to include('array_agg(DISTINCT offending_value)')
  end

  it 'includes content type URI guidance' do
    payload = described_class.new.execute(query: 'find invalid uris')

    expect(payload[:sql_guidance][:preferred_patterns]).to include(
      'Cocina content type is stored on repository_object_versions.content_type and values are HTTPS URIs'
    )
    expect(payload[:sql_guidance][:content_type_facts][:column]).to eq('repository_object_versions.content_type')
    expect(payload[:sql_guidance][:content_type_facts][:uri_prefix]).to eq('https://cocina.sul.stanford.edu/models/')
    expect(payload[:sql_guidance][:content_type_facts][:known_uris]).to include('https://cocina.sul.stanford.edu/models/image')
  end

  it 'returns an error payload when a dependency raises' do
    allow(Diviner::DorServicesSchema).to receive(:snapshot).and_raise(StandardError, 'no schema')

    expect(described_class.new.execute(query: 'anything')).to eq(error: 'no schema')
  end
end
