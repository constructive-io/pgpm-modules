-- Deploy extensions/pg_partman to pg

DO $$
BEGIN
  EXECUTE 'CREATE SCHEMA IF NOT EXISTS partman';
  EXECUTE 'CREATE EXTENSION pg_partman SCHEMA partman';
END;
$$;
