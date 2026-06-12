# frozen_string_literal: true

# Stores report planning and execution artifacts for user-requested SQL reports
class ReportRun < ApplicationRecord
  enum :status, {
    generating: 'generating',
    planned: 'planned',
    running: 'running',
    succeeded: 'succeeded',
    failed: 'failed'
  }, default: :planned, validate: true

  before_validation :normalize_generated_sql
  before_validation :ensure_generated_sql_not_null

  after_commit :broadcast_state

  validates :user_request, presence: true
  validates :generated_sql, presence: true, if: :sql_required?

  def rows
    result_rows || []
  end

  def in_progress?
    generating? || running?
  end

  def state_dom_id
    "report_run_#{id}_state"
  end

  private

  def sql_required?
    planned? || running? || succeeded?
  end

  def normalize_generated_sql
    self.generated_sql = Diviner::SqlPayload.extract(generated_sql).presence if generated_sql.present?
  end

  def ensure_generated_sql_not_null
    self.generated_sql = '' if generated_sql.nil?
  end

  def broadcast_state
    broadcast_replace_to(
      self,
      target: state_dom_id,
      partial: 'report_runs/state_frame',
      locals: { report_run: self }
    )
  end
end
