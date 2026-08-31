-- Deploy schemas/app_scope/procedures/actor_entity to pg
-- requires: schemas/app_scope/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/users_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/principal_auth_module/table

BEGIN;

-- actor_entity: the entity pair an actor carries when the actor IS the entity.
--
-- A request that names no entity anywhere (no route, parameter or header
-- entity) and is not actorless is done on behalf of the actor itself. A
-- principal is not an entity of its own: work authenticated by a credential is
-- done on behalf of the human who owns it, so a principal actor resolves to its
-- owner's pair.
--
-- users.type is an FK into the users module's own role-types table, which
-- metaschema_generators.users_module seeds with the same three rows in every
-- database (1 User, 2 Organization, 3 Principal) and exposes no grant, policy
-- or insert action for — so the type is a closed set and the scope it maps to
-- is our constant, not tenant data. Reading it back out of a per-database table
-- would only be indirection. The seed is pinned by a test that fails if it ever
-- stops matching this mapping.
--
-- Raises rather than returning NULL: the caller is stamping the claims a
-- transaction will be attributed by, and half a pair is what strict attribution
-- exists to refuse. A NULL here would surface much later as an unattributable
-- job, with no trace of which request minted it.
--
-- Dynamic SELECT against dynamically-named tables (identifiers are data, values
-- are bound parameters) because metaschema-generated tables live under each
-- database's schema hash — the same portable idiom as app_scope.dyn_lookup_uuid
-- and app_scope.membership_parent's probe, with no AST/deparser dependency.
CREATE FUNCTION app_scope.actor_entity(
    database_id uuid,
    actor_id uuid
) RETURNS TABLE (
    entity_id uuid,
    entity_type text
) AS $$
DECLARE
    users_schema text;
    users_table text;
    principals_schema text;
    principals_table text;

    -- the actor's own row, and the owner row a principal actor resolves to
    actor_type integer;
    owner_id uuid;
    owner_type integer;

    resolved_id uuid;
    resolved_type integer;
    resolved_scope text;
BEGIN
    IF actor_entity.actor_id IS NULL THEN
        RAISE EXCEPTION 'ACTOR_REQUIRED: actor_entity needs an actor to type'
            USING ERRCODE = '22004';
    END IF;

    -- The principals table is LEFT JOINed: a database may install users without
    -- principal_auth (the minimal preset does), and that only matters if the
    -- actor turns out to be a principal.
    SELECT users_schema_row.schema_name, users_table_row.name,
           principals_schema_row.schema_name, principals_table_row.name
    INTO users_schema, users_table, principals_schema, principals_table
    FROM metaschema_modules_public.users_module um
    JOIN metaschema_public."table" users_table_row
        ON (users_table_row.id = um.table_id)
    JOIN metaschema_public.schema users_schema_row
        ON (users_schema_row.id = users_table_row.schema_id
            AND users_schema_row.database_id = users_table_row.database_id)
    LEFT JOIN metaschema_modules_public.principal_auth_module pam
        ON (pam.database_id = um.database_id)
    LEFT JOIN metaschema_public."table" principals_table_row
        ON (principals_table_row.id = pam.principals_table_id)
    LEFT JOIN metaschema_public.schema principals_schema_row
        ON (principals_schema_row.id = principals_table_row.schema_id
            AND principals_schema_row.database_id = principals_table_row.database_id)
    WHERE um.database_id = actor_entity.database_id;

    IF users_schema IS NULL THEN
        RAISE EXCEPTION 'ACTOR_ENTITY_UNRESOLVED: database % installs no users module, so an actor has no entity to carry', actor_entity.database_id
            USING ERRCODE = '42704';
    END IF;

    IF principals_schema IS NULL THEN
        -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the generated users table is dynamically named, while actor_id stays a bound parameter
        EXECUTE format(
            'SELECT u.type FROM %I.%I u WHERE u.id = $1',
            users_schema, users_table
        ) INTO actor_type USING actor_entity.actor_id;
    ELSE
        -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the generated users and principals tables are dynamically named, while actor_id stays a bound parameter
        EXECUTE format(
            'SELECT u.type, owner.id, owner.type'
            '  FROM %I.%I u'
            '  LEFT JOIN %I.%I p ON p.user_id = u.id'
            '  LEFT JOIN %I.%I owner ON owner.id = p.owner_id'
            ' WHERE u.id = $1',
            users_schema, users_table,
            principals_schema, principals_table,
            users_schema, users_table
        ) INTO actor_type, owner_id, owner_type USING actor_entity.actor_id;
    END IF;

    IF actor_type IS NULL THEN
        RAISE EXCEPTION 'ACTOR_ENTITY_UNRESOLVED: actor % has no users row in database %', actor_entity.actor_id, actor_entity.database_id
            USING ERRCODE = '42704';
    END IF;

    IF actor_type = 3 THEN
        resolved_id := owner_id;
        resolved_type := owner_type;
    ELSE
        resolved_id := actor_entity.actor_id;
        resolved_type := actor_type;
    END IF;

    resolved_scope := CASE resolved_type
        WHEN 1 THEN 'app'
        WHEN 2 THEN 'org'
    END;

    -- Unresolvable: an unknown users.type, a principal with no owner row, or a
    -- principal owned by another principal.
    IF resolved_id IS NULL OR resolved_scope IS NULL THEN
        RAISE EXCEPTION 'ACTOR_ENTITY_UNRESOLVED: actor % of users.type % resolves to no entity in database %', actor_entity.actor_id, actor_type, actor_entity.database_id
            USING ERRCODE = '42704';
    END IF;

    RETURN QUERY SELECT resolved_id, resolved_scope;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION app_scope.actor_entity(uuid, uuid) IS
'Resolves an actor to a complete entity pair from its users.type, or to the owner pair for a principal. Raises ACTOR_ENTITY_UNRESOLVED rather than returning a partial pair.';

COMMIT;
