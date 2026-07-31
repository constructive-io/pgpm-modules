-- Revert schemas/db_utils/procedures/jsonb_set_deep from pg

BEGIN;

DROP FUNCTION IF EXISTS db_utils.jsonb_set_deep(jsonb, text[], jsonb);

COMMIT;
