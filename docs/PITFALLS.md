# Diviner - Known Pitfalls (Do Not Repeat)

1. Nested forms in report state partial can cause CSRF failures.
	- Do not place `button_to` inside `form_with` blocks.
	- Prefer `f.button` with `formaction`/`formmethod`.

2. RSpec double autocorrection can break tests.
	- For non-loaded constants, use string names in doubles where needed.

3. Heredoc hash syntax can silently corrupt payload shapes.
	- For hash values using heredoc, place comma on opener line correctly.

4. `generated_sql` is non-null at DB level.
	- Generating state uses empty string placeholder until SQL exists.

5. Async Turbo updates can look stale if callbacks are bypassed.
	- Avoid `update_columns` in paths that need UI state refresh.
	- This includes controller rescue/failure handling, not just job code.
