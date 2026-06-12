# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/diviner/sql_quality_rewriter'

RSpec.describe Diviner::SqlQualityRewriter do
  it 'rewrites item object types to dro' do
    sql = "SELECT * FROM repository_objects ro WHERE ro.object_type = 'item'"

    expect(described_class.call(sql)).to include("ro.object_type = 'dro'")
  end

  it 'rewrites current-version joins to head-version joins' do
    sql = 'SELECT * FROM repository_objects JOIN repository_object_versions ON repository_objects.current_version_id = repository_object_versions.id'

    expect(described_class.call(sql)).to include('repository_objects.head_version_id = repository_object_versions.id')
  end

  it 'adds strict mode to recursive title paths and narrows broad title scans' do
    sql = <<~SQL.squish
      SELECT *
      FROM repository_object_versions rov
      WHERE jsonb_path_exists(
        rov.description,
        '$.title.** ? (@.type() == "string" && @ like_regex "(?i)foo")'
      )
    SQL

    rewritten = described_class.call(sql)

    expect(rewritten).to include('strict $.title.**.value ? (@.type() == "string" && @ like_regex "(?i)foo")')
  end

  it 'rewrites generic folio catalog-record-id extraction to the canonical path' do
    sql = "SELECT jsonb_path_query(rov.identification, '$.catalogLinks[*].catalogRecordId') ->> 0 FROM repository_object_versions rov"

    expect(described_class.call(sql)).to include('$.catalogLinks[*] ? (@.catalog == "folio").catalogRecordId')
  end
end
