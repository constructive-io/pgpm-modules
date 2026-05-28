-- Deploy schemas/metaschema_modules_public/tables/agent_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.agent_module (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,

  -- Schema references (if uuid_nil, resolved from schema name or default)
  schema_id uuid NOT NULL DEFAULT uuid_nil(),
  private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

  -- Generated table IDs (populated by the generator)
  thread_table_id uuid NOT NULL DEFAULT uuid_nil(),
  message_table_id uuid NOT NULL DEFAULT uuid_nil(),
  task_table_id uuid NOT NULL DEFAULT uuid_nil(),
  prompts_table_id uuid NOT NULL DEFAULT uuid_nil(),
  knowledge_table_id uuid DEFAULT NULL,

  -- Table names (input to the generator)
  thread_table_name text NOT NULL DEFAULT 'agent_thread',
  message_table_name text NOT NULL DEFAULT 'agent_message',
  task_table_name text NOT NULL DEFAULT 'agent_task',
  prompts_table_name text NOT NULL DEFAULT 'agent_prompt',
  knowledge_table_name text NOT NULL DEFAULT 'agent_knowledge',

  -- Feature flags
  has_knowledge boolean NOT NULL DEFAULT false,

  -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
  api_name text DEFAULT 'agent',

  -- Multi-tenant scope
  membership_type int DEFAULT NULL,

  -- Module key discriminator: allows multiple agent modules per scope.
  -- 'default' is omitted from table names, any other value becomes
  -- an infix: {prefix}_{key}_agent_thread.
  -- Max 16 chars, lowercase snake_case.
  key text NOT NULL DEFAULT 'default',

  -- Entity table for RLS (NULL for app-level, entity table for entity-scoped)
  entity_table_id uuid NULL,

  -- Configurable security policies (NULL = use defaults based on membership_type)
  policies jsonb NULL,

  -- Knowledge RAG config (dimensions, chunk_size, chunk_strategy, search_indexes, etc.)
  -- NULL = use sensible defaults (768d, 1000 chars, paragraph, bm25)
  knowledge_config jsonb NULL,

  -- Custom RLS policies for knowledge table (provisions.knowledge.policies)
  -- NULL = use defaults (AuthzEntityMembership or AuthzAppMembership)
  knowledge_policies jsonb NULL,

  -- Per-table provisions overrides from blueprint config.
  -- Keys are table keys (thread, message, task, prompt, knowledge).
  -- When a key is present, the module trigger skips default security for that table;
  -- secure_table_provision applies the custom grants/policies instead.
  provisions jsonb NULL,

  -- Constraints
  CONSTRAINT agent_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT agent_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT agent_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT agent_module_thread_table_fkey FOREIGN KEY (thread_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT agent_module_message_table_fkey FOREIGN KEY (message_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT agent_module_task_table_fkey FOREIGN KEY (task_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT agent_module_prompts_table_fkey FOREIGN KEY (prompts_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT agent_module_knowledge_table_fkey FOREIGN KEY (knowledge_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT agent_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX agent_module_database_id_idx ON metaschema_modules_public.agent_module ( database_id );

-- Unique constraint on (database_id, membership_type, key) using COALESCE to handle NULLs.
-- NULL membership_type = app-level, non-NULL = entity-scoped. key discriminates
-- multiple agent modules for the same scope (e.g. 'support' + 'internal').
CREATE UNIQUE INDEX agent_module_unique_scope ON metaschema_modules_public.agent_module ( database_id, COALESCE(membership_type, -1), key );

COMMIT;
