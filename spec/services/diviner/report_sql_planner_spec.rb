# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/diviner/cocina_context'
require_relative '../../../app/services/diviner/dor_services_schema'
require_relative '../../../app/services/diviner/report_sql_planner'
require_relative '../../../app/services/diviner/sql_payload'
require_relative '../../../app/services/diviner/sql_quality_rewriter'

RSpec.describe Diviner::ReportSqlPlanner do
  let(:agent_instance) { instance_double(Diviner::ReportAgent) }

  before do
    stub_const('Diviner::ReportAgent', Class.new)
    stub_const('Diviner::DorServicesSchema', class_double(Diviner::DorServicesSchema, snapshot: 'schema-context'))
    stub_const('Diviner::CocinaContext', class_double(Diviner::CocinaContext, for_request: 'cocina-context'))
    stub_const('Diviner::SqlQualityRewriter', class_double(Diviner::SqlQualityRewriter))
    allow(Diviner::ReportAgent).to receive(:new).and_return(agent_instance)
    allow(Diviner::ContentTypeResolver).to receive(:hints_for_request).and_return({ uris: [], resolved: [] })
  end

  it 'builds a prompt with the expanded SQL-first guidance and rewrites parsed SQL' do
    allow(agent_instance).to receive(:ask).with(
      a_string_including(
        'Push grouping, deduplication, and anomaly detection into SQL rather than Ruby.',
        'Use the model_tool first to gather schema + SQL guidance before producing output.',
        'Content type guidance:',
        'schema-context',
        'cocina-context'
      )
    ).and_return(double(content: '{"sql":"SELECT 1 AS one"}'))
    allow(Diviner::SqlQualityRewriter).to receive(:call).with('SELECT 1 AS one').and_return('REWRITTEN SQL')

    result = described_class.call(user_request: 'find invalid language uris')

    expect(result).to eq('REWRITTEN SQL')
  end

  it 'accepts hash-shaped agent content' do
    allow(agent_instance).to receive(:ask).and_return(double(content: { sql: 'SELECT 2 AS two' }))
    allow(Diviner::SqlQualityRewriter).to receive(:call).with('SELECT 2 AS two').and_return('SELECT 2 AS two')

    expect(described_class.call(user_request: 'count files')).to eq('SELECT 2 AS two')
  end

  it 'falls back to raw content when JSON parsing fails' do
    allow(agent_instance).to receive(:ask).and_return(double(content: 'SELECT 3 AS three'))
    allow(Diviner::SqlQualityRewriter).to receive(:call).with('SELECT 3 AS three').and_return('SELECT 3 AS three')

    expect(described_class.call(user_request: 'plain sql')).to eq('SELECT 3 AS three')
  end

  it 'includes resolved content type hints in the prompt' do
    allow(Diviner::ContentTypeResolver).to receive(:hints_for_request).and_return(
      {
        uris: ['https://cocina.sul.stanford.edu/models/map'],
        resolved: [
          {
            input: 'image',
            uri: 'https://cocina.sul.stanford.edu/models/image'
          }
        ]
      }
    )

    allow(agent_instance).to receive(:ask).with(
      a_string_including(
        'Use provided content type URI as-is: https://cocina.sul.stanford.edu/models/map',
        "Resolved content type 'image' to URI: https://cocina.sul.stanford.edu/models/image"
      )
    ).and_return(double(content: '{"sql":"SELECT 1 AS one"}'))
    allow(Diviner::SqlQualityRewriter).to receive(:call).with('SELECT 1 AS one').and_return('SELECT 1 AS one')

    expect(described_class.call(user_request: 'report image and https://cocina.sul.stanford.edu/models/map')).to eq('SELECT 1 AS one')
  end
end
