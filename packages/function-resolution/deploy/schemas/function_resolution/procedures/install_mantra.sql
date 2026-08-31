-- Deploy schemas/function_resolution/procedures/install_mantra to pg
-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/install_route_bindings

BEGIN;

-- install_mantra: install the platform's Mantra page set onto one site.
--
-- Mantra is not a new site backing and not a new routing mode: every page it
-- serves is an ordinary route row whose target is a function
-- (target_function_id -> the functions catalog), which the routing resolver
-- already answers on the function lane, emitting the definition's
-- task_identifier for the sync gateway.
--
-- So there is nothing Mantra-specific left in the install itself, and this is
-- now the narrowest possible wrapper over the general engine
-- (install_route_bindings): it holds the Mantra document contract — a JSON array
-- of {path, task_identifier}, which the generated verb reads from the platform's
-- own preset catalog (metaschema_generators.content_preset_definition of kind
-- 'route_bindings', slug 'mantra' by default) — and declares every entry a
-- function target. Everything else (the one scope read off the sites plane's own
-- registration, the routes plane, the ownership key, resolution, idempotency)
-- belongs to the engine, so the platform's page set and a deployment graph
-- binding its own paths cannot drift apart.
--
-- WHICH paths get installed stays data, and it is not this module's data: the
-- caller passes the document. That keeps this module portable (it depends on
-- app-scope and the module registry, not on the generator layer that owns the
-- catalog) and keeps the page set a versioned row a deployment can fork, never a
-- list inside a function.
--
-- The sites plane arrives BY REFERENCE, as a regclass rather than a pair of name
-- strings. This entry point is called from GENERATED SQL, and a generated body
-- that spelled its own schema in a bare string literal carried the physical
-- schema name of the database it was generated in: the platform export renames
-- schemas to their logical names through an AST rewrite, which routes a reg*
-- cast structurally and deliberately leaves a bare literal alone, so the baked
-- name survived into the published module and matched no registration. It is the
-- same reason every generated verify asserts through a reg* cast.
CREATE FUNCTION function_resolution.install_mantra(
    database_id uuid,
    sites_plane regclass,
    site_id uuid,
    bindings jsonb,
    entity_id uuid DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
    function_bindings jsonb;
    sites_schema text;
    sites_table text;
BEGIN
    IF install_mantra.sites_plane IS NULL THEN
        RAISE EXCEPTION 'MANTRA_SITES_PLANE_REQUIRED: sites_plane is required'
            USING ERRCODE = 'FR050';
    END IF;

    -- The plane's names, read off the catalog entry the reference itself proves
    -- exists, and handed to the engine as the registry records them.
    SELECT n.nspname, c.relname
    INTO sites_schema, sites_table
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE c.oid = install_mantra.sites_plane;

    -- The Mantra document contract, checked here because it is stricter than the
    -- engine's: every entry names a task, and none of them may name a target
    -- kind — a preset row that has grown a service binding is a broken preset,
    -- not a mixed install.
    IF install_mantra.bindings IS NULL
       OR jsonb_typeof(install_mantra.bindings) <> 'array'
       OR jsonb_array_length(install_mantra.bindings) = 0 THEN
        RAISE EXCEPTION 'MANTRA_BINDINGS_INVALID: bindings must be a non-empty JSON array of {path, task_identifier}, got %',
            coalesce(jsonb_typeof(install_mantra.bindings), 'null')
            USING ERRCODE = 'FR060';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_mantra.bindings) AS b
        WHERE jsonb_typeof(b) <> 'object'
           OR coalesce(b ->> 'path', '') = ''
           OR coalesce(b ->> 'task_identifier', '') = ''
           OR b ? 'target'
    ) THEN
        RAISE EXCEPTION 'MANTRA_BINDINGS_INVALID: every binding must carry a non-empty path and task_identifier, and no target kind'
            USING ERRCODE = 'FR060';
    END IF;

    SELECT jsonb_agg(b || jsonb_build_object('target', 'function'))
    INTO function_bindings
    FROM jsonb_array_elements(install_mantra.bindings) AS b;

    RETURN function_resolution.install_route_bindings(
        install_mantra.database_id,
        sites_schema,
        sites_table,
        install_mantra.site_id,
        function_bindings,
        install_mantra.entity_id
    );
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION function_resolution.install_mantra(uuid, regclass, uuid, jsonb, uuid) IS
'Install the Mantra page set (a JSON array of {path, task_identifier}, which the generated verb reads from the content_presets catalog at kind ''route_bindings'') onto one site as ordinary function-target routes. The sites plane arrives by reference as a regclass, so a generated caller never spells a schema name in a bare string literal the platform export''s AST rename cannot follow. A thin wrapper holding the Mantra document contract — every entry names a task, none names a target kind — over function_resolution.install_route_bindings, which owns the one-scope install: scope and ownership key read from the sites plane''s own registration, the routes plane from app_scope.routing_tables, resolution at that same (scope, entity), idempotent per (domain_id, path).';

COMMIT;
