-- Revert: schemas/meta_public/alterations/alt0000000097 from pg

BEGIN;
COMMENT ON CONSTRAINT apis_domain_id_key ON "meta_public".apis IS NULL;
COMMIT;  

