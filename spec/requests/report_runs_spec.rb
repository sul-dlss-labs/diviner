# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe 'ReportRuns' do
  describe 'GET /report_runs/new' do
    it 'renders the report builder' do
      get new_report_run_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Diviner Report Builder')
    end
  end

  describe 'POST /report_runs' do
    it 'creates a generating report run and enqueues SQL generation' do
      expect do
        post report_runs_path, params: { report_run: { user_request: 'count invalid uris' } }
      end.to change(ReportRun, :count).by(1)

      report_run = ReportRun.order(:id).last
      expect(report_run.user_request).to eq('count invalid uris')
      expect(report_run).to be_generating
      expect(report_run.generated_sql).to eq('')
      expect(response).to redirect_to(report_run_path(report_run))
      expect(GenerateReportSqlJob).to have_been_enqueued.with(report_run.id)
    end

    it 're-renders the form when validation fails' do
      post report_runs_path, params: { report_run: { user_request: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(ReportRun.count).to eq(0)
    end
  end

  describe 'GET /report_runs/:id' do
    it 'does not expose editable generated SQL fields' do
      report_run = ReportRun.create!(user_request: 'read-only sql', generated_sql: 'SELECT 1 AS one', status: :planned)

      get report_run_path(report_run)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Generated SQL')
      expect(response.body).not_to include('report_run_generated_sql')
    end
  end

  describe 'PATCH /report_runs/:id' do
    let!(:report_run) do
      ReportRun.create!(user_request: 'original request', generated_sql: 'SELECT 1 AS one', status: :succeeded,
                        result_rows: [{ 'one' => 1 }], row_count: 1, execution_duration_ms: 12)
    end

    it 'enqueues SQL regeneration when the request changes' do
      patch report_run_path(report_run), params: { report_run: { user_request: 'new request' } }

      report_run.reload
      expect(report_run).to be_generating
      expect(report_run.generated_sql).to eq('')
      expect(report_run.row_count).to eq(0)
      expect(response).to redirect_to(report_run_path(report_run))
      queued_job = enqueued_jobs.find { |job| job[:job] == GenerateReportSqlJob }
      expect(queued_job).to be_present
      expect(queued_job[:args].first).to eq(report_run.id)
    end

    it 'enqueues generation and run when request changes with run_now' do
      patch report_run_path(report_run), params: {
        report_run: { user_request: 'new request' },
        run_now: '1'
      }

      expect(response).to redirect_to(report_run_path(report_run))
      expect(GenerateReportSqlJob).to have_been_enqueued.with(report_run.id, run_after_generate: true)
    end

    it 'enqueues run when request is unchanged and run_now is set' do
      patch report_run_path(report_run), params: {
        report_run: { user_request: 'original request' },
        run_now: '1'
      }

      report_run.reload
      expect(report_run).to be_running
      expect(response).to redirect_to(report_run_path(report_run))
      expect(RunReportJob).to have_been_enqueued.with(report_run.id)
    end
  end

  describe 'POST /report_runs/:id/regenerate_sql' do
    let!(:report_run) do
      ReportRun.create!(user_request: 'old request', generated_sql: 'SELECT 1 AS one', status: :failed,
                        error_message: 'old error', result_rows: [{ 'one' => 1 }], row_count: 1, execution_duration_ms: 50)
    end

    it 'resets state and enqueues SQL regeneration' do
      post regenerate_sql_report_run_path(report_run), params: { report_run: { user_request: 'fresh request' } }

      report_run.reload
      expect(report_run.user_request).to eq('fresh request')
      expect(report_run).to be_generating
      expect(report_run.generated_sql).to eq('')
      expect(report_run.execution_duration_ms).to be_nil
      expect(report_run.error_message).to be_nil
      expect(response).to redirect_to(report_run_path(report_run))
      queued_job = enqueued_jobs.find { |job| job[:job] == GenerateReportSqlJob }
      expect(queued_job).to be_present
      expect(queued_job[:args].first).to eq(report_run.id)
    end
  end

  describe 'POST /report_runs/:id/run' do
    it 'enqueues execution when SQL is available' do
      report_run = ReportRun.create!(user_request: 'run it', generated_sql: 'SELECT 7 AS seven', status: :planned)

      post run_report_run_path(report_run)

      report_run.reload
      expect(report_run).to be_running
      expect(response).to redirect_to(report_run_path(report_run))
      expect(RunReportJob).to have_been_enqueued.with(report_run.id)
    end

    it 'rejects execution while SQL is still missing' do
      report_run = ReportRun.create!(user_request: 'run it', generated_sql: '', status: :generating)

      post run_report_run_path(report_run)

      expect(response).to redirect_to(report_run_path(report_run))
      expect(flash[:alert]).to eq('Cannot run this report yet because SQL generation has not completed.')
      expect(RunReportJob).not_to have_been_enqueued
    end
  end

  describe 'GET /report_runs/:id/cocina' do
    let!(:report_run) do
      ReportRun.create!(
        user_request: 'fetch cocina',
        generated_sql: 'SELECT druid FROM rows',
        status: :succeeded,
        result_rows: [{ 'druid' => 'druid:aa111bb2222' }],
        row_count: 1
      )
    end

    it 'renders lazy-loaded cocina payload for a druid' do
      allow(Diviner::CocinaLookup).to receive(:call).with('druid:aa111bb2222').and_return({ 'type' => 'book' })

      get cocina_report_run_path(report_run), params: { druid: 'druid:aa111bb2222', row: 0 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turbo-frame id=\"report_run_#{report_run.id}_druid_0\"")
      expect(response.body).to include('type: ')
      expect(response.body).to include('&quot;book&quot;')
    end

    it 'renders warning when cocina payload is unavailable' do
      allow(Diviner::CocinaLookup).to receive(:call).with('druid:aa111bb2222').and_return(nil)

      get cocina_report_run_path(report_run), params: { druid: 'druid:aa111bb2222', row: 0 }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include(Diviner::CocinaRowEnricher::ENRICHMENT_WARNING)
    end
  end

  describe 'GET /report_runs/:id/download.csv' do
    let!(:report_run) do
      ReportRun.create!(
        user_request: 'download it',
        generated_sql: 'SELECT * FROM rows',
        status: :succeeded,
        result_rows: [{ 'druid' => 'druid:aa111bb2222', 'count' => 3 }],
        row_count: 1
      )
    end

    it 'returns CSV output for saved rows' do
      get download_report_run_path(report_run, format: :csv)

      parsed = CSV.parse(response.body, headers: true)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/csv')
      expect(parsed.headers).to contain_exactly('druid', 'count')
      expect(parsed.first.to_h).to eq('druid' => 'druid:aa111bb2222', 'count' => '3')
    end
  end
end
