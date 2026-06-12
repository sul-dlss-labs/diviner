# frozen_string_literal: true

require 'json'
require_relative 'content_type_resolver'

module Diviner
  # Uses RubyLLM to translate report requests into SQL.
  class ReportSqlPlanner
    SYSTEM_PROMPT = <<~PROMPT
      You are a PostgreSQL expert generating SQL for the dor-services database.
      Return SQL only. No markdown. No prose.

      Rules:
      - Read-only SQL only.
      - Use explicit table aliases and constrained predicates where reasonable.
      - repository_objects.object_type is enum(dro, admin_policy, collection); use 'dro' for DRO queries.
      - For current object state, prefer ro.head_version_id = rov.id.
      - For title matching use only description.title value nodes ($.title.**.value).
      - For recursive JSON paths with .**, prefer strict mode.
      - Prefer one row per repository object in the final result.
      - Push grouping, deduplication, and anomaly detection into SQL rather than Ruby.
      - Prefer jsonb_path_exists for filtering and jsonb_path_query/jsonb_path_query_array for projection.
      - Prefer grouped CTEs and aggregates such as array_agg(DISTINCT ...), COUNT(DISTINCT ...), bool_or, and HAVING for audit-style reports.
      - Include LIMIT 500 unless the user explicitly requests a smaller number.
      - Do not use DDL or DML.
    PROMPT

    def self.call(user_request:)
      new(user_request:).call
    end

    def initialize(user_request:)
      @user_request = user_request.to_s
    end

    def call
      schema_context = Diviner::DorServicesSchema.snapshot
      cocina_context = Diviner::CocinaContext.for_request(@user_request)
      content_type_hints = Diviner::ContentTypeResolver.hints_for_request(@user_request)

      prompt = <<~PROMPT
        #{SYSTEM_PROMPT}

        User request:
        #{@user_request}

        Use the model_tool first to gather schema + SQL guidance before producing output.

        dor-services schema snapshot:
        #{schema_context}

        Content type guidance:
        - Content types are stored on repository_object_versions.content_type.
        - Content type values are HTTPS URIs under #{Diviner::ContentTypeResolver::BASE_URI}.
        #{format_content_type_hints(content_type_hints)}

        Cocina context snippets:
        #{cocina_context}
      PROMPT

      response = Diviner::ReportAgent.new.ask(prompt)
      content = response.content
      parsed = content.is_a?(Hash) ? content : JSON.parse(content.to_s)

      sql = parsed['sql'] || parsed[:sql] || content.to_s.strip
      Diviner::SqlQualityRewriter.call(Diviner::SqlPayload.extract(sql))
    rescue JSON::ParserError
      Diviner::SqlQualityRewriter.call(Diviner::SqlPayload.extract(content.to_s.strip))
    end

    def format_content_type_hints(hints)
      lines = hints.fetch(:uris, []).map { |uri| "- Use provided content type URI as-is: #{uri}" }

      lines += hints.fetch(:resolved, []).map do |entry|
        "- Resolved content type '#{entry.fetch(:input)}' to URI: #{entry.fetch(:uri)}"
      end

      if lines.empty?
        return '- No explicit content type value provided; if needed, resolve plain names to canonical Cocina URIs.'
      end

      lines.join("\n")
    end
  end
end
