# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/diviner/safe_sql_runner'

RSpec.describe Diviner::SafeSqlRunner do
  let(:connection) { instance_double('Connection') }
  let(:result) { double(to_a: [{ 'one' => 1 }]) }

  before do
    allow(connection).to receive(:transaction).and_yield
    allow(connection).to receive(:execute)
    allow(connection).to receive(:select_all).and_return(result)
    stub_const('DorServicesRecord', class_double(DorServicesRecord))
    allow(DorServicesRecord).to receive(:with_readonly_connection).and_yield(connection)
  end

  it 'unwraps wrapped JSON payloads and applies the default limit' do
    sql = 'Write query attempted while in readonly mode: json {"sql":"SELECT 1 AS one"}'

    described_class.call(sql)

    expect(connection).to have_received(:select_all).with("SELECT 1 AS one\nLIMIT 500")
  end

  it 'preserves explicit limits on the final query' do
    described_class.call('SELECT 1 AS one LIMIT 10')

    expect(connection).to have_received(:select_all).with('SELECT 1 AS one LIMIT 10')
  end

  it 'allows readonly SET statements before a SELECT' do
    described_class.call('SET enable_seqscan = off; SELECT 1 AS one')

    expect(connection).to have_received(:execute).with('SET enable_seqscan = off')
    expect(connection).to have_received(:select_all).with("SELECT 1 AS one\nLIMIT 500")
  end

  it 'rejects forbidden write keywords' do
    expect do
      described_class.call('UPDATE repository_objects SET updated_at = NOW()')
    end.to raise_error(Diviner::SafeSqlRunner::Error, /Forbidden keyword detected: UPDATE/)
  end

  it 'rejects blank SQL payloads' do
    expect do
      described_class.call("  -- only a comment\n /* block comment */  ")
    end.to raise_error(Diviner::SafeSqlRunner::Error, 'SQL cannot be blank.')
  end

  it 'rejects malformed statements without a leading keyword' do
    expect do
      described_class.call('$$$')
    end.to raise_error(Diviner::SafeSqlRunner::Error, 'SQL statement is malformed.')
  end

  it 'rejects unsupported statement prefixes' do
    expect do
      described_class.call('DECLARE x CURSOR FOR SELECT 1')
    end.to raise_error(Diviner::SafeSqlRunner::Error, 'Unsupported SQL statement prefix: DECLARE')
  end

  it 'does not split semicolons inside quoted strings' do
    described_class.call("SELECT ';' AS semicolon")

    expect(connection).to have_received(:select_all).with("SELECT ';' AS semicolon\nLIMIT 500")
  end

  it 'preserves SQL containing JSON braces and operators' do
    sql = "SELECT rov.description #>> '{}' AS description_text FROM repository_object_versions rov"

    described_class.call(sql)

    expect(connection).to have_received(:select_all).with(
      "SELECT rov.description #>> '{}' AS description_text FROM repository_object_versions rov\nLIMIT 500"
    )
  end
end
