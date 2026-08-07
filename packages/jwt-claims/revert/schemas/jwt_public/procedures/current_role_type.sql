-- Revert schemas/jwt_public/procedures/current_role_type from pg

BEGIN;

DROP FUNCTION jwt_public.current_role_type();

COMMIT;
