-- Revert schemas/jwt_private/procedures/require_database_id from pg

BEGIN;

DROP FUNCTION jwt_private.require_database_id();

COMMIT;
