-- Deploy schemas/metaschema_public/types/object_category to pg

-- requires: schemas/metaschema_public/schema

BEGIN;

-- Unified category type for all metaschema objects (tables, fields, procedures, triggers, indexes, policies, constraints, etc.)
-- 'core' - system-level objects (id fields, entity_id, actor_id, etc.)
-- 'module' - objects created by modules (users, capabilities, memberships, etc.)
-- 'capabilities' - capability-framework objects (SPRTs, grants, capability defaults) — excluded from exports via excludeCategories
-- 'auth' - authentication/session objects (sessions, rate limits, identity providers) — excluded from exports via excludeCategories
-- 'memberships' - membership-structure objects (memberships, members, profiles, settings) — excluded from exports via excludeCategories
-- 'app' - user-defined application objects
CREATE TYPE metaschema_public.object_category AS ENUM ('core', 'module', 'capabilities', 'auth', 'memberships', 'app');

COMMIT;
