# frozen_string_literal: true

module Diviner
  # Applies small deterministic quality rewrites to generated SQL.
  class SqlQualityRewriter
    def self.call(sql)
      new(sql).call
    end

    def initialize(sql)
      @sql = sql.to_s
    end

    def call
      rewritten = @sql.dup

      # Fix common enum misuse for repository object type.
      rewritten.gsub!(/\bro\.object_type\s*=\s*'item'/i, "ro.object_type = 'dro'")
      rewritten.gsub!(/\brepository_objects\.object_type\s*=\s*'item'/i, "repository_objects.object_type = 'dro'")

      # Prefer the current-head join shape.
      rewritten.gsub!(
        /repository_objects\.current_version_id\s*=\s*repository_object_versions\.id/i,
        'repository_objects.head_version_id = repository_object_versions.id'
      )

      # Narrow broad title scan patterns to value-only nodes when safe to do so.
      rewritten.gsub!(
        /\$\.title\.\*\*\s*\?\s*\(@\.type\(\)\s*==\s*"string"\s*&&\s*@\s*like_regex\s*"\(\?i\)([^"]+)"\)/,
        '$.title.**.value ? (@.type() == "string" && @ like_regex "(?i)\\1")'
      )

      # Prefer strict recursive descent when a generated query uses .** without it.
      rewritten.gsub!(/(?<!strict )\$\.\*\*\./, 'strict $.**.')
      rewritten.gsub!(/(?<!strict )\$\.title\.\*\*\./, 'strict $.title.**.')
      rewritten.gsub!(/(?<!strict )\$\.event\.\*\*\./, 'strict $.event.**.')
      rewritten.gsub!(/(?<!strict )\$\.contributor\.\*\*\./, 'strict $.contributor.**.')

      # Prefer the canonical folio catalog-record-id extraction path.
      rewritten.gsub!(
        /jsonb_path_query\(([^,]+),\s*'\$\.catalogLinks\[\*\]\.catalogRecordId'\)\s*->>\s*0/i,
        "jsonb_path_query(\\1, '$.catalogLinks[*] ? (@.catalog == \"folio\").catalogRecordId') ->> 0"
      )

      rewritten
    end
  end
end
