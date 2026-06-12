# frozen_string_literal: true

class CreateReportRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :report_runs do |t|
      t.string :status, null: false, default: 'planned'
      t.text :user_request, null: false
      t.text :generated_sql, null: false
      t.jsonb :result_rows, null: false, default: []
      t.integer :row_count, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :report_runs, :status
    add_index :report_runs, :created_at
  end
end
