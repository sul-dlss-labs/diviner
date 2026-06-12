# frozen_string_literal: true

module Diviner
  # Fetches current Cocina JSON for a single druid from dor-services.
  module CocinaLookup
    module_function

    def call(druid)
      return if druid.blank?

      DorServicesRecord.with_readonly_connection do |connection|
        quoted_druid = connection.quote(druid)

        sql = <<~SQL.squish
          SELECT
            jsonb_build_object(
              'externalIdentifier', ro.external_identifier,
              'version', rov.version,
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
          WHERE ro.external_identifier = #{quoted_druid}
          LIMIT 1
        SQL

        connection.select_value(sql)
      end
    end
  end
end
