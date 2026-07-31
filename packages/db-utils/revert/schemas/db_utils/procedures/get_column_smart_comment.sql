-- Revert schemas/db_utils/procedures/get_column_smart_comment from pg

BEGIN;

DROP FUNCTION db_utils.get_column_smart_comment;

COMMIT;
