-- Revert: schemas/rls_public/tables/addresses/indexes/addresses_owner_id_idx from pg

BEGIN;


DROP INDEX "rls_public".addresses_owner_id_idx;

COMMIT;  

