-- Deploy schemas/supabase_integration/schema to pg

BEGIN;

CREATE SCHEMA supabase_integration;

GRANT USAGE ON SCHEMA supabase_integration TO anon, authenticated;

COMMIT;
