-- Revert: schemas/collections_public/tables/full_text_search/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.full_text_search FROM authenticated;
COMMIT;  

