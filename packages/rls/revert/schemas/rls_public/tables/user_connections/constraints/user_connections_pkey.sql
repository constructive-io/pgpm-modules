-- Revert: schemas/rls_public/tables/user_connections/constraints/user_connections_pkey from pg

BEGIN;


ALTER TABLE "rls_public".user_connections 
    DROP CONSTRAINT user_connections_pkey;

COMMIT;  

