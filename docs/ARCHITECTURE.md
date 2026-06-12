# Diviner Architecture

## Request -> SQL -> Results pipeline

1. User submits report request in `ReportRunsController#create`.
2. A `ReportRun` is created with `status: generating`.
3. `GenerateReportSqlJob` generates SQL via `Diviner::ReportSqlPlanner`.
4. SQL is normalized through `Diviner::SqlPayload.extract`.
5. Optional chained execution is queued via `RunReportJob`.
6. `RunReportJob` executes SQL through `Diviner::SafeSqlRunner`.
7. `ReportRun` is updated to `succeeded` or `failed` using callback-safe
    updates (jobs and controller rescue paths).
8. `ReportRun` broadcasts Turbo replacement for the state frame.

## SQL planning stack

- `Diviner::ReportSqlPlanner` builds prompt context and asks `Diviner::ReportAgent`.
- `ModelTool` supplies schema snapshot, curated facts, JSON-path recipes,
  and canonical example queries.
- `Diviner::SqlQualityRewriter` applies deterministic SQL rewrites.
- `Diviner::SqlPayload` strips wrappers and extracts plain SQL.

## SQL execution safety

`Diviner::SafeSqlRunner` enforces read-only execution and guards:

- strips comments and wrapper artifacts,
- splits statements safely (handles quoted semicolons),
- blocks forbidden keywords (DDL/DML),
- allows only supported readonly prefixes,
- applies `LIMIT 500` to the final query when missing,
- runs in readonly transaction with statement timeout.

## Live update transport

- Report state updates are broadcast via Turbo Streams.
- Transport uses ActionCable with the SolidCable adapter.
- SolidCable persists transient cable messages in `solid_cable_messages`.

## Job execution and cache backends

- Report generation/execution jobs use Active Job with SolidQueue.
- SolidQueue runtime is started via `bin/jobs` (included in `Procfile.dev`).
- Application caching uses SolidCache via `:solid_cache_store`.
