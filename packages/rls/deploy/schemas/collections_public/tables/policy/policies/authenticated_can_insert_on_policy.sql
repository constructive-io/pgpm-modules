-- Deploy: schemas/collections_public/tables/policy/policies/authenticated_can_insert_on_policy to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/policy/table
-- requires: schemas/collections_public/tables/policy/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_insert_on_policy ON collections_public.policy FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY( "rls_roles_public".get_current_group_ids() ) FROM collections_public.database AS p WHERE p.id = database_id) );
COMMIT;
