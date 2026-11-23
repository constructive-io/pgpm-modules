-- Verify roles/anon from pg

BEGIN;

DO $$
BEGIN
  ASSERT pg_has_role('anon', 'anonymous', 'MEMBER');
  ASSERT NOT pg_has_role('anon', 'anonymous', 'USAGE');
END;
$$;

ROLLBACK;
