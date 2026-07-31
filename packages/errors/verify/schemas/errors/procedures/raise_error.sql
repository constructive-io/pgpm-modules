-- Verify schemas/errors/procedures/raise_error on pg

BEGIN;

DO $$
BEGIN
  ASSERT (
    SELECT EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'errors'
        AND p.proname = 'raise_error'
    )
  ), 'function errors.raise_error does not exist';
END $$;

ROLLBACK;
