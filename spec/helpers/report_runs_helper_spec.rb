# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportRunsHelper do
  describe '#formatted_duration' do
    it 'formats milliseconds in seconds' do
      expect(helper.formatted_duration(1250)).to eq('1.25s')
    end

    it 'returns n/a for blank values' do
      expect(helper.formatted_duration(nil)).to eq('n/a')
    end
  end

  describe '#pretty_sql' do
    it 'formats and highlights SQL keywords' do
      html = helper.pretty_sql('select * from repository_objects where id = 1 and object_type = dro')

      expect(html).to include('<pre')
      expect(html).to include('<span class="sql-keyword">select</span>')
      expect(html).to include('<span class="sql-keyword">from</span>')
      expect(html).to include("\n<span class=\"sql-keyword\">where</span>")
    end
  end

  describe '#cocina_json_from_row' do
    it 'returns either string-keyed or symbol-keyed cocina_json values' do
      expect(helper.cocina_json_from_row({ 'cocina_json' => { 'a' => 1 } })).to eq({ 'a' => 1 })
      expect(helper.cocina_json_from_row({ cocina_json: { 'a' => 2 } })).to eq({ 'a' => 2 })
    end

    it 'returns nil when cocina_json is absent' do
      row = { 'druid' => 'druid:aa111bb2222', 'title' => 'Example' }

      expect(helper.cocina_json_from_row(row)).to be_nil
    end
  end

  describe '#druid_from_row' do
    it 'returns either string-keyed or symbol-keyed druids' do
      expect(helper.druid_from_row({ 'druid' => 'druid:aa111bb2222' })).to eq('druid:aa111bb2222')
      expect(helper.druid_from_row({ druid: 'druid:cc333dd4444' })).to eq('druid:cc333dd4444')
    end

    it 'falls back to external identifier fields' do
      expect(helper.druid_from_row({ 'external_identifier' => 'druid:ee555ff6666' })).to eq('druid:ee555ff6666')
      expect(helper.druid_from_row({ external_identifier: 'druid:gg777hh8888' })).to eq('druid:gg777hh8888')
      expect(helper.druid_from_row({ 'externalIdentifier' => 'druid:ii999jj0000' })).to eq('druid:ii999jj0000')
    end
  end

  describe '#cocina_enrichment_warning_from_row' do
    it 'returns either string-keyed or symbol-keyed warning values' do
      expect(helper.cocina_enrichment_warning_from_row({ 'cocina_enrichment_warning' => 'warn' })).to eq('warn')
      expect(helper.cocina_enrichment_warning_from_row({ cocina_enrichment_warning: 'warn2' })).to eq('warn2')
    end
  end

  describe '#pretty_cocina_json' do
    it 'renders nested JSON and prunes empty values' do
      html = helper.pretty_cocina_json(
        {
          'title' => 'Example',
          'count' => 2,
          'active' => true,
          'notes' => ['keep', '', nil],
          'metadata' => { 'empty' => nil, 'nested' => 'value' }
        }
      )

      expect(html).to include('json-object')
      expect(html).to include('title: ')
      expect(html).to include('&quot;Example&quot;')
      expect(html).to include('count: ')
      expect(html).to include('2')
      expect(html).to include('active: ')
      expect(html).to include('true')
      expect(html).to include('notes: [1]')
      expect(html).to include('metadata: {1}')
      expect(html).not_to include('empty')
    end

    it 'parses JSON strings before rendering' do
      html = helper.pretty_cocina_json('{"title":"Example"}')

      expect(html).to include('title: ')
      expect(html).to include('&quot;Example&quot;')
    end

    it 'falls back to a preformatted block for invalid JSON strings' do
      html = helper.pretty_cocina_json('{not valid json}')

      expect(html).to include('<pre')
      expect(html).to include('{not valid json}')
    end
  end

  describe 'private rendering helpers' do
    it 'formats SQL with line breaks' do
      formatted = helper.send(:format_sql, 'SELECT * FROM x JOIN y ON x.id = y.id WHERE a = 1 OR b = 2')

      expect(formatted).to include("\nJOIN")
      expect(formatted).to include("\nWHERE")
      expect(formatted).to include("\n  OR")
    end

    it 'renders scalar nulls and array nodes' do
      scalar = helper.send(:render_json_scalar, nil, key: 'missing')
      array = helper.send(:render_json_node, ['value'], key: 'items')

      expect(scalar).to include('missing: ')
      expect(scalar).to include('null')
      expect(array).to include('items: [1]')
      expect(array).to include('[0]: ')
    end
  end
end
