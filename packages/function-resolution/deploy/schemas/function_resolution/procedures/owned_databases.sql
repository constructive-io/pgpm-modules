-- Deploy schemas/function_resolution/procedures/owned_databases to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/database/table

BEGIN;

-- owned_databases: the databases owned by any of the given entities, for an
-- artifact service resolving which tenant databases an authenticated account
-- may act for. The caller reads the account's memberships (the SPRT rows that
-- name the owning entities) and passes their entity ids here; the ownership
-- join itself is the one the database table's RLS policy makes.
--
-- It reads every tenant's catalog row, so it is granted to no request role:
-- only the platform login (granted at provision) calls it, on its own
-- connection with no role switch.
CREATE FUNCTION function_resolution.owned_databases(
    owner_ids uuid[]
)
RETURNS TABLE (
    database_id uuid,
    owner_id uuid
) AS $$
    SELECT d.id, d.owner_id
    FROM metaschema_public.database AS d
    WHERE d.owner_id = ANY (owner_ids)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.owned_databases(uuid[]) FROM PUBLIC;

COMMIT;
