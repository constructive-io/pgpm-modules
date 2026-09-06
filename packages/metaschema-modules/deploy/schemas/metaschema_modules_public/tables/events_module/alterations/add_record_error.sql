-- Deploy schemas/metaschema_modules_public/tables/events_module/alterations/add_record_error to pg

-- requires: schemas/metaschema_modules_public/tables/events_module/table

BEGIN;

-- Generated private function that records a refused operation under its error
-- code as the event name; the server discovers it here, beside record_event.
ALTER TABLE metaschema_modules_public.events_module
  ADD COLUMN record_error text NOT NULL DEFAULT '';

COMMIT;
