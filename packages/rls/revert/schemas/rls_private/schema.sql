-- Revert: schemas/rls_private/schema from pg

BEGIN;


DROP SCHEMA IF EXISTS "rls_private" CASCADE;
COMMIT;  

