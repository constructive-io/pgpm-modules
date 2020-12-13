-- Revert: schemas/rls_public/tables/user_connections/columns/id/alterations/alt0000000119 from pg

BEGIN;


ALTER TABLE "rls_public".user_connections 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  

