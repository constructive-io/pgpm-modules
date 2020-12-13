-- Verify: schemas/collections_public/tables/index/policies/authenticated_can_select_on_index on pg

BEGIN;
SELECT verify_policy('authenticated_can_select_on_index', 'collections_public.index');
COMMIT;  

