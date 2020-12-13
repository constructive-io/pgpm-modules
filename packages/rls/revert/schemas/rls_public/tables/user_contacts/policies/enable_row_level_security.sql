-- Revert: schemas/rls_public/tables/user_contacts/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE "rls_public".user_contacts
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

