# frozen_string_literal: true

class AddTimingFieldsToReportRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :report_runs, :sql_generation_duration_ms, :integer
    add_column :report_runs, :execution_duration_ms, :integer
  end
end
