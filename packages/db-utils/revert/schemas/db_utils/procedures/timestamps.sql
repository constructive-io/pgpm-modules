-- Revert schemas/db_utils/procedures/timestamps from pg

BEGIN;

DROP FUNCTION IF EXISTS db_utils.timestamps(text, text);

COMMIT;
