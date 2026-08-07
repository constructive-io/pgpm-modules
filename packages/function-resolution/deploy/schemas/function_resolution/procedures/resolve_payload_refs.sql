-- Deploy schemas/function_resolution/procedures/resolve_payload_refs to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/resolve_bucket
-- requires: schemas/function_resolution/procedures/resolve_api
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table

BEGIN;

-- resolve_payload_refs: rewrite a job payload's typed references into
-- actionable coordinates, before anything outside the database sees it.
--
-- A payload is otherwise opaque jsonb: nothing tells a worker which string is a
-- bucket and which is a label. Tagging the leaf makes it self-describing, and
-- one pass turns the whole payload into data a function can act on without ever
-- querying the metaschema — which is the property that lets a function image be
-- tenant-agnostic and language-agnostic at once:
--
--   {"$ref": "bucket", "tags": ["variants"], "type": "private"}
--   {"$ref": "table",  "schema": "public", "name": "documents"}
--   {"$ref": "api",    "module": "notifications_module"}   -- or {"name": "admin"}
--
-- Secrets are deliberately NOT part of this vocabulary. A payload carries
-- coordinates and handles, never a credential (nor even a credential's name to
-- be looked up later); required_secrets on the definition stays the only
-- declaration, resolved per invocation through the realm's getter inside the
-- runtime.
--
-- An unknown $ref kind raises rather than passing through, so a typo in a node
-- type's payload schema fails at the boundary instead of reaching a function as
-- an object it will silently ignore.
--
-- Idempotent: a node that already carries its resolved id is left alone, so
-- re-running the pass over an already-resolved payload is a no-op.
CREATE FUNCTION function_resolution.resolve_payload_refs(
    database_id uuid,
    scope text,
    entity_id uuid,
    payload jsonb
) RETURNS jsonb AS $$
DECLARE
    v_kind text;
    v_tags text[];
    v_bucket record;
    v_api record;
    v_selector text;
    v_schema text;
    v_name text;
    v_table_id uuid;
    v_result jsonb;
    v_key text;
BEGIN
    IF resolve_payload_refs.payload IS NULL THEN
        RETURN NULL;
    END IF;

    IF jsonb_typeof(resolve_payload_refs.payload) = 'array' THEN
        SELECT coalesce(jsonb_agg(
                   function_resolution.resolve_payload_refs(
                       resolve_payload_refs.database_id,
                       resolve_payload_refs.scope,
                       resolve_payload_refs.entity_id,
                       elem
                   ) ORDER BY ord
               ), '[]'::jsonb)
        INTO v_result
        FROM jsonb_array_elements(resolve_payload_refs.payload) WITH ORDINALITY AS t(elem, ord);

        RETURN v_result;
    END IF;

    IF jsonb_typeof(resolve_payload_refs.payload) <> 'object' THEN
        RETURN resolve_payload_refs.payload;
    END IF;

    IF NOT (resolve_payload_refs.payload ? '$ref') THEN
        v_result := '{}'::jsonb;

        FOR v_key IN SELECT k FROM jsonb_object_keys(resolve_payload_refs.payload) k
        LOOP
            v_result := v_result || jsonb_build_object(
                v_key,
                function_resolution.resolve_payload_refs(
                    resolve_payload_refs.database_id,
                    resolve_payload_refs.scope,
                    resolve_payload_refs.entity_id,
                    resolve_payload_refs.payload -> v_key
                )
            );
        END LOOP;

        RETURN v_result;
    END IF;

    v_kind := resolve_payload_refs.payload->>'$ref';

    IF v_kind = 'bucket' THEN
        -- Already resolved (trigger-time stamping, or a second pass).
        IF resolve_payload_refs.payload ? 'bucket_id' THEN
            RETURN resolve_payload_refs.payload;
        END IF;

        IF resolve_payload_refs.payload ? 'tags' THEN
            SELECT array_agg(t.tag ORDER BY t.ord)
            INTO v_tags
            FROM jsonb_array_elements_text(resolve_payload_refs.payload->'tags')
                 WITH ORDINALITY AS t(tag, ord);
        ELSIF resolve_payload_refs.payload ? 'key' THEN
            -- A single key is the one-tag selector: the declaration vocabulary
            -- and the payload vocabulary stay the same thing.
            v_tags := ARRAY[resolve_payload_refs.payload->>'key'];
        END IF;

        SELECT *
        INTO v_bucket
        FROM function_resolution.resolve_bucket(
            resolve_payload_refs.database_id,
            resolve_payload_refs.scope,
            resolve_payload_refs.entity_id,
            v_tags,
            resolve_payload_refs.payload->>'type'
        );

        RETURN jsonb_build_object(
            '$ref', 'bucket',
            'bucket_id', v_bucket.bucket_id,
            'key', v_bucket.bucket_key,
            'type', v_bucket.bucket_type,
            'physical_name', v_bucket.physical_name,
            'database_id', v_bucket.owner_database_id
        );
    END IF;

    IF v_kind = 'api' THEN
        IF resolve_payload_refs.payload ? 'api_id' THEN
            RETURN resolve_payload_refs.payload;
        END IF;

        -- Both keys carry the selector vocabulary itself: module is a module
        -- name (optionally .api / @scope), name is an api name.
        v_selector := coalesce(
            resolve_payload_refs.payload->>'module',
            resolve_payload_refs.payload->>'name'
        );

        SELECT *
        INTO v_api
        FROM function_resolution.resolve_api(
            resolve_payload_refs.database_id,
            resolve_payload_refs.scope,
            resolve_payload_refs.entity_id,
            v_selector
        );

        RETURN jsonb_build_object(
            '$ref', 'api',
            'api_id', v_api.api_id,
            'name', v_api.api_name,
            'database_id', v_api.owner_database_id
        );
    END IF;

    IF v_kind = 'table' THEN
        IF resolve_payload_refs.payload ? 'table_id' THEN
            RETURN resolve_payload_refs.payload;
        END IF;

        v_schema := resolve_payload_refs.payload->>'schema';
        v_name := resolve_payload_refs.payload->>'name';

        IF v_schema IS NULL OR v_name IS NULL THEN
            RAISE EXCEPTION 'CAPABILITY_TABLE_REF_INVALID: a table reference needs both schema and name (got %)',
                resolve_payload_refs.payload
                USING ERRCODE = 'FR031';
        END IF;

        SELECT t.id
        INTO v_table_id
        FROM metaschema_public.schema s
        JOIN metaschema_public."table" t ON (t.schema_id = s.id AND t.database_id = s.database_id)
        WHERE s.database_id = resolve_payload_refs.database_id
          AND s.schema_name = v_schema
          AND t.name = v_name;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'CAPABILITY_TABLE_NOT_FOUND: database % has no table %.%',
                resolve_payload_refs.database_id, v_schema, v_name
                USING ERRCODE = 'FR032';
        END IF;

        RETURN jsonb_build_object(
            '$ref', 'table',
            'schema', v_schema,
            'name', v_name,
            'table_id', v_table_id
        );
    END IF;

    RAISE EXCEPTION 'CAPABILITY_REF_UNKNOWN: "%" is not a known payload reference kind (known kinds: bucket, table, api)',
        v_kind
        USING ERRCODE = 'FR030';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
