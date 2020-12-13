-- Revert: schemas/rls_public/tables/invites/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE "rls_public".invites
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

