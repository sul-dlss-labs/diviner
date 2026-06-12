# frozen_string_literal: true

require 'json'
require 'digest'
require 'open-uri'

namespace :cocina do
  desc 'Ingest Cocina schema/docs from sul-dlss/cocina-models into local DB context store'
  task ingest_models: :environment do
    puts 'Fetching cocina-models file tree...'

    tree_json = URI.parse('https://api.github.com/repos/sul-dlss/cocina-models/git/trees/main?recursive=1').read
    tree = JSON.parse(tree_json)

    include_path = lambda do |path|
      path == 'schema.json' ||
        (path.start_with?('docs/') && path.end_with?('.md', '.jsonld')) ||
        (path.start_with?('lib/cocina/models/') && path.end_with?('.rb'))
    end

    paths = tree.fetch('tree').filter_map do |entry|
      next unless entry['type'] == 'blob'

      path = entry['path']
      next unless include_path.call(path)

      path
    end

    puts "Found #{paths.size} candidate files"

    upserted = 0
    skipped = 0

    paths.each do |path|
      raw_url = "https://raw.githubusercontent.com/sul-dlss/cocina-models/main/#{path}"
      content = URI.parse(raw_url).read
      digest = Digest::SHA256.hexdigest(content)

      record = CocinaSchemaDocument.find_or_initialize_by(path: path)
      if record.digest == digest
        skipped += 1
        next
      end

      record.content = content
      record.digest = digest
      record.source = 'sul-dlss/cocina-models'
      record.save!
      upserted += 1
    rescue StandardError => e
      warn "Skipped #{path}: #{e.message}"
    end

    puts "Ingestion complete. Upserted=#{upserted} SkippedUnchanged=#{skipped} Total=#{paths.size}"
  end
end
