-- Revert: schemas/rls_public/tables/user_connections/table from pg

BEGIN;
DROP TABLE "rls_public".user_connections;
COMMIT;  

