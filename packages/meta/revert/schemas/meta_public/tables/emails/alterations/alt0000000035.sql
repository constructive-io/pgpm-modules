-- Revert: schemas/meta_public/tables/emails/alterations/alt0000000035 from pg

BEGIN;


ALTER TABLE "meta_public".emails
    ENABLE ROW LEVEL SECURITY;

COMMIT;  

