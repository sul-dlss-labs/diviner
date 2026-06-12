# Diviner Status Model and UI Semantics

`ReportRun.status` values:

- `generating`: SQL generation in progress (show spinner)
- `planned`: SQL ready, not currently running
- `running`: execution in progress (show spinner)
- `succeeded`: results available
- `failed`: error available

Helper method:

- `ReportRun#in_progress?` is `true` for `generating` and `running`.

Turbo stream behavior:

- Show page subscribes to `turbo_stream_from @report_run`.
- State frame id comes from `ReportRun#state_dom_id`.
- Model broadcasts replacement on every commit.
