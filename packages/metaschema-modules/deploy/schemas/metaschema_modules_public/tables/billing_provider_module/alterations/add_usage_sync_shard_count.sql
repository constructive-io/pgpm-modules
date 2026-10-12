-- Deploy schemas/metaschema_modules_public/tables/billing_provider_module/alterations/add_usage_sync_shard_count to pg

-- requires: schemas/metaschema_modules_public/tables/billing_provider_module/table

BEGIN;

-- Input: how many disjoint billing:sync_usage jobs each run of the task is
-- split into for this database. 1 runs the whole set in one job; N > 1
-- enqueues N shard jobs.
ALTER TABLE metaschema_modules_public.billing_provider_module
  ADD COLUMN IF NOT EXISTS usage_sync_shard_count int NOT NULL DEFAULT 1;

COMMIT;
