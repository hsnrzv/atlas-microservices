# Architecture Decision Records (atlas-backend)

Format and rules: [ADR-0001](0001-record-architecture-decisions.md). Copy
[`0000-template.md`](0000-template.md) for a new record and use the next free number.

| ADR | Title | Status | Date |
|---|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 2026-11-12 |
| [0002](0002-modular-monolith-with-spring-modulith.md) | Modular monolith with Spring Modulith in repository `atlas-microservices` | Accepted | 2026-11-12 |
| [0003](0003-postgresql-flyway-jpa.md) | PostgreSQL 18, Flyway migrations and Spring Data JPA (no Hibernate schema generation) | Accepted | 2026-11-12 |
| [0004](0004-database-schema-strategy.md) | Database schema strategy: one `atlas` schema with module-owned, module-prefixed tables | Proposed | 2026-11-12 |
| [0005](0005-authentication-provider-neutral-oidc.md) | Authentication: provider-neutral OIDC, BFF session for web, PKCE system browser for Capacitor | Proposed; provider (Microsoft Entra External ID) accepted 2026-11-12 | 2026-11-12 |
| [0006](0006-rest-api-openapi-problem-details.md) | REST API under `/api/v1`, code-first OpenAPI, RFC 9457 Problem Details | Proposed | 2026-11-12 |
| [0007](0007-java-21-spring-boot-4-1-maven-wrapper.md) | Java 21, Spring Boot 4.1 and the Maven Wrapper as the backend baseline | Accepted; Java part superseded by ADR-0008; Boot 4.2 addendum 2026-11-27 | 2026-11-12 |
| [0008](0008-java-25-lts-runtime.md) | Java 25 LTS as the backend runtime | Accepted | 2026-11-12 |

Status meanings: **Proposed** (awaiting owner review), **Accepted** (owner decision or Phase 1 baseline
implemented and verified), **Superseded by ADR-NNNN**.

Cross-cutting decisions live in the `atlas` repository (`atlas/docs/adr/`): 0001 record decisions,
0002 repository topology & ownership, 0003 UI component stack, 0004 visualization stack, 0005 icon
library (Tabler), 0006 UI vocabulary & domain mapping, 0007 design tokens as source of truth,
0008 frontend test toolchain. Infrastructure decisions live in `atlas-infra/docs/adr/`.
