-- Deploy extensions/pg_partman to pg

DO $$
BEGIN
  EXECUTE 'CREATE SCHEMA IF NOT EXISTS partman';
  EXECUTE 'CREATE EXTENSION pg_partman SCHEMA partman';
END;
$$;

GRANT USAGE ON SCHEMA partman TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA partman TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA partman GRANT EXECUTE ON FUNCTIONS TO authenticated;
