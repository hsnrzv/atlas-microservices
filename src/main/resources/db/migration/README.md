# Flyway migrations

All schema changes for the `atlas` PostgreSQL schema live here. Hibernate only **validates**
(`spring.jpa.hibernate.ddl-auto=validate`); it never creates or alters tables.

## Rules

1. **Naming:** `V<version>__<module>_<short_description>.sql`, e.g. `V3__goals_create_goal.sql`.
   Versions are plain increasing integers (`V2`, `V3`, ...). Use the owning module name as the first
   word of the description. Repeatable migrations (`R__...`) are reserved for views/functions and need a
   reviewer's explicit approval.
2. **Never edit an applied migration.** Once a migration is merged to `main` it is immutable (Flyway
   validates checksums on start-up). Fix mistakes with a new migration.
3. **One concern per migration**, owned by one module. Do not mix DDL for several modules.
4. **Forward-compatible (expand/contract) changes only.** The previous application version must keep
   working against the new schema during a rolling deployment:
   1. *Expand*: add nullable columns / new tables / new indexes.
   2. Deploy code that reads and writes both shapes.
   3. Backfill in a separate migration if needed.
   4. Switch reads and writes to the new shape.
   5. *Contract*: drop old structures in a later release.
5. **Conventions** (details in `docs/plan/PLAN-DATABASE.md` §4): unqualified table names (Flyway sets
   `search_path` to `atlas`); `snake_case`; tables prefixed with the owning module; UUID primary keys;
   `NUMERIC(19,4)` for money with an ISO 4217 `VARCHAR(3)` currency column
   (`CHECK (currency ~ '^[A-Z]{3}$')`); `DATE` for business dates, `TIMESTAMPTZ` for instants;
   `created_at`, `updated_at`, `version` on aggregate roots; `owner_id` on every aggregate root; enums
   as `VARCHAR` + `CHECK` (no PostgreSQL enum types); named constraints (`pk_`, `fk_`, `uq_`, `ux_`,
   `ck_`, `ix_`).
6. **No cross-module foreign keys** except to the identity owner table once it exists (see ADR-0004).
7. **No data, secrets or personal sample data** in migrations. Seed reference data only when it is part
   of the product (for example the seven Life Dimension keys) and keep it idempotent.
8. **Test every migration**: `./mvnw verify` applies all migrations to a fresh PostgreSQL 18 container.

## Baseline

| Version | Purpose |
|---|---|
| `V1__baseline.sql` | Documents the `atlas` schema conventions. No tables. |
