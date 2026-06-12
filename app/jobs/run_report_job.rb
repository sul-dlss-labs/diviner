# frozen_string_literal: true

require 'benchmark'

class RunReportJob < ApplicationJob
  queue_as :default

  def perform(report_run_id)
    report_run = ReportRun.find_by(id: report_run_id)
    return unless report_run
    return unless report_run.running?

    sql = Diviner::SqlPayload.extract(report_run.generated_sql)
    raise 'Cannot run report before SQL has been generated.' if sql.blank?

    report_run.update!(error_message: nil, generated_sql: sql)

    rows = nil
    execution_duration_ms = Benchmark.realtime do
      rows = Diviner::SafeSqlRunner.call(sql)
    end

    normalized_rows = Array(rows).map { |row| row.respond_to?(:to_h) ? row.to_h : row }

    report_run.update!(
      status: :succeeded,
      result_rows: normalized_rows,
      row_count: normalized_rows.length,
      execution_duration_ms: (execution_duration_ms * 1000).round,
      error_message: nil
    )
  rescue StandardError => e
    report_run&.update(status: :failed, error_message: e.message)
  end
end
