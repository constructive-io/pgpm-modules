-- Deploy: schemas/collections_public/tables/database/grants/authenticated/select to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/database/table

BEGIN;
GRANT SELECT ON TABLE collections_public.database TO authenticated;
COMMIT;
