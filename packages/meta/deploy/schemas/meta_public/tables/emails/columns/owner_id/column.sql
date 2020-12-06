-- Deploy: schemas/meta_public/tables/emails/columns/owner_id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/emails/table

BEGIN;

ALTER TABLE "meta_public".emails ADD COLUMN owner_id uuid;
COMMIT;
