-- Deploy: schemas/rls_public/tables/invites/columns/sender_id/alterations/alt0000000049 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table
-- requires: schemas/rls_public/tables/invites/columns/sender_id/column

BEGIN;

ALTER TABLE "rls_public".invites 
    ALTER COLUMN sender_id SET DEFAULT "rls_roles_public".get_current_user_id();
COMMIT;
