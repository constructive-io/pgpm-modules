-- Verify: schemas/collections_public/tables/database/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.database', 'insert', 'authenticated');
COMMIT;  

