-- Revert schemas/jwt_public/procedures/require_user_id from pg

BEGIN;

DROP FUNCTION jwt_public.require_user_id();

COMMIT;
