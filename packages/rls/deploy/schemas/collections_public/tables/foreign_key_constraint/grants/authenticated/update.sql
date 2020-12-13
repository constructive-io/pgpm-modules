-- Deploy: schemas/collections_public/tables/foreign_key_constraint/grants/authenticated/update to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/foreign_key_constraint/table

BEGIN;
GRANT UPDATE ON TABLE collections_public.foreign_key_constraint TO authenticated;
COMMIT;
