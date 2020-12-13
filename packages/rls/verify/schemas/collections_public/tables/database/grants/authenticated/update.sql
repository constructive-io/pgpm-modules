-- Verify: schemas/collections_public/tables/database/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.database', 'update', 'authenticated');
COMMIT;  

