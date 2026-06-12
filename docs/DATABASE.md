# Diviner Database and Environment Notes

Two database connections are configured:

- `primary`: Diviner app DB.
- `dor_services_read_only`: read-only dor-services-app connection.

Solid backends use the app database in this project (single-database setup):

- SolidCable: `solid_cable_messages`
- SolidQueue: `solid_queue_*` tables
- SolidCache: `solid_cache_entries`

Local development defaults:

- App DB via `docker compose up db` on port `5432`.
- dor-services via SSH tunnel on port `5433` (see `Procfile.dev`).

Test env notes:

- Uses `active_job` test adapter.
- Includes a test `dor_services_read_only` entry with `database_tasks: false`.
- Active Storage test service is configured.
