# ADR-0004: Database schema strategy: one `atlas` schema with module-owned, module-prefixed tables

- Status: Accepted (2026-11-27, owner review BE-2.2/DB-2.1)
- Date: 2026-11-12
- Deciders: @hsnrzv (owner); proposed by the backend planning agent

## Context

`project-instruction.md` §12.3 and open decision §21.5 ask to choose between:

1. a single PostgreSQL schema with module-prefixed table names and strict repository ownership, or
2. a separate PostgreSQL schema per module with module-specific Flyway locations.

Either way, cross-module foreign keys must not couple every module change. Phase 1 already created a
single Flyway-managed schema `atlas` (cross-repository contract: database `atlas`, user `atlas`, schema
`atlas`, `public` unused). The application is a modular monolith with one data source (ADR-0002) and
one Flyway history (ADR-0003). §12.1 requires `owner_id` at every aggregate boundary.

## Decision

Proposed default:

- **One schema, `atlas`**, managed by one Flyway history (`atlas.flyway_schema_history`) and one
  migration folder.
- **Every table belongs to exactly one module** and starts with that module's prefix:

  | Module | Prefix | Examples (see `docs/plan/PLAN-DATABASE.md`) |
  |---|---|---|
  | `profile` | `profile_` | `profile_app_user`, `profile_preferences` |
  | `onboarding` | `onboarding_` | `onboarding_progress` |
  | `ikigai` | `ikigai_` | `ikigai_area` |
  | `goals` | `goal_` | `goal`, `goal_node`, `goal_node_dependency`, `goal_ikigai_area` |
  | `finance` | `finance_` | `finance_income_source`, `finance_goal_impact` |
  | `capacity` | `capacity_` | `capacity_weekly_availability`, `capacity_time_plan` |
  | `dashboard` | `dashboard_` | only if a persisted read model becomes necessary |
  | later modules | `career_`, `property_`, `fitness_`, `freelance_`, `trading_`, `hobby_`, `relationship_`, `ai_` | |

  The goals module uses `goal` / `goal_` because the spec's table names already follow that pattern.
- **Foreign keys stay inside a module**, with one exception: every aggregate root has
  `owner_id UUID NOT NULL` with a foreign key to `profile_app_user(id)`. The FK uses `ON DELETE RESTRICT`,
  so account deletion must explicitly remove (or anonymise) each module's data before the user row can
  be deleted. The database therefore proves that deletion was complete.
- **Cross-module references are plain `UUID` columns without FK** (for example
  `finance_goal_impact.goal_id`). Their integrity is enforced in the application:
  - The writing module validates the reference through the owning module's published API, including
    the owner check.
  - The writing module reacts to the owning module's lifecycle events (`GoalArchived`, `GoalDeleted`)
    so that it does not keep dangling references.
  - These columns are indexed and documented in PLAN-DATABASE as "logical reference → module".
- A module's tables are read and written only through that module's repositories. Other modules use the
  module's Java API or events; reporting/read models are built by the owning module or by `dashboard`
  from published APIs.
- Migration files carry the module name (`V7__goals_create_goal_node.sql`), and each migration touches
  one module.

Re-evaluate this decision if a module needs independent backup/restore, separate database privileges
(for example AI audit data), or extraction into its own service. In that case, moving one module's
prefixed tables to its own schema is a mechanical migration because there are no cross-module FKs.

## Consequences

- One connection pool, one search path, one Flyway history: simplest operations, matches the Phase 1
  baseline and the cross-repository runtime contract.
- Ownership is visible in every table name and migration file. Reviewers can reject a migration that
  touches another module's prefix.
- Without database FKs across modules, a bug can leave a dangling `goal_id` in finance or capacity
  tables. Mitigations: validation through the owning module's API, event-driven clean-up, Testcontainers
  tests for these flows, and (optional) a periodic consistency check query.
- A per-module database privilege boundary is not possible with this layout; all modules use the same
  database user. That is acceptable for the MVP because there is one deployable.
- Table prefixes are slightly verbose (`capacity_time_plan` instead of `goal_time_estimate`), but
  they avoid ambiguous ownership such as a `goal_*` table owned by capacity.

## Alternatives considered

- **Schema per module (`goals`, `finance`, ...):** stronger isolation and per-schema grants are possible.
  But it needs either one Flyway history spanning many schemas or one Flyway instance per module with
  custom ordering. Owner FKs then cross schemas, the Phase 1 contract (`schema atlas`) would change, and
  every environment's tooling (backups, `search_path`, grants) becomes more complex. Not justified for one
  deployable and one user.
- **Single schema with cross-module FKs everywhere:** strongest referential integrity, but a change in
  one module (for example hard-deleting goals) cascades into others. That couples modules at the
  database level, which §12.3 asks to avoid.
- **Unprefixed table names:** shorter, but ownership is not visible, and names like
  `goal_time_estimate` (owned by capacity) would be misleading.

## References

- `project-instruction.md` §11.1, §11.3, §12.1–§12.3, §12.5, §21.5
- ADR-0002, ADR-0003, `docs/plan/PLAN-DATABASE.md`, `docs/architecture/DOMAIN-MODULES.md`
