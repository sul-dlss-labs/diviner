# Diviner Key Files

- Report flow controller: `app/controllers/report_runs_controller.rb`
- Report state model + Turbo broadcast: `app/models/report_run.rb`
- Background jobs:
  - `app/jobs/generate_report_sql_job.rb`
  - `app/jobs/run_report_job.rb`
- SQL payload normalization: `app/services/diviner/sql_payload.rb`
- Planner and execution services:
  - `app/services/diviner/report_sql_planner.rb`
  - `app/services/diviner/safe_sql_runner.rb`
- LLM tooling and domain guidance:
  - `app/tools/model_tool.rb`
  - `app/services/diviner/dor_services_facts.rb`
  - `app/services/diviner/query_examples.rb`
- Report UI and helpers:
  - `app/views/report_runs/show.html.erb`
  - `app/views/report_runs/_state.html.erb`
  - `app/helpers/report_runs_helper.rb`
