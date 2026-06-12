# frozen_string_literal: true

require_relative 'content_type_resolver'

module Diviner
  # Curated dor-services facts derived from structure.sql to guide SQL planning.
  module DorServicesFacts
    REPOSITORY_OBJECT_TYPE_ENUM = %w[dro admin_policy collection].freeze

    REPORT_FAMILIES = %w[
      metadata_validation
      catalog_link_consistency
      descriptive_metadata_anomalies
      structural_file_metrics
      collection_membership_reporting
    ].freeze

    CORE_RELATIONSHIPS = {
      head_version_join: 'repository_objects.head_version_id = repository_object_versions.id',
      object_to_versions_join: 'repository_object_versions.repository_object_id = repository_objects.id',
      object_identifier: 'repository_objects.external_identifier',
      collection_membership: "jsonb_path_query(repository_object_versions.structural, '$.isMemberOf') ->> 0",
      folio_catalog_record_id: "jsonb_path_query(repository_object_versions.identification, '$.catalogLinks[*] ? (@.catalog == \"folio\").catalogRecordId') ->> 0"
    }.freeze

    INDEX_HINTS = [
      'index_repository_objects_on_object_type',
      'index_repository_objects_on_head_version_id',
      'index_repository_object_versions_on_repository_object_id',
      'GIN indexes on JSONB columns can materially improve jsonb_path_exists/jsonb_path_query workloads'
    ].freeze

    COCINA_JSON_COLUMNS = %w[
      access administrative description identification structural geographic
    ].freeze

    JSON_PATH_RECIPES = {
      title_values: '$.title.**.value',
      folio_catalog_links: '$.catalogLinks[*] ? (@.catalog == "folio")',
      collection_membership: '$.isMemberOf',
      event_date_types: 'strict $.event.**.date.**.type',
      contributor_parallel: 'strict $.contributor.**.parallelContributor ? (@.size() > 0)',
      language_uris: 'strict $.**.language.**.uri',
      form_source_codes: 'strict $.**.form.**.source.code',
      subject_source_codes: 'strict $.**.subject.**.source.code',
      files: '$.contains[*].structural.contains[*]',
      file_sizes: '$.contains[*].structural.contains[*].size'
    }.freeze

    OUTPUT_COLUMNS = %w[
      druid folio_instance_hrid collection_druid collection_title matched_values count flag
    ].freeze

    SQL_PATTERNS = [
      'Prefer one row per repository object in the final SELECT',
      'Push deduplication and grouping into SQL with array_agg(DISTINCT ...), COUNT(DISTINCT ...), bool_or, and HAVING',
      'When using recursive descent with .**, prefer strict JSON path mode',
      'Use jsonb_path_exists for filtering and jsonb_path_query/jsonb_path_query_array for projection',
      'For structural file reports, expand only filtered head-version rows and aggregate in SQL',
      'For validation reports, return identifiers plus the offending values rather than whole JSON blobs'
    ].freeze

    CONTENT_TYPE_FACTS = {
      column: 'repository_object_versions.content_type',
      uri_prefix: Diviner::ContentTypeResolver::BASE_URI,
      known_uris: Diviner::ContentTypeResolver.known_uris
    }.freeze

    def self.summary
      {
        repository_object_type_enum: REPOSITORY_OBJECT_TYPE_ENUM,
        report_families: REPORT_FAMILIES,
        core_relationships: CORE_RELATIONSHIPS,
        index_hints: INDEX_HINTS,
        cocina_json_columns: COCINA_JSON_COLUMNS,
        json_path_recipes: JSON_PATH_RECIPES,
        output_columns: OUTPUT_COLUMNS,
        content_type_facts: CONTENT_TYPE_FACTS,
        sql_patterns: SQL_PATTERNS,
        guidance: [
          "For DRO queries use repository_objects.object_type = 'dro' (never 'item').",
          'For current cocina state, join through repository_objects.head_version_id to repository_object_versions.id.',
          'Cocina content type is stored on repository_object_versions.content_type and values are HTTPS URIs.',
          'If a user provides a content type URI, use it as is.',
          'If a user provides a plain content type string (for example image), resolve it to the canonical Cocina models URI first.',
          'For JSONB report requests, do as much filtering, grouping, deduplication, and anomaly detection in SQL as possible.',
          'When filtering title text, use repository_object_versions.description and target $.title.**.value nodes only.',
          'For recursive JSON path expressions using .**, prefer strict mode to avoid unexpected array unwrapping.',
          'For validation reports, aggregate offending values in SQL so the final result already has one row per druid.',
          'Common report families are metadata validation, catalog-link consistency, descriptive anomaly detection, and structural file metrics.'
        ]
      }
    end
  end
end
