-- Deploy: schemas/collections_public/tables/rls_function/policies/authenticated_can_insert_on_rls_function to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/rls_function/table
-- requires: schemas/collections_public/tables/rls_function/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_insert_on_rls_function ON collections_public.rls_function FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY( "rls_roles_public".get_current_group_ids() ) FROM collections_public.database AS p WHERE p.id = database_id) );
COMMIT;
