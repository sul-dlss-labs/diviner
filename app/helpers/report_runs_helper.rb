# frozen_string_literal: true

require 'json'

module ReportRunsHelper
  SQL_KEYWORDS = %w[
    WITH SELECT FROM WHERE JOIN INNER LEFT RIGHT FULL OUTER ON AND OR AS
    GROUP ORDER BY LIMIT OFFSET EXISTS DISTINCT COUNT OVER
  ].freeze

  def formatted_duration(ms)
    return 'n/a' if ms.blank?

    format('%.2fs', ms.to_f / 1000.0)
  end

  def pretty_sql(sql)
    cleaned_sql = Diviner::SqlPayload.extract(sql)
    formatted = format_sql(cleaned_sql.to_s)
    escaped = ERB::Util.html_escape(formatted)
    highlighted = SQL_KEYWORDS.reduce(escaped) do |memo, keyword|
      memo.gsub(/\b#{Regexp.escape(keyword)}\b/i, '<span class="sql-keyword">\\0</span>')
    end

    content_tag(:pre, highlighted.html_safe, class: 'sql-preview') # rubocop:disable Rails/OutputSafety
  end

  def cocina_json_from_row(row)
    payload = row['cocina_json'] || row[:cocina_json]
    return payload if payload.present?

    nil
  end

  def druid_from_row(row)
    row_hash = row.respond_to?(:to_h) ? row.to_h : {}

    row_hash['druid'] ||
      row_hash[:druid] ||
      row_hash['external_identifier'] ||
      row_hash[:external_identifier] ||
      row_hash['externalIdentifier'] ||
      row_hash[:externalIdentifier]
  end

  def cocina_enrichment_warning_from_row(row)
    row['cocina_enrichment_warning'] || row[:cocina_enrichment_warning]
  end

  def pretty_cocina_json(cocina_json)
    payload = cocina_json.is_a?(String) ? JSON.parse(cocina_json) : cocina_json
    cleaned = prune_empty(payload || {})
    render_json_node(cleaned, root: true)
  rescue JSON::ParserError
    content_tag(:pre, cocina_json.to_s, class: 'sql-preview')
  end

  private

  def format_sql(sql)
    text = sql.strip
    text = text.gsub(/\s+/, ' ')
    text = text.gsub(/\b(FROM|WHERE|GROUP BY|ORDER BY|LIMIT|OFFSET)\b/i, "\n\\1")
    text = text.gsub(/\b(INNER JOIN|LEFT JOIN|RIGHT JOIN|FULL JOIN|JOIN)\b/i, "\n\\1")
    text = text.gsub(/\b(AND|OR)\b/i, "\n  \\1")
    text = text.gsub(/\b(SELECT)\b/i, '\\1')
    text.strip
  end

  def prune_empty(value)
    case value
    when Hash
      value.each_with_object({}) do |(k, v), out|
        pruned = prune_empty(v)
        next if pruned.nil? || pruned == '' || pruned == {} || pruned == []

        out[k] = pruned
      end
    when Array
      value.map { |item| prune_empty(item) }
           .reject { |item| item.nil? || item == '' || item == {} || item == [] }
    else
      value
    end
  end

  def render_json_node(node, key: nil, root: false)
    case node
    when Hash
      summary_label = key ? "#{key}: {#{node.size}}" : "{#{node.size}}"
      content_tag(:details, open: root, class: 'json-node json-object') do
        concat content_tag(:summary, summary_label, class: 'json-summary')
        concat(
          content_tag(:ul, class: 'json-list') do
            safe_join(
              node.map do |child_key, child_value|
                content_tag(:li, render_json_node(child_value, key: child_key), class: 'json-item')
              end
            )
          end
        )
      end
    when Array
      summary_label = key ? "#{key}: [#{node.size}]" : "[#{node.size}]"
      content_tag(:details, open: false, class: 'json-node json-array') do
        concat content_tag(:summary, summary_label, class: 'json-summary')
        concat(
          content_tag(:ul, class: 'json-list') do
            safe_join(
              node.each_with_index.map do |child_value, index|
                content_tag(:li, render_json_node(child_value, key: "[#{index}]"), class: 'json-item')
              end
            )
          end
        )
      end
    else
      render_json_scalar(node, key: key)
    end
  end

  def render_json_scalar(value, key: nil)
    key_span = key ? content_tag(:span, "#{key}: ", class: 'json-key') : ''.html_safe

    value_span = case value
                 when String
                   content_tag(:span, value.to_json, class: 'json-string')
                 when Numeric
                   content_tag(:span, value, class: 'json-number')
                 when true, false
                   content_tag(:span, value.to_s, class: 'json-boolean')
                 when NilClass
                   content_tag(:span, 'null', class: 'json-null')
                 else
                   content_tag(:span, value.to_s, class: 'json-string')
                 end

    safe_join([key_span, value_span])
  end
end
