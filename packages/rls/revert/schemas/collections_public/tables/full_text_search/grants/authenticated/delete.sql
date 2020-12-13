-- Revert: schemas/collections_public/tables/full_text_search/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.full_text_search FROM authenticated;
COMMIT;  

