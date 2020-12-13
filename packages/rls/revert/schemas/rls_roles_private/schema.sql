-- Revert: schemas/rls_roles_private/schema from pg

BEGIN;


DROP SCHEMA IF EXISTS "rls_roles_private" CASCADE;
COMMIT;  

