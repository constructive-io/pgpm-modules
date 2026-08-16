-- Deploy schemas/function_resolution/procedures/image_catalog_row to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/frame_candidates

BEGIN;

-- image_catalog_row: load one container image the execution is allowed to run.
--
-- An image foreign key never leaves its own scope, so a tenant that runs a
-- platform-published image holds no reference to it: the reference is a name,
-- and this is where a name becomes coordinates. The frame candidates join
-- catalog_private.images nearest frame first, so a scope's own image shadows a
-- published one of the same name — the read-down is a fallback, not an override.
--
-- The shared plane holds every database's rows, so each candidate carries the
-- row's expected database_id (its own key at database scope, the frame's lookup
-- database otherwise); without it a name could resolve against a row belonging
-- to another tenant. A row owned by another database additionally needs
-- is_visible (the source row's is_published), and platform_only rows are never
-- reachable from outside the database that owns them.
--
-- Returns no row when the image is not reachable, leaving the fail-loud wording
-- to the caller, which knows what named it.
--
-- plpgsql, not sql: this module is portable and deploys into databases that host
-- no catalog module, so catalog_private must be resolved on first call rather
-- than at CREATE FUNCTION time.
CREATE FUNCTION function_resolution.image_catalog_row(
    database_id uuid,
    scope text,
    entity_id uuid,
    image_name text
) RETURNS TABLE (
    image_id uuid,
    name text,
    registry_host text,
    repository text,
    tag text,
    digest text,
    runtime text,
    labels jsonb,
    owner_database_id uuid,
    owner_scope text,
    owner_key uuid
) AS $$
BEGIN
    RETURN QUERY
    SELECT i.id,
           i.name,
           i.registry_host,
           i.repository,
           i.tag,
           i.digest,
           i.runtime,
           i.labels,
           i.database_id,
           i.owner_scope,
           i.owner_key
    FROM function_resolution.frame_candidates(
        image_catalog_row.database_id,
        image_catalog_row.scope,
        image_catalog_row.entity_id
    ) cand
    JOIN catalog_private.images i
      ON i.owner_scope = cand.owner_scope
     AND i.owner_key IS NOT DISTINCT FROM cand.owner_key
     AND i.database_id = CASE
           WHEN cand.owner_scope = 'database' THEN cand.owner_key
           ELSE cand.lookup_database_id
         END
    WHERE i.name = image_catalog_row.image_name
      AND (
            i.database_id = image_catalog_row.database_id
            OR (i.is_visible AND NOT i.platform_only)
          )
    ORDER BY cand.ord
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
