-- Revert schemas/infra_utils/schema from pg

BEGIN;

DROP SCHEMA infra_utils;

COMMIT;
