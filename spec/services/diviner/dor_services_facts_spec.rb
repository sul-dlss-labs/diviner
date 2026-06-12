# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/diviner/dor_services_facts'

RSpec.describe Diviner::DorServicesFacts do
  describe '.summary' do
    it 'returns report families, path recipes, and SQL-first guidance' do
      summary = described_class.summary

      expect(summary[:report_families]).to include('metadata_validation', 'structural_file_metrics')
      expect(summary[:json_path_recipes][:title_values]).to eq('$.title.**.value')
      expect(summary[:json_path_recipes][:event_date_types]).to eq('strict $.event.**.date.**.type')
      expect(summary[:output_columns]).to include('druid', 'folio_instance_hrid', 'count')
      expect(summary[:content_type_facts][:column]).to eq('repository_object_versions.content_type')
      expect(summary[:content_type_facts][:uri_prefix]).to eq('https://cocina.sul.stanford.edu/models/')
      expect(summary[:content_type_facts][:known_uris]).to include('https://cocina.sul.stanford.edu/models/image')
      expect(summary[:sql_patterns]).to include('Prefer one row per repository object in the final SELECT')
      expect(summary[:guidance]).to include('For JSONB report requests, do as much filtering, grouping, deduplication, and anomaly detection in SQL as possible.')
      expect(summary[:guidance]).to include('If a user provides a content type URI, use it as is.')
    end
  end
end
