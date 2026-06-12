# frozen_string_literal: true

module Diviner
  # Builds compact DB structure context from dor-services for prompting.
  class DorServicesSchema
    MAX_TABLES = 60

    def self.snapshot
      new.snapshot
    end

    def snapshot
      rows = DorServicesRecord.with_readonly_connection do |connection|
        connection.select_all(<<~SQL.squish).to_a
          SELECT table_name, column_name, data_type
          FROM information_schema.columns
          WHERE table_schema = 'public'
          ORDER BY table_name, ordinal_position
        SQL
      end

      grouped = rows.group_by { |row| row['table_name'] }.first(MAX_TABLES)
      grouped.map do |table_name, cols|
        "#{table_name}(#{cols.map { |c| "#{c['column_name']}:#{c['data_type']}" }.join(', ')})"
      end.join("\n")
    rescue StandardError => e
      "(dor-services schema unavailable: #{e.message})"
    end
  end
end
