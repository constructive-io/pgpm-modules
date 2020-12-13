-- Deploy: schemas/collections_public/tables/primary_key_constraint/grants/authenticated/select to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/primary_key_constraint/table

BEGIN;
GRANT SELECT ON TABLE collections_public.primary_key_constraint TO authenticated;
COMMIT;
