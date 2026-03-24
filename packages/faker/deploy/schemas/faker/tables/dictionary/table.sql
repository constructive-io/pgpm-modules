-- Deploy schemas/faker/tables/dictionary/table to pg

-- requires: schemas/faker/schema

BEGIN;

CREATE TABLE faker.dictionary (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    type text,
    word text
);

CREATE INDEX faker_type_idx ON faker.dictionary (
 type
);

COMMIT;
