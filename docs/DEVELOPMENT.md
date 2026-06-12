# Diviner Developer Workflow

## Run app stack

- `bin/dev` (or run entries in `Procfile.dev`)
- `bin/dev` includes a `jobs` process running `bin/jobs` for Solid Queue.

## ActionCable / Turbo Streams

- App uses ActionCable for Turbo stream updates on report state pages.
- `config/cable.yml` is configured to use `solid_cable` in development and
  production.

## Background jobs and cache

- Active Job backend is `solid_queue` in development and production.
- Cache store is `solid_cache_store` in development and production.
- Ensure DB migrations are up-to-date so Solid tables exist:
  - `bundle exec rails db:prepare`
  - creates/updates `solid_queue_*`, `solid_cache_entries`, and
    `solid_cable_messages` tables.

## Run tests

- `bundle exec rails db:prepare`
- `bundle exec rspec`

## Run lint

- `bundle exec rubocop`

Lint policy in this repo currently relies on generated todo config:

- `.rubocop.yml` inherits from `.rubocop_todo.yml`.
- Prefer regenerating todo over broad stylistic refactors unless there is a
  functional reason to refactor.

