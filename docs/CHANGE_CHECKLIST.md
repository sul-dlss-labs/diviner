# Diviner Change Checklist

Before finishing any non-trivial change:

1. Ensure SQL is still system-generated and sanitized.
2. Ensure async job flow is intact for generate/run.
3. Ensure spinner status transitions clear correctly.
4. Confirm `ReportRun` state transitions do not use `update_columns`.
5. Run:
	- `bundle exec rspec`
	- `bundle exec rubocop`
6. Confirm no UI regressions in report show page interactions.

## Decision Log

1. SQL editing policy
	- Decision: user input must never directly persist or edit SQL.
	- Consequence: forms only accept natural-language request fields; SQL is a
	  generated side product.

2. Callback-safe failure updates
	- Decision: state/error transitions on `ReportRun` must use callback-safe
	  writes in both jobs and controller rescue paths.
	- Consequence: avoid `update_columns` for status changes so Turbo broadcasts
	  remain reliable.
