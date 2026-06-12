# frozen_string_literal: true

module Diviner
  # Retrieves best-effort Cocina snippets for a user request.
  class CocinaContext
    MAX_DOCS = 12
    MAX_CHARS_PER_DOC = 1_000_000_000_000

    def self.for_request(user_request)
      new(user_request).for_request
    end

    def initialize(user_request)
      @user_request = user_request.to_s
    end

    def for_request
      docs = ranked_docs.first(MAX_DOCS)
      return '(no local cocina schema docs loaded; run rake cocina:ingest_models)' if docs.empty?

      docs.map do |doc|
        <<~TEXT
          FILE: #{doc.path}
          #{doc.content.to_s[0...MAX_CHARS_PER_DOC]}
        TEXT
      end.join("\n\n")
    end

    private

    def ranked_docs
      tokens = tokenize(@user_request)
      all_docs = CocinaSchemaDocument.limit(200).to_a

      all_docs.sort_by do |doc|
        score = tokens.sum { |token| doc.content.to_s.downcase.scan(token).size }
        -score
      end.reject do |doc|
        tokens.any? && tokens.none? { |token| doc.content.to_s.downcase.include?(token) }
      end.presence || all_docs.first(MAX_DOCS)
    end

    def tokenize(text)
      text.downcase.scan(/[a-z0-9_]{3,}/).uniq.first(20)
    end
  end
end
