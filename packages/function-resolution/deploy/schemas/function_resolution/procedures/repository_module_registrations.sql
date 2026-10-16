-- Deploy schemas/function_resolution/procedures/repository_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/repository_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- repository_module_registrations: the repository_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.repository_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    prefix text,
    entity_field text,
    host_database_id uuid,
    repositories_table_name text,
    repository_events_table_name text,
    workflows_table_name text,
    builds_table_name text,
    build_steps_table_name text,
    proposals_table_name text,
    proposal_comments_table_name text,
    proposal_reactions_table_name text,
    proposal_reviews_table_name text,
    proposal_file_views_table_name text,
    repository_required_checks_table_name text,
    has_builds boolean,
    has_attachments boolean,
    public_schema text,
    private_schema text
) AS $$
SELECT
    rpm.database_id,
    (rpm.database_id = app_scope.platform_database_id()) AS platform_owned,
    rpm.scope,
    rpm.prefix,
    rpm.entity_field,
    rpm.database_id AS host_database_id,
    rpm.repositories_table_name,
    rpm.repository_events_table_name,
    rpm.workflows_table_name,
    rpm.builds_table_name,
    rpm.build_steps_table_name,
    rpm.proposals_table_name,
    rpm.proposal_comments_table_name,
    rpm.proposal_reactions_table_name,
    rpm.proposal_reviews_table_name,
    rpm.proposal_file_views_table_name,
    rpm.repository_required_checks_table_name,
    rpm.has_builds,
    rpm.has_attachments,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.repository_module AS rpm
    LEFT JOIN metaschema_public.schema ps ON ps.id = rpm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = rpm.private_schema_id
WHERE ($1 IS NULL OR rpm.database_id = $1)
  AND ($2 IS NULL OR rpm.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.repository_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
