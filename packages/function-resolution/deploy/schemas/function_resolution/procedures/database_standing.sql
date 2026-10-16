-- Deploy schemas/function_resolution/procedures/database_standing to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/database/table

BEGIN;

-- database_standing: whether a database may be served right now, for the
-- platform's own serving lanes (gateway, worker, pg-wire proxy) before any
-- request identity exists.
--
-- The lanes connect as NOBYPASSRLS logins, and the database table's RLS shows a
-- row only to members of the owning org, so a direct read finds nothing and
-- every database looks nonexistent. This hands back the two system-controlled
-- standing columns of the one database named, and nothing else; no row means
-- the database does not exist. Granted to no request role: only the platform
-- logins (granted at provision) call it.
CREATE FUNCTION function_resolution.database_standing(database_id uuid)
RETURNS TABLE (
    suspended_at timestamptz,
    suspended_reason text
) AS $$
    SELECT d.suspended_at, d.suspended_reason
    FROM metaschema_public.database AS d
    WHERE d.id = database_standing.database_id
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.database_standing(uuid) FROM PUBLIC;

COMMIT;
