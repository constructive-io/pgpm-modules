-- Deploy procedures/table to pg

-- requires: procedures/rls

-- hack to add to table since introspection COULD NOT DO IT

BEGIN;

ALTER TABLE collections_public."table" ENABLE ROW LEVEL SECURITY;
CREATE POLICY authenticated_can_select_on_table ON collections_public."table" FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );
CREATE POLICY authenticated_can_insert_on_table ON collections_public."table" FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );
CREATE POLICY authenticated_can_update_on_table ON collections_public."table" FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );
CREATE POLICY authenticated_can_delete_on_table ON collections_public."table" FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );
GRANT SELECT ON TABLE collections_public."table" TO authenticated;
GRANT INSERT ON TABLE collections_public."table" TO authenticated;
GRANT UPDATE ON TABLE collections_public."table" TO authenticated;
GRANT DELETE ON TABLE collections_public."table" TO authenticated;

COMMIT;
