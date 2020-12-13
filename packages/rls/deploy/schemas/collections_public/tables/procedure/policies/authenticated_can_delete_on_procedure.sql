-- Deploy: schemas/collections_public/tables/procedure/policies/authenticated_can_delete_on_procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/procedure/table
-- requires: schemas/collections_public/tables/procedure/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_delete_on_procedure ON collections_public.procedure FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY( "rls_roles_public".get_current_group_ids() ) FROM collections_public.database AS p WHERE p.id = database_id) );
COMMIT;
