-- Deploy: schemas/meta_public/tables/phone_numbers/alterations/alt0000000058 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/phone_numbers/table

BEGIN;

ALTER TABLE "meta_public".phone_numbers
    DISABLE ROW LEVEL SECURITY;
COMMIT;
