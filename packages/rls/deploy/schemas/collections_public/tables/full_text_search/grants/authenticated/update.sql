-- Deploy: schemas/collections_public/tables/full_text_search/grants/authenticated/update to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/full_text_search/table

BEGIN;
GRANT UPDATE ON TABLE collections_public.full_text_search TO authenticated;
COMMIT;
