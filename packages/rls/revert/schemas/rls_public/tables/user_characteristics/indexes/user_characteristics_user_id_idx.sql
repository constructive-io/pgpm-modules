-- Revert: schemas/rls_public/tables/user_characteristics/indexes/user_characteristics_user_id_idx from pg

BEGIN;


DROP INDEX "rls_public".user_characteristics_user_id_idx;

COMMIT;  

