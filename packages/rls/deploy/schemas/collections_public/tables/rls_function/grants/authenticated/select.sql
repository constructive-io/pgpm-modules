-- Deploy: schemas/collections_public/tables/rls_function/grants/authenticated/select to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/rls_function/table

BEGIN;
GRANT SELECT ON TABLE collections_public.rls_function TO authenticated;
COMMIT;
