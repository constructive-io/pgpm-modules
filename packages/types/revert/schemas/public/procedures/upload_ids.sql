-- Revert schemas/public/procedures/upload_ids from pg

BEGIN;

DROP FUNCTION upload_ids(upload[]);

COMMIT;
