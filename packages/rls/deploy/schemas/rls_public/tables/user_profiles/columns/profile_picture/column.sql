-- Deploy: schemas/rls_public/tables/user_profiles/columns/profile_picture/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_profiles/table

BEGIN;

ALTER TABLE "rls_public".user_profiles ADD COLUMN profile_picture image;
COMMIT;
