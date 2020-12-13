-- Verify: schemas/collections_public/tables/foreign_key_constraint/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.foreign_key_constraint', 'update', 'authenticated');
COMMIT;  

