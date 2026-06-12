# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateReportSqlJob do
  it 'generates SQL, strips JSON wrapper artifacts, and marks report as planned' do
    report_run = ReportRun.create!(user_request: 'find something', generated_sql: '', status: :generating)
    allow(Diviner::ReportSqlPlanner).to receive(:call).with(user_request: 'find something').and_return('{"sql":"SELECT 1 AS one"}')

    described_class.perform_now(report_run.id)

    report_run.reload
    expect(report_run).to be_planned
    expect(report_run.generated_sql).to eq('SELECT 1 AS one')
    expect(report_run.sql_generation_duration_ms).to be >= 0
    expect(report_run.error_message).to be_nil
  end

  it 'marks running and queues execution when run_after_generate is requested' do
    report_run = ReportRun.create!(user_request: 'find something', generated_sql: '', status: :generating)
    allow(Diviner::ReportSqlPlanner).to receive(:call).and_return('SELECT 9 AS nine')

    expect do
      described_class.perform_now(report_run.id, run_after_generate: true)
    end.to have_enqueued_job(RunReportJob).with(report_run.id)

    report_run.reload
    expect(report_run).to be_running
  end

  it 'marks report as failed when generation raises' do
    report_run = ReportRun.create!(user_request: 'find something', generated_sql: '', status: :generating)
    allow(Diviner::ReportSqlPlanner).to receive(:call).and_raise(StandardError, 'planner offline')

    described_class.perform_now(report_run.id)

    report_run.reload
    expect(report_run).to be_failed
    expect(report_run.error_message).to eq('planner offline')
  end
end
