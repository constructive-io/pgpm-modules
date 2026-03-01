-- Deploy schemas/measurements/tables/quantities/table to pg

-- requires: schemas/measurements/schema

BEGIN;

CREATE TABLE measurements.quantities (
    id serial PRIMARY KEY,
    name text,
    label text,
    unit text,
    unit_desc text,
    description text
);

COMMENT ON TABLE measurements.quantities IS 'Unit of measure definitions: maps quantity names to their display labels, units, and descriptions';
COMMENT ON COLUMN measurements.quantities.id IS 'Auto-incrementing identifier for this quantity';
COMMENT ON COLUMN measurements.quantities.name IS 'Machine-readable name for this quantity (e.g. length, mass, temperature)';
COMMENT ON COLUMN measurements.quantities.label IS 'Human-readable display label';
COMMENT ON COLUMN measurements.quantities.unit IS 'Unit symbol or abbreviation (e.g. m, kg, °C)';
COMMENT ON COLUMN measurements.quantities.unit_desc IS 'Full unit name (e.g. meters, kilograms, degrees Celsius)';
COMMENT ON COLUMN measurements.quantities.description IS 'Detailed description of what this quantity measures';

COMMIT;
