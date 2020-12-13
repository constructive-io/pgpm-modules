-- Revert: schemas/rls_public/tables/emails/indexes/emails_owner_id_idx from pg

BEGIN;


DROP INDEX "rls_public".emails_owner_id_idx;

COMMIT;  

