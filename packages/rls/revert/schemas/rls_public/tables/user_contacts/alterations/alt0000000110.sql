-- Revert: schemas/rls_public/tables/user_contacts/alterations/alt0000000110 from pg

BEGIN;


ALTER TABLE "rls_public".user_contacts
    ENABLE ROW LEVEL SECURITY;

COMMIT;  

