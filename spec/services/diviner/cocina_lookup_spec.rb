# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/diviner/cocina_lookup'

RSpec.describe Diviner::CocinaLookup do
  it 'returns nil for blank druid' do
    expect(described_class.call(nil)).to be_nil
    expect(described_class.call('')).to be_nil
  end

  it 'fetches cocina json for a druid' do
    connection = instance_double('Connection')
    allow(connection).to receive(:quote).with('druid:aa111bb2222').and_return("'druid:aa111bb2222'")
    allow(connection).to receive(:select_value).and_return({ 'type' => 'book' })

    stub_const('DorServicesRecord', class_double(DorServicesRecord))
    allow(DorServicesRecord).to receive(:with_readonly_connection).and_yield(connection)

    result = described_class.call('druid:aa111bb2222')

    expect(result).to eq({ 'type' => 'book' })
    expect(connection).to have_received(:select_value)
  end

  it 'does not include non-cocina head field' do
    connection = instance_double('Connection')
    captured_sql = nil
    allow(connection).to receive(:quote).with('druid:aa111bb2222').and_return("'druid:aa111bb2222'")
    allow(connection).to receive(:select_value) do |sql|
      captured_sql = sql
      { 'type' => 'book' }
    end

    stub_const('DorServicesRecord', class_double(DorServicesRecord))
    allow(DorServicesRecord).to receive(:with_readonly_connection).and_yield(connection)

    described_class.call('druid:aa111bb2222')

    expect(captured_sql).not_to include("'head'")
  end
end
