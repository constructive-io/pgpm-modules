-- Verify schemas/errors/schema on pg

BEGIN;

DO $$
BEGIN
  ASSERT (
    SELECT EXISTS (
      SELECT 1 FROM pg_namespace WHERE nspname = 'errors'
    )
  ), 'schema errors does not exist';
END $$;

ROLLBACK;
