# frozen_string_literal: true

require_relative '../services/diviner/content_type_resolver'

class ModelTool < RubyLLM::Tool
  description 'Return dor-services schema snapshot, Cocina context snippets, and SQL planning guidance.'

  param :query, type: 'string', required: false, desc: 'Optional query describing needed context'

  PREFERRED_PATTERNS = [
    "Use ro.object_type = 'dro' for DRO queries (enum values: dro/admin_policy/collection)",
    'For current object state, join ro.head_version_id = rov.id',
    'Cocina content type is stored on repository_object_versions.content_type and values are HTTPS URIs',
    'If user input includes a content type URI, use it as is',
    'If user input includes a plain content type string (example: image), resolve it to the canonical Cocina URI first',
    'Use jsonb_path_exists for selective filtering and jsonb_path_query/jsonb_path_query_array for extraction',
    'When searching title text, inspect only $.title.**.value nodes',
    'When using recursive descent with .**, prefer strict JSON path mode',
    'Aggregate offending values and counts in SQL so the final result is already one row per object',
    'For text matching use PostgreSQL regex or JSON path like_regex only on the narrowest known path',
    'Filter first (CTE), aggregate second, and build expensive cocina JSON projection only if the user asked for it'
  ].freeze

  def execute(query: nil)
    {
      dor_services_schema: Diviner::DorServicesSchema.snapshot,
      dor_services_facts: Diviner::DorServicesFacts.summary,
      cocina_context: Diviner::CocinaContext.for_request(query.to_s),
      sql_guidance: sql_guidance
    }
  rescue StandardError => e
    { error: e.message }
  end

  private

  def sql_guidance
    {
      canonical_examples: canonical_examples,
      preferred_patterns: PREFERRED_PATTERNS,
      content_type_facts: {
        column: 'repository_object_versions.content_type',
        uri_prefix: Diviner::ContentTypeResolver::BASE_URI,
        known_uris: Diviner::ContentTypeResolver.known_uris
      },
      report_families: Diviner::DorServicesFacts::REPORT_FAMILIES,
      json_path_recipes: Diviner::DorServicesFacts::JSON_PATH_RECIPES,
      title_match_example: <<~SQL.squish.strip,
        EXISTS (
          SELECT 1
          FROM jsonb_path_query(rov.description, '$.title.**.value') AS t(value_json)
          WHERE jsonb_typeof(t.value_json) = 'string'
            AND (t.value_json #>> '{}') ~* '\\msymphon(y|ies)\\M'
        )
      SQL
      grouped_output_example: <<~SQL.squish.strip
        SELECT
          druid,
          array_agg(DISTINCT offending_value) FILTER (WHERE offending_value IS NOT NULL) AS offending_values,
          COUNT(DISTINCT offending_value) AS offending_value_count
        FROM matched
        GROUP BY druid
      SQL
    }
  end

  def canonical_examples
    {
      title_match_with_cocina: Diviner::QueryExamples::TITLE_MATCH_WITH_COCINA,
      invalid_uri_aggregate: Diviner::QueryExamples::INVALID_URI_AGGREGATE,
      distinct_value_anomaly: Diviner::QueryExamples::DISTINCT_VALUE_ANOMALY,
      file_count_and_size: Diviner::QueryExamples::FILE_COUNT_AND_SIZE,
      property_presence_with_aggregate: Diviner::QueryExamples::PROPERTY_PRESENCE_WITH_AGGREGATE
    }
  end
end
