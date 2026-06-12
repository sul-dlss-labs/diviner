# frozen_string_literal: true

require 'json'

module Diviner
  # Validates and executes read-only SQL against dor-services.
  class SafeSqlRunner
    MAX_LIMIT = 500
    FORBIDDEN_KEYWORDS = %w[
      INSERT UPDATE DELETE DROP ALTER TRUNCATE GRANT REVOKE
      CREATE COMMENT ANALYZE VACUUM REFRESH
    ].freeze

    class Error < StandardError; end

    def self.call(sql)
      new(sql).call
    end

    def initialize(sql)
      @sql = sql.to_s
    end

    def call
      normalized = normalize_sql(@sql)
      statements = split_statements(normalized)
      validate!(statements)

      DorServicesRecord.with_readonly_connection do |connection|
        last_rows = []

        connection.transaction do
          connection.execute("SET LOCAL statement_timeout = '10s'")
          connection.execute('SET LOCAL transaction_read_only = on')

          statements.each_with_index do |statement, index|
            keyword = leading_keyword(statement)
            next if transaction_control_statement?(keyword)

            if index == statements.length - 1 && limitable_query_statement?(keyword)
              statement = apply_default_limit(statement)
            end

            if row_returning_statement?(keyword)
              last_rows = connection.select_all(statement).to_a
            elsif non_returning_readonly_statement?(keyword)
              connection.execute(statement)
            else
              raise Error, "Unsupported SQL statement prefix: #{keyword}"
            end
          end
        end

        last_rows
      end
    rescue StandardError => e
      raise Error, e.message
    end

    private

    def normalize_sql(sql)
      text = extract_sql_payload(sql.to_s)
      text = text.strip
      text = text.gsub(/\A```(?:sql)?\s*/i, '').gsub(/\s*```\z/, '')
      text = text.sub(/\A(?:sql\s*[:-])\s*/i, '')

      without_line_comments = text.gsub(/--.*$/, '')
      without_block_comments = without_line_comments.gsub(%r{/\*.*?\*/}m, '')
      without_block_comments.strip
    end

    def extract_sql_payload(text)
      candidate = text.to_s.strip

      # Common error wrapper prefix from previous failures.
      candidate = candidate.sub(/\AWrite query attempted while in readonly mode:\s*/i, '')
      candidate = candidate.sub(/\Ajson\s*/i, '').strip

      if candidate.start_with?('{') && candidate.end_with?('}')
        parsed = JSON.parse(candidate)
        return parsed['sql'].to_s if parsed.is_a?(Hash) && parsed.key?('sql')
        return parsed[:sql].to_s if parsed.is_a?(Hash) && parsed.key?(:sql)
      end

      # Fallback: pull SQL string directly from a JSON-like snippet.
      sql_string = candidate[/"sql"\s*:\s*"((?:\\.|[^"\\])*)"/m, 1]
      return JSON.parse("\"#{sql_string}\"") if sql_string.present?

      candidate
    rescue JSON::ParserError
      candidate
    end

    def split_statements(sql)
      statements = []
      current = +''
      in_single_quote = false
      in_double_quote = false

      sql.each_char do |char|
        if char == "'" && !in_double_quote
          in_single_quote = !in_single_quote
          current << char
          next
        end

        if char == '"' && !in_single_quote
          in_double_quote = !in_double_quote
          current << char
          next
        end

        if char == ';' && !in_single_quote && !in_double_quote
          trimmed = current.strip
          statements << trimmed unless trimmed.empty?
          current = +''
        else
          current << char
        end
      end

      trimmed = current.strip
      statements << trimmed unless trimmed.empty?
      statements
    end

    def validate!(statements)
      raise Error, 'SQL cannot be blank.' if statements.empty?

      statements.each do |statement|
        validate_statement!(statement)
      end
    end

    def validate_statement!(sql)
      raise Error, 'SQL statement is malformed.' if leading_keyword(sql).empty?

      forbidden = FORBIDDEN_KEYWORDS.find { |forbidden_keyword| sql.match?(/\b#{forbidden_keyword}\b/i) }
      raise Error, "Forbidden keyword detected: #{forbidden}" if forbidden
    end

    def leading_keyword(sql)
      sql.to_s[/\A\s*([A-Za-z]+)/, 1].to_s.upcase
    end

    def transaction_control_statement?(keyword)
      %w[BEGIN COMMIT ROLLBACK].include?(keyword)
    end

    def row_returning_statement?(keyword)
      %w[WITH SELECT EXPLAIN SHOW VALUES TABLE].include?(keyword)
    end

    def limitable_query_statement?(keyword)
      %w[WITH SELECT TABLE].include?(keyword)
    end

    def non_returning_readonly_statement?(keyword)
      %w[SET].include?(keyword)
    end

    def apply_default_limit(sql)
      return sql if sql.match?(/\bLIMIT\s+\d+\b/i)

      "#{sql}\nLIMIT #{MAX_LIMIT}"
    end
  end
end
