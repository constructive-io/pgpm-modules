-- Revert: schemas/rls_public/schema from pg

BEGIN;


DROP SCHEMA IF EXISTS "rls_public" CASCADE;
COMMIT;  

