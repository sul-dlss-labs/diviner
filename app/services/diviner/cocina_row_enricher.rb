# frozen_string_literal: true

module Diviner
  # Backfills full Cocina JSON for result rows that only include identifiers.
  module CocinaRowEnricher
    ENRICHMENT_WARNING = 'Full Cocina JSON could not be found for this druid; showing raw row data.'

    module_function

    def call(rows)
      normalized_rows = normalize_rows(rows)
      return normalized_rows if normalized_rows.empty?

      enrichable_druids = druids_needing_enrichment(normalized_rows)
      return normalized_rows if enrichable_druids.empty?

      cocina_by_druid = fetch_cocina_by_druid(enrichable_druids)
      merge_cocina_payloads(normalized_rows, cocina_by_druid)
    rescue StandardError
      normalized_rows
    end

    def normalize_rows(rows)
      Array(rows).map { |row| row.respond_to?(:to_h) ? row.to_h : row }
    end

    def druids_needing_enrichment(rows)
      rows.filter_map { |row| druid_from_row(row) if needs_enrichment?(row) }.uniq
    end

    def druid_from_row(row)
      row['druid'] || row[:druid]
    end

    def needs_enrichment?(row)
      payload = row['cocina_json'] || row[:cocina_json]
      payload.nil? || (payload.respond_to?(:empty?) && payload.empty?)
    end

    def merge_cocina_payloads(rows, cocina_by_druid)
      rows.map do |row|
        druid = druid_from_row(row)
        next row unless druid && needs_enrichment?(row)

        cocina_json = cocina_by_druid[druid]
        if cocina_json
          row.merge('cocina_json' => cocina_json)
        else
          row.merge('cocina_enrichment_warning' => ENRICHMENT_WARNING)
        end
      end
    end

    def fetch_cocina_by_druid(druids)
      DorServicesRecord.with_readonly_connection do |connection|
        quoted_druids = druids.map { |druid| connection.quote(druid) }.join(', ')

        sql = <<~SQL.squish
          SELECT
            ro.external_identifier AS druid,
            jsonb_build_object(
              'externalIdentifier', ro.external_identifier,
              'version', rov.version,
              'head', (ro.head_version_id = rov.id),
              'cocinaVersion', rov.cocina_version,
              'type', rov.content_type,
              'label', rov.label,
              'description', rov.description,
              'identification', rov.identification,
              'structural', rov.structural,
              'administrative', rov.administrative,
              'access', rov.access
            ) AS cocina_json
          FROM repository_objects ro
          JOIN repository_object_versions rov
            ON ro.head_version_id = rov.id
          WHERE ro.external_identifier IN (#{quoted_druids})
        SQL

        connection.select_all(sql).to_a.to_h do |row|
          [row['druid'], row['cocina_json']]
        end
      end
    end
  end
end
