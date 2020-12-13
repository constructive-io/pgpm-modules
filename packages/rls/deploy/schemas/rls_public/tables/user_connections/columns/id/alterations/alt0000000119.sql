-- Deploy: schemas/rls_public/tables/user_connections/columns/id/alterations/alt0000000119 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_connections/table
-- requires: schemas/rls_public/tables/user_connections/columns/id/column

BEGIN;

ALTER TABLE "rls_public".user_connections 
    ALTER COLUMN id SET NOT NULL;
COMMIT;
