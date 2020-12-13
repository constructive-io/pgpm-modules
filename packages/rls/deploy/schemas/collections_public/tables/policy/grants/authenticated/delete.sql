-- Deploy: schemas/collections_public/tables/policy/grants/authenticated/delete to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/policy/table

BEGIN;
GRANT DELETE ON TABLE collections_public.policy TO authenticated;
COMMIT;
