-- Deploy schemas/function_resolution/procedures/service_principal to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/principal_auth_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- service_principal: the platform database's principal of that name, for the
-- platform's own background writers (the refusal recorder) to take as their
-- flush identity before any request exists. The principals table is located
-- through the platform database's principal_auth_module registration; its
-- name comes from the catalog, never from the caller.
--
-- Principals sit behind owner/member RLS, so this is the narrow hop past it:
-- one row by name, granted to no request role. owner_id/owner_type are the
-- owning user and its membership type, which a service identity takes as its
-- attribution entity; the users table is hidden from the login too, and is
-- located through the same registration. Only the platform
-- login (granted at provision) calls it, on its own connection with no role
-- switch. A missing registration raises instead of reading nothing.
CREATE FUNCTION function_resolution.service_principal(principal_name text)
RETURNS TABLE (
    user_id uuid,
    bypass_step_up boolean,
    owner_id uuid,
    owner_type integer
) AS $$
DECLARE
    principals_schema text;
    principals_table text;
    users_schema text;
    users_table text;
BEGIN
    SELECT s.schema_name, pam.principals_table_name, us.schema_name, ut.name
    INTO principals_schema, principals_table, users_schema, users_table
    FROM metaschema_modules_public.principal_auth_module AS pam
    JOIN metaschema_public.schema AS s ON s.id = pam.schema_id
    LEFT JOIN metaschema_public.table AS ut ON ut.id = pam.users_table_id
    LEFT JOIN metaschema_public.schema AS us ON us.id = ut.schema_id
    WHERE pam.database_id = app_scope.platform_database_id();

    IF principals_schema IS NULL OR users_table IS NULL THEN
        RAISE EXCEPTION 'SERVICE_PRINCIPAL_MODULE_MISSING: the platform database has no principal_auth_module';
    END IF;

    -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: relation names come from the catalog registration, values are bound
    RETURN QUERY EXECUTE format(
        'SELECT p.user_id, p.bypass_step_up, owner.id, owner.type FROM %I.%I AS p '
        'LEFT JOIN %I.%I AS owner ON owner.id = p.owner_id WHERE p.name = $1',
        principals_schema, principals_table, users_schema, users_table
    ) USING service_principal.principal_name;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.service_principal(text) FROM PUBLIC;

COMMIT;
