-- Deploy schemas/function_resolution/procedures/catalog_location to pg
-- requires: schemas/function_resolution/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/catalog_module/table

BEGIN;

-- catalog_location: deterministically resolve the typed functions-catalog
-- table (schema, table) for one database. The catalog is the flat,
-- trigger-maintained projection every function definition of every scope
-- hosted in that database registers into (catalog_module + catalog_register),
-- keyed by (owner_scope, owner_key, task_identifier).
--
-- Returns no row when the database has no catalog module or its catalog has
-- no functions table — callers treat that as "catalog resolution unavailable
-- for this database" and decide (fail loud vs frame-walk fallback) at their
-- layer. More than one catalog module for one database is a provisioning bug
-- and raises.
CREATE FUNCTION function_resolution.catalog_location(
    database_id uuid
) RETURNS TABLE (
    schema_name text,
    table_name text
) AS $$
DECLARE
    v_functions_table_id uuid;
BEGIN
    BEGIN
        SELECT cm.functions_table_id
        INTO STRICT v_functions_table_id
        FROM metaschema_modules_public.catalog_module cm
        WHERE cm.database_id = catalog_location.database_id
          AND cm.functions_table_id <> uuid_nil();
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN;
        WHEN TOO_MANY_ROWS THEN
            RAISE EXCEPTION 'FUNCTION_RESOLUTION_CATALOG_AMBIGUOUS: multiple functions catalogs registered for database %',
                catalog_location.database_id;
    END;

    SELECT s.schema_name, t.name
    INTO catalog_location.schema_name, catalog_location.table_name
    FROM metaschema_public.schema s
    JOIN metaschema_public."table" t ON (t.schema_id = s.id AND t.database_id = s.database_id)
    WHERE t.id = v_functions_table_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
