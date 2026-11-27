# ADR-0006: REST API under `/api/v1`, code-first OpenAPI, RFC 9457 Problem Details

- Status: Accepted (2026-11-27, owner review BE-2.2)
- Date: 2026-11-12
- Deciders: @hsnrzv (owner); proposed by the backend planning agent

## Context

The Angular web client, the Capacitor apps and possibly later AI/MCP adapters consume the backend.
`project-instruction.md` §9.3 and §11.5–§11.6 require:

- A versioned REST API under `/api/v1`, with JSON and ISO 8601 dates.
- Consistent Problem Details errors.
- A published OpenAPI document from which the frontend generates types.
- CI that detects contract drift, and an explicit plan for breaking changes.

The edge routing contract sends `/api/` to the backend. Phase 1 already enables Spring MVC Problem
Details (`spring.mvc.problemdetails.enabled=true`). The integration test checks that unknown paths
return `application/problem+json`.

Verified on 2026-11-12 (Maven Central): `org.springdoc:springdoc-openapi-starter-webmvc-api` /
`-webmvc-ui` latest release **3.2.0**, built against `spring-boot-starter-parent` 4.1.2, Apache-2.0. Not
added in Phase 1 because there are no endpoints yet.

Spike BE-2.3 (2026-11-27, throwaway branch, not merged): **3.2.1** runs on Spring Boot 4.2.0 with Jackson
3.1.8 and serves OpenAPI 3.1.0. Records, `UUID`, `LocalDate`, `Instant` and enums are described correctly.
Three gaps need configuration in Phase 3 (BE-3.05):

- `BigDecimal` is documented as `number` although it is serialised as a string.
- The default `servers` entry contains the random test port, and the response content type is `*/*`.
- Required properties, the security scheme and the `ETag` header are not documented by default.

Details: `docs/implementation/phase-2-contract-review.md` §4 (S-1…S-5).

## Decision

Proposed default:

1. **REST over JSON under `/api/v1`.** Resource-oriented paths per module (`/api/v1/goals/...`). The
   details are in `docs/architecture/API-CONTRACT.md`:
   - HTTP semantics as in RFC 9110 (`POST` creates → `201` + `Location`; `PATCH` partial update;
     `DELETE` deletes permanently; resources that can be archived have explicit `archive`/`restore`
     actions instead, API-CONTRACT A-1).
   - JPA entities are never exposed; each module has request/response records in its `api` package.
   - UUID identifiers; money as `{ "amount": "1234.50", "currency": "EUR" }` (decimal string);
     date-only values as `YYYY-MM-DD`; instants as UTC ISO 8601 with `Z`.
2. **Errors are RFC 9457 Problem Details** (`application/problem+json`) from one global
   `@RestControllerAdvice` (extending `ResponseEntityExceptionHandler`).
   - Each response has a stable `type` URI per error kind, `title`, `status`, `detail`, `instance`, plus
     the extension members `code` (stable machine key) and `errors[]` (field violations) for validation
     failures.
   - Stack traces, SQL and personal values never appear in error bodies.
3. **Concurrency:** optimistic locking with a `version` column, exposed as a strong `ETag` and required
   as `If-Match` on `PUT`/`PATCH`/`DELETE` of versioned resources. A missing header returns `428`; a
   stale one returns `412`.
4. **Idempotency:** `POST` operations that could duplicate a completion or a financial impact accept an
   `Idempotency-Key` header (see API-CONTRACT).
5. **OpenAPI is generated from code** with springdoc-openapi (`springdoc-openapi-starter-webmvc-api`
   3.2.1 or later, added in Phase 3; compatibility with Boot 4.2 verified by spike BE-2.3).
   - A Testcontainers integration test writes `target/openapi/openapi.json`, and a committed snapshot
     `docs/api/openapi.json` must match it. The PR diff then shows every contract change.
   - CI publishes the document as a build artifact. `openapi-publish.yml` with breaking-change detection
     (tool to be selected and license-checked) follows in Phase 4.
   - The `atlas` repository generates its TypeScript client/types from the published document.
   - `/v3/api-docs` is enabled only for `local` and `dev`. No Swagger UI in staging/prod.
6. **Versioning:** additive changes (new optional fields, new endpoints, new enum values announced in
   advance) stay in `v1`. Clients must ignore unknown fields. Removing or renaming fields, changing
   types or semantics, or making optional input required is breaking. Breaking changes need `/api/v2` for
   the affected resources, or a documented expand/contract plan that keeps `v1` working until all
   clients (including installed mobile apps) are upgraded.

## Consequences

- Backend developers keep one source of truth (Java DTOs plus annotations). The committed snapshot
  makes contract changes reviewable without contract-first tooling.
- The frontend depends on the published document. CI in `atlas` should fail if generated types drift
  (owned by `atlas`).
- Code-first can lead to accidental contract changes (renamed record components). The snapshot test and
  the later breaking-change check are the guard.
- Mobile apps stay installed for a long time, so `v1` compatibility must be kept longer than for the web
  client alone.

## Alternatives considered

- **Contract-first (hand-written OpenAPI + generated server interfaces):** strongest contract
  discipline and good for several teams. But it adds a generator to the build and a second
  representation for a single developer working on both sides. Can be adopted later; the committed
  snapshot keeps the option open.
- **Spring REST Docs:** test-driven documentation, but it produces AsciiDoc snippets. OpenAPI output
  needs third-party extensions.
- **GraphQL:** flexible reads for the dashboard, but it adds schema/tooling complexity and makes caching
  and error semantics less standard. Not needed for the planned endpoints.
- **Custom error JSON:** no benefit over the RFC; Spring supports Problem Details out of the box.

## References

- `project-instruction.md` §9.3, §11.5, §11.6, §13.4, §16.2, §17.2
- RFC 9457, Problem Details for HTTP APIs: <https://www.rfc-editor.org/rfc/rfc9457>
- RFC 9110, HTTP Semantics: <https://www.rfc-editor.org/rfc/rfc9110>
- IETF draft, The Idempotency-Key HTTP Header Field:
  <https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/> (accessed 2026-11-12)
- springdoc-openapi: <https://springdoc.org/>; Maven Central metadata for
  `org.springdoc:springdoc-openapi-starter-webmvc-ui` (accessed 2026-11-12)
- `docs/architecture/API-CONTRACT.md`; see `atlas` ADR-0006 (UI vocabulary & domain mapping)
