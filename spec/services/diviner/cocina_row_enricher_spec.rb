# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/diviner/cocina_row_enricher'

RSpec.describe Diviner::CocinaRowEnricher do
  it 'backfills cocina_json for druid rows missing payloads' do
    connection = instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    allow(connection).to receive(:quote) { |value| "'#{value}'" }
    allow(connection).to receive(:select_all).and_return(
      double(to_a: [{ 'druid' => 'druid:aa111bb2222',
                      'cocina_json' => { 'type' => 'https://cocina.sul.stanford.edu/models/image' } }])
    )
    stub_const('DorServicesRecord', class_double(DorServicesRecord))
    allow(DorServicesRecord).to receive(:with_readonly_connection).and_yield(connection)

    rows = [{ 'druid' => 'druid:aa111bb2222' }]
    enriched = described_class.call(rows)

    expect(enriched).to eq(
      [{ 'druid' => 'druid:aa111bb2222',
         'cocina_json' => { 'type' => 'https://cocina.sul.stanford.edu/models/image' } }]
    )
  end

  it 'leaves rows unchanged when they already have cocina_json' do
    row = { 'druid' => 'druid:aa111bb2222', 'cocina_json' => { 'id' => 'druid:aa111bb2222' } }

    expect(described_class.call([row])).to eq([row])
  end

  it 'returns original rows if dor-services lookup fails' do
    connection = instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    allow(connection).to receive(:quote) { |value| "'#{value}'" }
    allow(connection).to receive(:select_all).and_raise(StandardError, 'db unavailable')
    stub_const('DorServicesRecord', class_double(DorServicesRecord))
    allow(DorServicesRecord).to receive(:with_readonly_connection).and_yield(connection)

    rows = [{ 'druid' => 'druid:aa111bb2222' }]

    expect(described_class.call(rows)).to eq(rows)
  end

  it 'adds a warning when a druid cannot be enriched' do
    connection = instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    allow(connection).to receive(:quote) { |value| "'#{value}'" }
    allow(connection).to receive(:select_all).and_return(double(to_a: []))
    stub_const('DorServicesRecord', class_double(DorServicesRecord))
    allow(DorServicesRecord).to receive(:with_readonly_connection).and_yield(connection)

    rows = [{ 'druid' => 'druid:aa111bb2222' }]
    enriched = described_class.call(rows)

    expect(enriched).to eq(
      [{
        'druid' => 'druid:aa111bb2222',
        'cocina_enrichment_warning' => Diviner::CocinaRowEnricher::ENRICHMENT_WARNING
      }]
    )
  end
end
