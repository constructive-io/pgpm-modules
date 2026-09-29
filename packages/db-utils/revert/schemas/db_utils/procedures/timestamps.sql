-- Revert schemas/db_utils/procedures/timestamps from pg

BEGIN;

DROP FUNCTION db_utils.timestamps(text, text);

COMMIT;
