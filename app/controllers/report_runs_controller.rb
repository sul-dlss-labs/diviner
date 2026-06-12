# frozen_string_literal: true

require 'csv'

class ReportRunsController < ApplicationController
  def index
    @report_runs = ReportRun.order(created_at: :desc).limit(100)
  end

  def show
    @report_run = ReportRun.find(params.expect(:id))
  end

  def new
    @report_run = ReportRun.new
  end

  def create
    user_request = report_run_params[:user_request].to_s
    @report_run = ReportRun.create!(
      user_request: user_request,
      status: :generating,
      generated_sql: '',
      result_rows: [],
      row_count: 0,
      error_message: nil
    )
    GenerateReportSqlJob.perform_later(@report_run.id)

    redirect_to report_run_path(@report_run),
                notice: 'Working on your report request. SQL generation is running in the background.'
  rescue StandardError => e
    @report_run = ReportRun.new(user_request: user_request)
    flash.now[:alert] = "Could not generate SQL: #{e.message}"
    render :new, status: :unprocessable_content
  end

  def update
    @report_run = ReportRun.find(params.expect(:id))

    original_user_request = @report_run.user_request
    @report_run.assign_attributes(report_run_params)

    if @report_run.user_request != original_user_request
      @report_run.update!(
        status: :generating,
        generated_sql: '',
        sql_generation_duration_ms: nil,
        execution_duration_ms: nil,
        result_rows: [],
        row_count: 0,
        error_message: nil
      )
      GenerateReportSqlJob.perform_later(@report_run.id, run_after_generate: params[:run_now] == '1')

      notice = if params[:run_now] == '1'
                 'Updating request. SQL generation and report execution are running in the background.'
               else
                 'Updating request. SQL generation is running in the background.'
               end
      redirect_to report_run_path(@report_run), notice: notice
    elsif params[:run_now] == '1'
      start_report_execution!(@report_run)
      respond_report_enqueued(@report_run, notice: 'Running report in the background.')
    else
      @report_run.save!
      redirect_to report_run_path(@report_run), notice: 'Report request updated.'
    end
  rescue StandardError => e
    mark_report_failed(@report_run, e)
    redirect_to report_run_path(@report_run || params[:id]), alert: "Report update failed: #{e.message}"
  end

  def regenerate_sql
    @report_run = ReportRun.find(params.expect(:id))

    @report_run.user_request = report_run_params[:user_request] if report_run_params[:user_request].present?
    @report_run.update!(
      status: :generating,
      generated_sql: '',
      sql_generation_duration_ms: nil,
      execution_duration_ms: nil,
      result_rows: [],
      row_count: 0,
      error_message: nil
    )
    GenerateReportSqlJob.perform_later(@report_run.id)

    redirect_to report_run_path(@report_run), notice: 'Regenerating SQL in the background.'
  rescue StandardError => e
    mark_report_failed(@report_run, e)
    redirect_to report_run_path(@report_run || params[:id]), alert: "SQL regeneration failed: #{e.message}"
  end

  def run
    @report_run = ReportRun.find(params.expect(:id))
    if @report_run.generated_sql.blank?
      respond_report_enqueue_blocked(@report_run)
      return
    end

    start_report_execution!(@report_run)
    respond_report_enqueued(@report_run, notice: 'Running report in the background.')
  rescue StandardError => e
    mark_report_failed(@report_run, e)
    respond_report_enqueue_failed(@report_run, e)
  end

  def download
    @report_run = ReportRun.find(params.expect(:id))
    send_csv(@report_run)
  end

  def cocina
    @report_run = ReportRun.find(params.expect(:id))
    druid = params[:druid].to_s
    row_index = params[:row].to_i

    if druid.blank?
      render_cocina_error('druid is required', status: :unprocessable_content)
      return
    end

    cocina_json = Diviner::CocinaLookup.call(druid)

    if cocina_json.present?
      render partial: 'report_runs/cocina_row', locals: {
        report_run: @report_run,
        row_id: row_index,
        druid: druid,
        cocina_json: cocina_json,
        warning: nil
      }
    else
      render_cocina_error(Diviner::CocinaRowEnricher::ENRICHMENT_WARNING, row_id: row_index, druid: druid,
                                                                          status: :not_found)
    end
  rescue StandardError => e
    render_cocina_error(e.message, row_id: row_index, druid: druid, status: :unprocessable_content)
  end

  private

  def report_run_params
    params.fetch(:report_run, {}).permit(:user_request)
  end

  def send_csv(report_run)
    rows = report_run.rows
    csv_string = CSV.generate(headers: true) do |csv|
      if rows.any?
        headers = rows.first.keys
        csv << headers
        rows.each { |row| csv << headers.map { |h| row[h] } }
      end
    end

    send_data csv_string,
              filename: "report-run-#{report_run.id}.csv",
              type: 'text/csv; charset=utf-8'
  end

  def start_report_execution!(report_run)
    report_run.update!(status: :running, error_message: nil)
    RunReportJob.perform_later(report_run.id)
  end

  def respond_report_enqueued(report_run, notice:)
    respond_to do |format|
      format.html { redirect_to report_run_path(report_run), notice: }
      format.turbo_stream { render_state_turbo_stream(report_run, notice: notice) }
    end
  end

  def respond_report_enqueue_blocked(report_run)
    alert = 'Cannot run this report yet because SQL generation has not completed.'

    respond_to do |format|
      format.html { redirect_to report_run_path(report_run), alert: }
      format.turbo_stream { render_state_turbo_stream(report_run, alert: alert) }
    end
  end

  def respond_report_enqueue_failed(report_run, error)
    alert = "Report execution failed: #{error.message}"

    respond_to do |format|
      format.html { redirect_to report_run_path(report_run), alert: }
      format.turbo_stream { render_state_turbo_stream(report_run, alert: alert) }
    end
  end

  def render_state_turbo_stream(report_run, notice: nil, alert: nil)
    flash.now[:notice] = notice if notice.present?
    flash.now[:alert] = alert if alert.present?

    render turbo_stream: turbo_stream.replace(
      report_run.state_dom_id,
      partial: 'report_runs/state_frame',
      locals: { report_run: report_run }
    )
  end

  def render_cocina_error(message, row_id: 0, druid: nil, status: :unprocessable_content)
    render partial: 'report_runs/cocina_row',
           status: status,
           locals: {
             report_run: @report_run,
             row_id: row_id,
             druid: druid,
             cocina_json: nil,
             warning: message
           }
  end

  def mark_report_failed(report_run, error)
    report_run&.update(status: :failed, error_message: error.message)
  end
end
