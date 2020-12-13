-- Deploy: schemas/collections_public/tables/field/policies/authenticated_can_insert_on_field to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/field/table
-- requires: schemas/collections_public/tables/field/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_insert_on_field ON collections_public.field FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY( "rls_roles_public".get_current_group_ids() ) FROM collections_public.database AS p WHERE p.id = database_id) );
COMMIT;
