-- Revert: schemas/rls_roles_public/schema from pg

BEGIN;


DROP SCHEMA IF EXISTS "rls_roles_public" CASCADE;
COMMIT;  

