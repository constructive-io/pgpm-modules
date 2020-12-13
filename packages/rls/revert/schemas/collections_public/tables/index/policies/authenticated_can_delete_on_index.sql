-- Revert: schemas/collections_public/tables/index/policies/authenticated_can_delete_on_index from pg

BEGIN;
DROP POLICY authenticated_can_delete_on_index ON collections_public.index;
COMMIT;  

