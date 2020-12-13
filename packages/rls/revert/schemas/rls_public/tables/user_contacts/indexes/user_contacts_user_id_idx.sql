-- Revert: schemas/rls_public/tables/user_contacts/indexes/user_contacts_user_id_idx from pg

BEGIN;


DROP INDEX "rls_public".user_contacts_user_id_idx;

COMMIT;  

