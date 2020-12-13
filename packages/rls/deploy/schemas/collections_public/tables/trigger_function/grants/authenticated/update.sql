-- Deploy: schemas/collections_public/tables/trigger_function/grants/authenticated/update to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/trigger_function/table

BEGIN;
GRANT UPDATE ON TABLE collections_public.trigger_function TO authenticated;
COMMIT;
