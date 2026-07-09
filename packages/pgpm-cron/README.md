# @pgpm/cron

Open-code pg_cron sync for the `metaschema_public.scheduled_cron` registry.

## Overview

`metaschema_public.scheduled_cron` is the declarative source of truth for which
recurring jobs should exist for a database (populated automatically by metaschema
triggers — e.g. registering `maintenance:partman` when a partitioned table is
parented). This module contains the **open-code** mechanism that reconciles that
registry into [pg_cron](https://github.com/citusdata/pg_cron), so it is safe to
ship to exported/consumer databases without any platform-proprietary code.

It targets the **local, single-database** deployment shape, where `pg_cron` is
installed in the same database that holds the `scheduled_cron` rows. The platform
cross-database case (one `pg_cron` in `postgres` fanning out to many app/tenant
databases via `cron.schedule_in_database()`) is handled separately by the
platform deploy flow, not by this module.

## pg_cron placement (important)

`pg_cron` is installed **once per cluster** — in a single database (the "cron
database", `postgres` by default), which is the only place `CREATE EXTENSION
pg_cron` and the `cron.job` table exist. It also requires
`shared_preload_libraries = 'pg_cron'` + a restart. So `pg_cron` is **not**
present in the platform database or in tenant/app databases, and it cannot be a
hard `requires` in this module's control file.

- **Local single-DB dev:** app, registry, and `pg_cron` are all one database, so
  `sync_scheduled_cron()` uses `cron.schedule()` directly (this module).
- **Platform:** the registry lives in the platform DB but scheduling must run
  from the cron DB via `cron.schedule_in_database(..., target => platform_db)`.
  That cross-database fan-out is handled by the platform deploy flow, not here.

## What it does

`pgpm_cron.sync_scheduled_cron()`:

- Silently no-ops when `pg_cron` is not installed — the table remains the source
  of truth for an external scheduler.
- Schedules every `is_enabled` row via `cron.schedule(name, schedule, command)`.
- Unschedules rows that are present but disabled.

`database_id` on `scheduled_cron` is operational metadata (which database a job
targets / cascade cleanup) and is intentionally ignored here: in the local
single-database shape every row belongs to the one database that runs the sync.

## Notes

- Removal of a job when its `scheduled_cron` row is deleted is expected to be
  driven by a delete-side sync in the platform metadatabase; this reconcile
  function only handles enabled/disabled state for rows that still exist.
