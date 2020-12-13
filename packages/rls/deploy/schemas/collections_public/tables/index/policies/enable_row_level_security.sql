-- Deploy: schemas/collections_public/tables/index/policies/enable_row_level_security to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/index/table

BEGIN;

ALTER TABLE collections_public.index
    ENABLE ROW LEVEL SECURITY;
COMMIT;
