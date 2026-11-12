# ADR-0003: PostgreSQL 18, Flyway migrations and Spring Data JPA (no Hibernate schema generation)

- Status: Accepted
- Date: 2026-11-12
- Deciders: @hsnrzv (owner)

## Context

The data is strongly relational: hierarchical goal trees, dependencies, typed links, money with
currency and frequency, and per-owner data. It needs transactions, constraints and queries across these
relationships. `project-instruction.md` §9.3–§9.4 propose PostgreSQL 18, Flyway and Spring Data JPA,
and §12.1 forbids relying on Hibernate schema auto-update outside throwaway environments. Phase 1 must
connect to PostgreSQL through Flyway (§18).

Verified on 2026-11-12: Docker image `postgres:18.6-alpine` exists. Spring Boot 4.1.2 manages Flyway
12.4.0, Hibernate ORM 7.4.13.Final and PostgreSQL JDBC 42.7.14. Since Flyway 10, PostgreSQL support is a
separate artifact, `flyway-database-postgresql`.

## Decision

- **PostgreSQL 18** (latest 18.x patch per environment; locally and in tests `postgres:18.6-alpine`) is
  the single source of truth. Database name `atlas`, application schema `atlas`; `public` is unused.
- **Flyway** owns the schema:
  - Plain SQL migrations live in `src/main/resources/db/migration`, named `V<n>__<module>_<description>.sql`.
  - Flyway runs at application start-up with `default-schema=atlas`, `schemas=atlas` and
    `create-schemas=true`. Its history table is `atlas.flyway_schema_history`.
  - Applied migrations are immutable. Changes are forward-compatible (expand/contract), so the previous
    application version keeps working during a rolling deployment.
- **Spring Data JPA / Hibernate** maps the tables with `spring.jpa.hibernate.ddl-auto=validate` in every
  profile, including tests. Hibernate never creates or alters schema objects. `open-in-view` is
  disabled. Repositories stay internal to their owning module.
- Tests run every migration against a real PostgreSQL 18 container (Testcontainers) on every
  `./mvnw verify`. There is no H2 or other in-memory substitute.
- Local development uses `compose.yaml` (PostgreSQL only, local-only credentials) through Spring Boot's
  Docker Compose support.

Phase 1 delivered `V1__baseline.sql`. It documents the schema conventions and creates no tables.

## Consequences

- Schema changes are reviewable SQL and versioned with the code. CI proves that migrations apply from an
  empty database. A mismatch between entities and schema fails fast at start-up (`validate`).
- Developers write DDL by hand: entities and migrations must be kept in sync, and `validate` catches
  drift.
- Running migrations at application start is simple for one replica. With several replicas, Flyway's
  lock serialises them. Whether migrations run as a separate Kubernetes Job or Argo CD sync hook is an
  infrastructure decision (see `atlas-infra` PLAN-INFRASTRUCTURE-CICD). The image already contains
  everything needed for either option.
- The database user needs `CREATE` rights on the database for the first run (schema creation). A
  separate migration user versus runtime user is an open decision in `docs/plan/PLAN-DATABASE.md`.

## Alternatives considered

- **Liquibase:** equally capable; XML/YAML changelogs add abstraction that this project does not need,
  because it targets PostgreSQL only and the team prefers plain SQL.
- **Hibernate `ddl-auto=update`:** no review, no rollback story, silent destructive edge cases.
  Forbidden by §12.1.
- **jOOQ or Spring Data JDBC instead of JPA:** more explicit SQL. JPA was chosen for team familiarity
  and aggregate mapping (§9.3). Module-internal read models may still use `JdbcClient` where JPA is
  awkward.
- **MongoDB / Cosmos DB:** excluded by §2.3 and §9.4; the model is relational.

## References

- `project-instruction.md` §9.3, §9.4, §12, §16.4, §17.3
- PostgreSQL 18 documentation: <https://www.postgresql.org/docs/18/> (accessed 2026-11-12)
- Spring Boot "Database Initialization" how-to (Flyway, `ddl-auto`):
  <https://docs.spring.io/spring-boot/how-to/data-initialization.html> (accessed 2026-11-12)
- Flyway: <https://github.com/flyway/flyway> (accessed 2026-11-12)
- `src/main/resources/db/migration/README.md`, `docs/plan/PLAN-DATABASE.md`, ADR-0004
