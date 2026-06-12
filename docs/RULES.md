# Diviner Rules (Non-Negotiable)

1. Never allow user-edited SQL persistence from forms.
	- `report_run_params` should not permit `generated_sql`.

2. Never persist or display raw wrapper payloads.
	- Always normalize through `Diviner::SqlPayload.extract` before storing,
	  rewriting, running, or rendering SQL.

3. Do not move generation/execution back into web requests.
	- Use jobs for any long-running planner/runner operations.

4. Keep spinner state truthful.
	- Any status/error write on `ReportRun` (jobs and controller rescue paths)
	  must use callback-safe updates so Turbo broadcasts fire.
	- Do not use `update_columns` for state transitions.

5. Preserve readonly guarantees.
	- Do not relax `SafeSqlRunner` guards without explicit approval.
