-- Revert schemas/jwt_public/procedures/current_principal_id from pg

BEGIN;

DROP FUNCTION jwt_public.current_principal_id();

COMMIT;
