# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/diviner/dor_services_schema'

RSpec.describe Diviner::DorServicesSchema do
  it 'formats schema rows grouped by table' do
    connection = instance_double('Connection')
    rows = [
      { 'table_name' => 'repository_objects', 'column_name' => 'id', 'data_type' => 'bigint' },
      { 'table_name' => 'repository_objects', 'column_name' => 'external_identifier', 'data_type' => 'text' },
      { 'table_name' => 'repository_object_versions', 'column_name' => 'description', 'data_type' => 'jsonb' }
    ]
    allow(connection).to receive(:select_all).and_return(double(to_a: rows))
    stub_const('DorServicesRecord', class_double(DorServicesRecord))
    allow(DorServicesRecord).to receive(:with_readonly_connection).and_yield(connection)

    snapshot = described_class.snapshot

    expect(snapshot).to include('repository_objects(id:bigint, external_identifier:text)')
    expect(snapshot).to include('repository_object_versions(description:jsonb)')
  end

  it 'returns a readable fallback when schema lookup fails' do
    connection = instance_double('Connection')
    allow(connection).to receive(:select_all).and_raise(StandardError, 'boom')
    stub_const('DorServicesRecord', class_double(DorServicesRecord))
    allow(DorServicesRecord).to receive(:with_readonly_connection).and_yield(connection)

    expect(described_class.snapshot).to eq('(dor-services schema unavailable: boom)')
  end
end
