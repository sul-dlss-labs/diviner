# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/diviner/sql_payload'

RSpec.describe Diviner::SqlPayload do
  it 'extracts SQL from JSON payloads' do
    payload = '{"sql":"SELECT 1 AS one"}'

    expect(described_class.extract(payload)).to eq('SELECT 1 AS one')
  end

  it 'strips markdown and wrapper prefixes' do
    payload = "Write query attempted while in readonly mode: json ```json\n{\"sql\":\"SELECT 2 AS two\"}\n```"

    expect(described_class.extract(payload)).to eq('SELECT 2 AS two')
  end

  it 'returns plain SQL unchanged' do
    expect(described_class.extract('SELECT 3 AS three')).to eq('SELECT 3 AS three')
  end

  it 'does not truncate SQL containing JSON braces' do
    sql = <<~SQL.squish
      SELECT *
      FROM repository_object_versions rov
      WHERE jsonb_path_exists(rov.structural, '$.contains[*] ? (@.filename like_regex "transcript")')
    SQL

    expect(described_class.extract(sql).strip).to eq(sql.strip)
  end

  it 'extracts sql field from surrounding prose containing JSON object' do
    payload = "Here is the result:\n{\"sql\":\"SELECT 4 AS four\"}\nUse it"

    expect(described_class.extract(payload)).to eq('SELECT 4 AS four')
  end
end
