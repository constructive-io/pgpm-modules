-- Deploy: schemas/collections_public/tables/trigger/grants/authenticated/select to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/trigger/table

BEGIN;
GRANT SELECT ON TABLE collections_public.trigger TO authenticated;
COMMIT;
