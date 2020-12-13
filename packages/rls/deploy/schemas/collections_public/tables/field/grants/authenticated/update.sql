-- Deploy: schemas/collections_public/tables/field/grants/authenticated/update to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/field/table

BEGIN;
GRANT UPDATE ON TABLE collections_public.field TO authenticated;
COMMIT;
