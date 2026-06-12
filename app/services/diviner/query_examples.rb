# frozen_string_literal: true

module Diviner
  # Canonical examples for common Cocina querying patterns.
  module QueryExamples
    TITLE_MATCH_WITH_COCINA = <<~SQL.squish
      WITH matched AS (
        SELECT
          ro.external_identifier AS druid,
          rov.*
        FROM repository_objects ro
        JOIN repository_object_versions rov
          ON rov.id = ro.head_version_id
        WHERE ro.object_type = 'dro'
          AND EXISTS (
            SELECT 1
            FROM jsonb_path_query(rov.description, '$.title.**.value') AS t(value_json)
            WHERE jsonb_typeof(t.value_json) = 'string'
              AND (t.value_json #>> '{}') ~* '\\msymphon(y|ies)\\M'
          )
      )
      SELECT
        druid,
        jsonb_strip_nulls(
          jsonb_build_object(
            'cocinaVersion', cocina_version,
            'type', content_type,
            'externalIdentifier', druid,
            'label', label,
            'version', version,
            'access', access,
            'administrative', administrative,
            'description', description,
            'identification', identification,
            'structural', structural,
            'geographic', geographic
          )
        ) AS cocina_json
      FROM matched
      LIMIT 500
    SQL

    INVALID_URI_AGGREGATE = <<~SQL.squish
      WITH matched AS (
        SELECT
          ro.external_identifier AS druid,
          jsonb_path_query(rov.identification, '$.catalogLinks[*] ? (@.catalog == "folio").catalogRecordId') ->> 0 AS folio_instance_hrid,
          jsonb_path_query(rov.structural, '$.isMemberOf') ->> 0 AS collection_druid,
          jsonb_path_query(rov.description, 'strict $.**.language.**.uri ? (@ like_regex "^(?!https?://).*$" || @ like_regex "^.*\\.html$")') ->> 0 AS invalid_uri
        FROM repository_objects ro
        JOIN repository_object_versions rov
          ON rov.id = ro.head_version_id
        WHERE ro.object_type = 'dro'
          AND jsonb_path_exists(
            rov.description,
            'strict $.**.language.**.uri ? (@ like_regex "^(?!https?://).*$" || @ like_regex "^.*\\.html$")'
          )
      )
      SELECT
        druid,
        folio_instance_hrid,
        collection_druid,
        array_agg(DISTINCT invalid_uri) FILTER (WHERE invalid_uri IS NOT NULL) AS invalid_uris
      FROM matched
      GROUP BY druid, folio_instance_hrid, collection_druid
      ORDER BY druid
      LIMIT 500
    SQL

    DISTINCT_VALUE_ANOMALY = <<~SQL.squish
      WITH matched AS (
        SELECT
          ro.external_identifier AS druid,
          jsonb_path_query(rov.identification, '$.catalogLinks[*] ? (@.catalog == "folio").catalogRecordId') ->> 0 AS folio_instance_hrid,
          jsonb_path_query(rov.description, 'strict $.event') AS event_json
        FROM repository_objects ro
        JOIN repository_object_versions rov
          ON rov.id = ro.head_version_id
        WHERE ro.object_type = 'dro'
          AND jsonb_path_exists(rov.description, 'strict $.event.**.date.**.type')
      ),
      date_types AS (
        SELECT
          druid,
          folio_instance_hrid,
          jsonb_path_query(event_json, '$.date[*].type') #>> '{}' AS date_type
        FROM matched
      )
      SELECT
        druid,
        folio_instance_hrid,
        array_agg(DISTINCT date_type) FILTER (WHERE date_type IS NOT NULL) AS date_types
      FROM date_types
      GROUP BY druid, folio_instance_hrid
      HAVING COUNT(DISTINCT date_type) > 1
      ORDER BY druid
      LIMIT 500
    SQL

    FILE_COUNT_AND_SIZE = <<~SQL.squish
      WITH filtered AS (
        SELECT
          ro.external_identifier AS druid,
          rov.structural
        FROM repository_objects ro
        JOIN repository_object_versions rov
          ON rov.id = ro.head_version_id
        WHERE ro.object_type = 'dro'
      ),
      files AS (
        SELECT
          druid,
          jsonb_array_elements(
            jsonb_path_query_array(structural, '$.contains[*].structural.contains[*]')
          ) AS file_json
        FROM filtered
      )
      SELECT
        druid,
        COUNT(*) AS file_count,
        COALESCE(SUM((file_json ->> 'size')::numeric), 0) AS size_bytes
      FROM files
      GROUP BY druid
      ORDER BY file_count DESC, size_bytes DESC
      LIMIT 500
    SQL

    PROPERTY_PRESENCE_WITH_AGGREGATE = <<~SQL.squish
      WITH matched AS (
        SELECT
          ro.external_identifier AS druid,
          jsonb_path_query(rov.structural, '$.isMemberOf') ->> 0 AS collection_druid,
          jsonb_path_query(rov.identification, '$.catalogLinks[*] ? (@.catalog == "folio").catalogRecordId') ->> 0 AS folio_instance_hrid,
          jsonb_path_query(rov.description, 'strict $.contributor.**.parallelContributor') AS parallel_contributor
        FROM repository_objects ro
        JOIN repository_object_versions rov
          ON rov.id = ro.head_version_id
        WHERE ro.object_type = 'dro'
          AND jsonb_path_exists(rov.description, 'strict $.contributor.**.parallelContributor ? (@.size() > 0)')
      )
      SELECT
        druid,
        collection_druid,
        folio_instance_hrid,
        COUNT(*) AS parallel_contributor_hits
      FROM matched
      GROUP BY druid, collection_druid, folio_instance_hrid
      ORDER BY parallel_contributor_hits DESC, druid
      LIMIT 500
    SQL
  end
end
