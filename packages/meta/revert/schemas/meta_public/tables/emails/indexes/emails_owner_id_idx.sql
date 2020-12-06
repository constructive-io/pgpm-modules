-- Revert: schemas/meta_public/tables/emails/indexes/emails_owner_id_idx from pg

BEGIN;


DROP INDEX "meta_public".emails_owner_id_idx;

COMMIT;  

