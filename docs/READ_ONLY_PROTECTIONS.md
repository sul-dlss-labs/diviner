# Diviner Dor-Services Read-only Protections

This document summarizes the current write protections for Diviner's
`dor_services_read_only` connection and outlines planned hardening work.

## Current protections (as built today)

Diviner currently uses multiple layers to reduce write risk:

1. Separate dor-services connection
   - `DorServicesRecord` establishes a dedicated connection to
     `dor_services_read_only` in `config/database.yml`.
   - The connection entry is marked `replica: true`.

2. ActiveRecord write prevention wrapper
   - `DorServicesRecord.with_readonly_connection` wraps dor-services DB access
     in `while_preventing_writes`.
   - dor-services query paths use this wrapper:
     - `Diviner::SafeSqlRunner`
     - `Diviner::DorServicesSchema`
     - `Diviner::CocinaRowEnricher`

3. SQL guardrails in runner
   - `Diviner::SafeSqlRunner` strips wrappers/comments, validates statements,
     blocks forbidden write/DDL keywords, and limits supported statement
     prefixes.
   - Runner sets:
     - `SET LOCAL statement_timeout = '10s'`
     - `SET LOCAL transaction_read_only = on`
   - Final row-returning query gets a default `LIMIT 500` when absent.

4. Coding rule protection
   - `docs/RULES.md` designates readonly guarantees as non-negotiable.

## Known limitation

These protections are strong defense-in-depth, but they are not a full
substitute for database-level privilege enforcement.

True guarantee requires that the configured dor-services DB role itself has
no write privileges.

## Planned hardening (deferred until VM setup)

When environment setup allows, implement DB-role verification and fail-fast
checks:

1. Provision and use a least-privilege dor-services role
   - Grant only required read privileges (`SELECT`, plus any necessary schema
     usage).
   - Revoke write and DDL-related privileges.

2. Add startup/runtime verification
   - Add a verifier that inspects role capabilities via safe catalog queries
     (e.g., role attributes and grant tables).
   - Fail boot (or surface high-visibility error) if write privileges are
     detected.

3. Add CI/spec coverage for the verifier
   - Validate expected behavior for compliant and non-compliant privilege
     states.

## Safe privilege checking approach

Use metadata/catalog introspection queries only (no write probes) against the
configured dor-services account to verify access level. This avoids any data
mutation risk while still confirming effective privileges.
