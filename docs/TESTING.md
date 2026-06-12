# Diviner Testing Guidance

When changing report flow, update these first:

- request specs: `spec/requests/report_runs_spec.rb`
- job specs:
  - `spec/jobs/generate_report_sql_job_spec.rb`
  - `spec/jobs/run_report_job_spec.rb`
- helper specs: `spec/helpers/report_runs_helper_spec.rb`
- planner/runner unit specs under `spec/services/diviner/`

Coverage is enabled via SimpleCov in `spec/spec_helper.rb`.
Keep coverage healthy and avoid introducing untested state transitions.
