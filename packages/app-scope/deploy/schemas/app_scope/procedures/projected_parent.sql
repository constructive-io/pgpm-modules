-- Deploy schemas/app_scope/procedures/projected_parent to pg
-- requires: schemas/app_scope/schema

BEGIN;

-- projected_parent: one scope's membership type and the scope it climbs to, read
-- from the scope type projection with plain static SQL.
--
-- This is the fast half of app_scope.membership_parent. The projection
-- (scope_private.scope_types, one row per scope of every logical database in this
-- Postgres database, keyed by database_id) holds exactly the type-level structure
-- the climb needs — `team` sits under `department` — so the two hops that
-- membership_parent resolves by probing a per-database, hash-named
-- membership_types table with EXECUTE become a single self-join here.
--
-- Returns no row when the projection cannot answer, which is not an error and has
-- three ordinary causes: the plane is not installed in this database at all; the
-- schema exists under a database's hash rather than the published name (a
-- live-provisioned platform database, where names are only stabilised by export —
-- see docs/architecture/platform-publication-pipeline.md); or the scope is simply
-- not a membership scope. The caller falls back to the dynamic probe, so a
-- no-answer costs a to_regclass and nothing else.
--
-- The literal name is the point: naming the published schema is what makes the
-- climb plannable, and it is checked at runtime rather than required at deploy
-- time so that the bootstrap and test-harness databases — which provision through
-- live triggers instead of deploying the published module, and which are what
-- build the published module in the first place — keep working unchanged.
CREATE FUNCTION app_scope.projected_parent(
    database_id uuid,
    scope text
) RETURNS TABLE (
    membership_type int,
    parent_scope text
) AS $$
BEGIN
    IF to_regclass('scope_private.scope_types') IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT st.membership_type,
           parent.scope
    FROM scope_private.scope_types st
    LEFT JOIN scope_private.scope_types parent
           ON parent.database_id = st.database_id
          AND parent.membership_type = st.parent_membership_type
    WHERE st.database_id = projected_parent.database_id
      AND st.scope = projected_parent.scope;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION app_scope.projected_parent(uuid, text) IS
'One scope''s membership type and parent scope, read from scope_private.scope_types with static SQL. Returns no row when the projection is absent or does not cover the scope, so callers fall back to the dynamic probe.';

COMMIT;
