-- V1 baseline: establishes the conventions of the Flyway-managed `atlas` schema.
-- Flyway creates the schema (spring.flyway.create-schemas=true) and runs every migration with
-- search_path set to `atlas`, so later migrations use unqualified table names.
-- Domain tables are introduced from Phase 3 onwards, one module-owned migration at a time.
-- Conventions: docs/plan/PLAN-DATABASE.md and src/main/resources/db/migration/README.md.

COMMENT ON SCHEMA atlas IS
    'IKIGAI ATLAS system of record. Managed exclusively by Flyway (atlas-backend). '
    'Tables are owned by one application module and prefixed with its name; see docs/plan/PLAN-DATABASE.md.';
