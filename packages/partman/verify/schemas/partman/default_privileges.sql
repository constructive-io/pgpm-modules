-- Verify schemas/partman/default_privileges on pg

BEGIN;

SELECT 1 / count(*)::int AS ok
FROM pg_default_acl d
JOIN pg_namespace n ON n.oid = d.defaclnamespace
WHERE n.nspname = 'partman';

ROLLBACK;
