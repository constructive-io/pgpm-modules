-- Revert schemas/db_utils/procedures/jsonb_deep_merge from pg

BEGIN;

DROP FUNCTION IF EXISTS db_utils.jsonb_deep_merge(jsonb, jsonb);

COMMIT;
