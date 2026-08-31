-- Verify schemas/jwt_private/procedures/current_entity_id on pg

BEGIN;

SELECT 1 / CASE WHEN EXISTS (
  SELECT 1
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'jwt_private'
    AND p.proname = 'current_entity_id'
    AND p.proargtypes = ''
) THEN 1 ELSE 0 END;

ROLLBACK;
