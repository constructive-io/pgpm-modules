-- Deploy schemas/function_resolution/procedures/storage_default_origins to pg

-- requires: schemas/function_resolution/schema
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/storage_module/table

BEGIN;

-- storage_default_origins: the browser origins a bucket is provisioned with
-- when neither the bucket row nor its storage_module names any. The reconciler
-- (storage:provision_bucket) asks for it as the last tier, so a freshly
-- provisioned database's first presigned upload is not refused by the object
-- store's CORS check before the owner has ever edited allowed_origins.
--
-- Two sources, both catalog state the platform already holds, never the
-- request's own Origin header and never '*':
--   - the platform plane's default storage_module.allowed_origins: the
--     deployment's first-party browser hosts (the dashboard), recorded by the
--     operator next to the object-store endpoint;
--   - the database's own verified, non-wildcard hostnames (routing_public.domains;
--     the platform database's own live in routing_public.platform_domains),
--     as origins the same way the generated <sites>_site_origin spells them:
--     https once TLS is active/ready, otherwise http, plus the managed
--     domain's public port when it has one.
--
-- Resolved at provision time from the catalog, not copied onto the rows, so a
-- hostname that is added or gains TLS later is picked up by the next
-- storage:resync_module_cors / storage:provision_bucket run with nothing to
-- backfill. domains sits behind member RLS and the platform storage_module
-- behind owner RLS, so this is the narrow hop past both: granted to no
-- request role, called only by the platform login (fun platform
-- COMPONENT_GRANTS) with no role switch.

CREATE FUNCTION function_resolution.storage_default_origins(database_id uuid)
RETURNS SETOF text AS $$
DECLARE
    platform_id uuid := app_scope.platform_database_id();
BEGIN
    RETURN QUERY
    SELECT DISTINCT o.origin
    FROM (
        SELECT CASE WHEN h.tls_status IN ('active', 'ready') THEN 'https://' ELSE 'http://' END
               || h.hostname
               || COALESCE(':' || h.public_port::text, '') AS origin
        FROM (
            SELECT d.hostname::text AS hostname,
                   d.tls_status::text AS tls_status,
                   (SELECT md.public_port
                      FROM routing_public.managed_domains AS md
                     WHERE md.domain = substr(d.hostname::text, strpos(d.hostname::text, '.') + 1)
                       AND md.public_port IS NOT NULL
                     LIMIT 1) AS public_port
            FROM routing_public.domains AS d
            WHERE d.database_id = storage_default_origins.database_id
              AND storage_default_origins.database_id <> platform_id
              AND d.hostname IS NOT NULL
              AND d.is_wildcard IS NOT TRUE
              AND d.verification_status = 'verified'
            UNION ALL
            SELECT pd.hostname::text,
                   pd.tls_status::text,
                   (SELECT pmd.public_port
                      FROM routing_public.platform_managed_domains AS pmd
                     WHERE pmd.domain = substr(pd.hostname::text, strpos(pd.hostname::text, '.') + 1)
                       AND pmd.public_port IS NOT NULL
                     LIMIT 1)
            FROM routing_public.platform_domains AS pd
            WHERE storage_default_origins.database_id = platform_id
              AND pd.hostname IS NOT NULL
              AND pd.is_wildcard IS NOT TRUE
              AND pd.verification_status = 'verified'
        ) AS h
        UNION ALL
        SELECT unnest(sm.allowed_origins)
        FROM metaschema_modules_public.storage_module AS sm
        WHERE sm.database_id = platform_id
          AND sm.scope = 'platform'
          AND sm.key = 'default'
    ) AS o
    WHERE o.origin IS NOT NULL
      AND o.origin <> '*'
    ORDER BY 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.storage_default_origins(uuid) FROM PUBLIC;

COMMIT;
