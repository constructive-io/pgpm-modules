-- Revert: schemas/collections_public/tables/full_text_search/policies/authenticated_can_insert_on_full_text_search from pg

BEGIN;
DROP POLICY authenticated_can_insert_on_full_text_search ON collections_public.full_text_search;
COMMIT;  

