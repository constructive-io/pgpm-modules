-- Revert: schemas/rls_simple_secrets/schema from pg

BEGIN;


DROP SCHEMA IF EXISTS "rls_simple_secrets" CASCADE;
COMMIT;  

