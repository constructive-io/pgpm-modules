-- Deploy: schemas/rls_public/tables/user_characteristics/columns/dob/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_characteristics/table

BEGIN;

ALTER TABLE "rls_public".user_characteristics ADD COLUMN dob date;
COMMIT;
