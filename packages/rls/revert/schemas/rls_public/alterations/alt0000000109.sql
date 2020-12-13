-- Revert: schemas/rls_public/alterations/alt0000000109 from pg

BEGIN;
COMMENT ON CONSTRAINT user_characteristics_user_id_key ON "rls_public".user_characteristics IS NULL;
COMMIT;  

