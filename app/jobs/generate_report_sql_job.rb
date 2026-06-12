# frozen_string_literal: true

require 'benchmark'

class GenerateReportSqlJob < ApplicationJob
  queue_as :default

  def perform(report_run_id, run_after_generate: false)
    report_run = ReportRun.find_by(id: report_run_id)
    return unless report_run

    raw_sql = nil
    sql_generation_duration_ms = Benchmark.realtime do
      raw_sql = Diviner::ReportSqlPlanner.call(user_request: report_run.user_request)
    end

    generated_sql = Diviner::SqlPayload.extract(raw_sql)
    raise 'Generated SQL was empty.' if generated_sql.blank?

    report_run.update!(
      generated_sql: generated_sql,
      sql_generation_duration_ms: (sql_generation_duration_ms * 1000).round,
      status: :planned,
      error_message: nil,
      execution_duration_ms: nil,
      result_rows: [],
      row_count: 0
    )

    if run_after_generate
      report_run.update!(status: :running)
      RunReportJob.perform_later(report_run.id)
    end
  rescue StandardError => e
    report_run&.update(status: :failed, error_message: e.message)
  end
end
