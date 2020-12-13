-- Deploy: schemas/collections_public/tables/procedure/grants/authenticated/select to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/procedure/table

BEGIN;
GRANT SELECT ON TABLE collections_public.procedure TO authenticated;
COMMIT;
