-- Deploy: schemas/collections_public/tables/index/grants/authenticated/select to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/index/table

BEGIN;
GRANT SELECT ON TABLE collections_public.index TO authenticated;
COMMIT;
