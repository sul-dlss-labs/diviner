# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RunReportJob do
  it 'runs SQL and marks report as succeeded' do
    report_run = ReportRun.create!(user_request: 'run', generated_sql: 'SELECT 1 AS one', status: :running)
    allow(Diviner::SafeSqlRunner).to receive(:call).with('SELECT 1 AS one').and_return([{ 'one' => 1 }])

    described_class.perform_now(report_run.id)

    report_run.reload
    expect(report_run).to be_succeeded
    expect(report_run.row_count).to eq(1)
    expect(report_run.rows).to eq([{ 'one' => 1 }])
    expect(report_run.execution_duration_ms).to be >= 0
  end

  it 'fails when SQL is unavailable for a running report' do
    report_run = ReportRun.create!(user_request: 'run', generated_sql: 'SELECT 1 AS one', status: :running)
    report_run.update_columns(generated_sql: '') # rubocop:disable Rails/SkipsModelValidations

    described_class.perform_now(report_run.id)

    report_run.reload
    expect(report_run).to be_failed
    expect(report_run.error_message).to eq('Cannot run report before SQL has been generated.')
  end

  it 'marks report failed when SQL execution raises' do
    report_run = ReportRun.create!(user_request: 'run', generated_sql: 'SELECT 7 AS seven', status: :running)
    allow(Diviner::SafeSqlRunner).to receive(:call).and_raise(StandardError, 'readonly failure')

    described_class.perform_now(report_run.id)

    report_run.reload
    expect(report_run).to be_failed
    expect(report_run.error_message).to eq('readonly failure')
  end

  it 'does not re-run jobs that are not currently running' do
    report_run = ReportRun.create!(user_request: 'run', generated_sql: 'SELECT 1 AS one', status: :planned)

    described_class.perform_now(report_run.id)

    report_run.reload
    expect(report_run).to be_planned
    expect(report_run.error_message).to be_nil
  end
end
