# frozen_string_literal: true

module Diviner
  # Resolves Cocina content type aliases to canonical HTTPS URIs.
  module ContentTypeResolver
    BASE_URI = 'https://cocina.sul.stanford.edu/models/'
    URI_PATTERN = %r{https://cocina\.sul\.stanford\.edu/models/[a-z0-9_-]+}i
    DEFAULT_OBJECT_TYPE_PATH = '/home/mjg/workspace/sul-dlss/cocina-models/lib/cocina/models/object_type.rb'

    DEFAULT_TYPE_SLUGS = %w[
      3d
      admin_policy
      agreement
      book
      collection
      curated-collection
      document
      exhibit
      file
      geo
      image
      manuscript
      map
      media
      object
      page
      photograph
      series
      track
      user-collection
      webarchive-binary
      webarchive-seed
    ].freeze

    module_function

    def known_uris
      @known_uris ||= begin
        slugs = slugs_from_cocina_models
        slugs = DEFAULT_TYPE_SLUGS if slugs.empty?
        slugs.uniq.sort.map { |slug| "#{BASE_URI}#{slug}" }
      end
    end

    def resolve(value)
      input = value.to_s.strip
      return if input.empty?
      return input if content_type_uri?(input)

      alias_to_uri[normalize(input)]
    end

    def content_type_uri?(value)
      value.to_s.match?(URI_PATTERN)
    end

    def hints_for_request(user_request)
      request = user_request.to_s
      uris = request.scan(URI_PATTERN).uniq

      return { uris: uris, resolved: [] } unless request_mentions_content_type?(request) || uris.any?

      resolved_matches = matched_aliases(request).filter_map do |matched_alias|
        uri = resolve(matched_alias)
        next unless uri

        { input: matched_alias, uri: uri }
      end

      resolved = resolved_matches.uniq { |entry| entry[:uri] }

      { uris: uris, resolved: resolved }
    end

    def request_mentions_content_type?(request)
      request.match?(/content[\s_-]?types?/i)
    end

    def matched_aliases(request)
      downcased_request = request.downcase

      alias_to_uri.keys
                  .sort_by { |alias_name| -alias_name.length }
                  .select do |alias_name|
        downcased_request.match?(alias_pattern(alias_name))
      end
    end

    def alias_pattern(alias_name)
      /\b#{Regexp.escape(alias_name)}\b/
    end

    def alias_to_uri
      @alias_to_uri ||= begin
        mapping = {}

        known_uris.each do |uri|
          slug = uri.delete_prefix(BASE_URI)
          aliases_for_slug(slug).each { |name| mapping[normalize(name)] = uri }
        end

        mapping
      end
    end

    def aliases_for_slug(slug)
      names = [slug, slug.tr('-', ' '), slug.tr('-', '_'), slug.tr('_', ' '), slug.tr('_', '-')]

      names += names.map { |name| pluralize(name) }

      names += ['three dimensional', 'three-dimensional'] if slug == '3d'

      names.uniq
    end

    def pluralize(name)
      return name if name.end_with?('s')

      "#{name}s"
    end

    def normalize(value)
      value.to_s.downcase.strip.gsub(/\A["']+|["']+\z/, '').tr('_', '-').squeeze(' ')
    end

    def slugs_from_cocina_models
      path = ENV.fetch('COCINA_MODELS_OBJECT_TYPE_PATH', DEFAULT_OBJECT_TYPE_PATH)
      return [] unless File.exist?(path)

      File.readlines(path).filter_map do |line|
        match = line.match(/property\s+:(?:'([^']+)'|([a-z_][\w-]*))/)
        match && (match[1] || match[2])
      end
    rescue StandardError
      []
    end
  end
end
