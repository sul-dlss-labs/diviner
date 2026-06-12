# frozen_string_literal: true

require 'json'

module Diviner
  # Normalizes LLM SQL payloads by stripping wrappers and extracting plain SQL.
  module SqlPayload
    module_function

    def extract(raw_text)
      candidate = normalize(raw_text.to_s)

      parsed = parse_json_object(candidate)
      return parsed['sql'].to_s.strip if parsed.is_a?(Hash) && parsed['sql'].present?

      sql_string = candidate[/"sql"\s*:\s*"((?:\\.|[^"\\])*)"/m, 1]
      return JSON.parse("\"#{sql_string}\"").to_s.strip if sql_string.present?

      candidate
    rescue JSON::ParserError
      candidate
    end

    def normalize(text)
      cleaned = text.strip
      cleaned = cleaned.gsub(/\A```(?:json|sql)?\s*/i, '').gsub(/\s*```\z/, '')
      cleaned = cleaned.sub(/\AWrite query attempted while in readonly mode:\s*/i, '')
      cleaned = cleaned.sub(/\A(?:sql|json)\s*[:-]?\s*/i, '')
      cleaned.to_s.strip
    end
    private_class_method :normalize

    def parse_json_object(candidate)
      return unless candidate.start_with?('{') && candidate.end_with?('}')

      JSON.parse(candidate)
    end
    private_class_method :parse_json_object
  end
end
