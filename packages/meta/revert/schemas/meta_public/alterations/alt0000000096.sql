-- Revert: schemas/meta_public/alterations/alt0000000096 from pg

BEGIN;
COMMENT ON CONSTRAINT apis_domain_id_fkey ON "meta_public".apis IS NULL;
COMMIT;  

