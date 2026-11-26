# Implementation roadmap — atlas-backend

- Status: **Proposed 2026-11-17**, awaiting owner approval. Phase 1 is delivered and pushed to `origin/main`
  (2026-11-26) except BE-1.12…BE-1.15; phases 2–4 have not started. No feature code exists yet
  (only `AtlasApplication`).
- Purpose: set the order in which the backend is built, phase by phase, with an explicit gate between phases and the
  cross-repository hand-offs that unblock the frontend and infrastructure.
- Maps the cross-repository phases P0–P11 in `atlas` `docs/plan/IMPLEMENTATION-ROADMAP.md` onto the existing backlog
  in [PLAN-BACKEND §14](../plan/PLAN-BACKEND.md#14-pr-sized-backlog-phases-14) (`BE-…` IDs) and
  [PLAN-DATABASE](../plan/PLAN-DATABASE.md). Those documents stay authoritative for scope and acceptance criteria;
  this one sets the order, the gates and the dependencies.
- Related: [DOMAIN-MODULES](../architecture/DOMAIN-MODULES.md), [API-CONTRACT](../architecture/API-CONTRACT.md),
  [ADR index](../adr/README.md); siblings: `atlas` `docs/implementation/roadmap.md` (frontend),
  `atlas-infra` `docs/implementation/roadmap.md` (infrastructure, `INF-…` IDs).

## 1. Working rules

- **One backlog item per PR**, small and reviewable (aim < 400 changed lines excluding generated files and
  migrations). Each PR names its backlog ID and meets the Definition of Done (`project-instruction.md` §19).
- Every PR runs `./mvnw -B verify` green with JDK 25 and Docker available (Testcontainers ITs must run, not skip).
- A phase starts only after the owner approves the previous gate. Phases overlap only where marked.
- Contract changes go through the committed OpenAPI snapshot (`docs/api/openapi.json`, BE-3.05). A change to a
  published endpoint updates API-CONTRACT and the frontend's open questions (`atlas` frontend.md §6.5, FQ-…).
- Derived values (progress, availability, reasons, rewards) are computed here only; the frontend never recalculates
  them (R-4).
- Every endpoint is owner-scoped and covered by the cross-owner matrix (R-3, BE-3.81). The `local` development
  identity is never enabled outside `local` (B-2).
- Migrations are expand/contract and tested from the previous version (PLAN-DATABASE §10).
- Dependencies: permissive licences only; update `THIRD-PARTY-NOTICES.md` in the same PR.

## 2. Phases

### Phase 1 — Foundations (repo P1 finish)

| ID | Item | Status |
|---|---|---|
| BE-1.1…1.11 | Boot 4.1.2 scaffold (Java 25), profiles, compose PostgreSQL, Flyway V1, Modulith test, IT, Docker, CI | done 2026-11-12 (local) |
| BE-1.12 | JaCoCo report in `verify`, uploaded by CI (no gate yet) | done 2026-11-26 (local; CI run pending BE-1.15) |
| BE-1.13 | CycloneDX SBOM + container vulnerability scan, fail on fixable critical/high | open; Trivy proposed (same as `atlas` F2-11), to be agreed with infra |
| BE-1.14 | Owner: push, dependency graph, Dependabot alerts, secret scanning with push protection, branch protection | in progress (owner action): pushed to `origin/main` by 2026-11-26; repository settings and branch protection open |
| BE-1.15 | First green run of `backend-ci` and `backend-container` on GitHub | open; `main` is pushed, first green run to be confirmed |

**Gate 1:** both workflows green on GitHub; branch protection requires them; SBOM and scan run in CI.

### Phase 2 — Contract alignment (no feature code)

Runs in parallel with the frontend's mock-backed shell (already delivered in `atlas`).

| ID | Item | Status |
|---|---|---|
| BE-2.1 | Review API-CONTRACT §9.1–§9.7 against the delivered frontend ports and FQ-1…FQ-22; resolve A-1…A-6 | open; the frontend ports and FQ list are ready for review |
| BE-2.2 | Owner review of ADR-0004, ADR-0005, ADR-0006, B-1…B-13 and D-1…D-9 | open (owner) |
| BE-2.3 | Spike (≤ 1 day, throwaway): springdoc 3.x with Boot 4.1/Jackson 3; JWT `audiences` | open |
| BE-2.4 | Publish `main-<sha>` to GHCR (provenance, SBOM, scan) and open the bump PR to `atlas-infra` | blocked: `atlas-infra` ADR-0007 is Proposed; needs BE-1.13 |

**Gate 2:** ADR-0004/0005/0006 accepted or revised; A-1…A-6 resolved and each FQ answered or deferred to a phase;
spike findings recorded. BE-2.4 may finish later (it is not on the critical path for phase 3).

### Phase 3 — Core domain and database

Order per PLAN-BACKEND §14. Steps run in order; within a step the items are sequential.

| Step | ID(s) | Item | Unblocks | Status |
|---|---|---|---|---|
| 3.0 | BE-3.01 | `shared` module: value types, `Clock`, Jackson config | everything below | open |
| 3.0 | BE-3.02 | Problem Details error model and `code` catalogue | `atlas` F4-2 error mapping | open |
| 3.0 | BE-3.03 | Security baseline: resource server, `CurrentOwner`, `local` development identity with start-up guard | BE-4.2 | open |
| 3.0 | BE-3.04 | `ETag`/`If-Match`, pagination, `Idempotency-Key` component | `atlas` F4-3 against the real API | open |
| 3.0 | BE-3.05 | springdoc, snapshot test, `docs/api/openapi.json` | early snapshot for `atlas` F3-5 | open |
| 3.0 | BE-3.06 | Architecture tests and JaCoCo gates | — | open |
| 3.1 | BE-3.10…3.12 | Profile (JIT owner), baseline snapshot, onboarding | `atlas` onboarding flow | open |
| 3.2 | BE-3.20 | Life Dimensions (`ikigai` areas) | `atlas` Life Dimensions page | open |
| 3.3 | BE-3.30, 3.31 | Goals and node tree (bounds B-12) | `atlas` Destinations/Waypoints (critical path) | open |
| 3.4 | BE-3.40, 3.41 | Dependencies, unlocks, complete/reopen, audited override | `atlas` Connections, Steps | open |
| 3.5 | BE-3.50, 3.51 | Progress calculator and rewards | `atlas` Awards, progress display | open |
| 3.6 | BE-3.60…3.62 | Notes, change log, goal links | `atlas` notes, Journey history | open |
| 3.7 | BE-3.70, 3.71 | Timeline read model and dashboard | `atlas` My Atlas, Journey | open |
| exit | BE-3.80 | `MigrationIT` from the previous version | — | open |
| exit | BE-3.81 | Cross-owner / unauthenticated security matrix for every endpoint family | — | open |
| exit | BE-3.82 | Publish the OpenAPI snapshot; API-CONTRACT points to it | `atlas` F3-5, F4-1 | open |

**Gate 3:** PLAN-BACKEND §12 "Phase 3" criteria met: every Phase 3 endpoint in the snapshot; 401/404/400/412/428
proven per family; domain tests for nested progress, cycles, ALL/ANY and override audit; `MigrationIT` green;
coverage gates met; `ModularityTests` clean. The staging access model (R-2) is decided.

### Phase 4 — Frontend/backend integration

Needs Gate 3 and, for BE-4.5, infra Phase 4 (staging).

| ID | Item | Unblocks | Status |
|---|---|---|---|
| BE-4.1 | `openapi-publish.yml`: versioned artifact per main build + breaking-change check | `atlas` F4-1 regeneration; infra INF-4.1 | open |
| BE-4.2 | Local integration guide: `local` profile + Angular proxy + development identity | `atlas` F4-4, F4-6 | open |
| BE-4.3 | `412` carries the current `ETag`; idempotent replays return the original response | `atlas` F4-3 end to end | open |
| BE-4.4 | Guarded demo-data switch (B-11), off by default | — | open |
| BE-4.5 | Staging readiness: JWT issuer/audience env, DB secrets, access model per R-2; e2e green | `atlas` Gate 9; infra Gate 4 | open |
| BE-4.6 | Performance check: p95 < 300 ms for dashboard and a 500-node tree in staging | — | open |

**Gate 4:** PLAN-BACKEND §12 "Phase 4" criteria met: the frontend runs on the HTTP adapters only; e2e green in
staging with the agreed access model (R-2).

### Phases 5–11 — Outline

IDs are assigned when a phase is planned in detail (one PR per item, as above).

| Phase | Backend work | Depends on |
|---|---|---|
| 5 | Timeline/calendar/chart read models, only if BE-3.70 is insufficient for the visualisations | Gate 4; `atlas` visualisation spike |
| 6 | `finance` (baseline, impacts, realise, scenarios, projection) and `capacity`; onboarding financial step (B-10) | Gate 4; PLAN-DATABASE §6.3 |
| 7 | Export data endpoints | Phases 5–6 |
| 8 | Domain extension modules, one at a time | Phase 6 |
| 9 | BFF login under `/api/auth/**`, `GET /api/v1/me`, logout and CSRF cookie (answers FQ-22); production Entra External ID; Spring Session JDBC tables; account export/deletion; migrate-only mode for the PreSync Job (infra ADR-0008); tracing/metrics export; threat model | Gate 4; infra Phase 9 |
| 10 | Native auth support (CORS/bearer) for Capacitor builds | Phase 9 |
| 11 | `ai` module (dry-run suggestions, audit, apply through use cases) | Phase 9 |

## 3. Cross-repository hand-offs

| Backend delivers | Unblocks |
|---|---|
| BE-1.13 scanner choice | One shared scanner across repositories (`atlas` F2-11 uses Trivy); infra ADR-0007 |
| BE-2.1 reviewed contract | Phase 3 start; answers to `atlas` FQ-1…FQ-21 |
| BE-2.4 GHCR publishing | infra INF-2.2, INF-3.7 (`atlas-dev` runs a real backend image) |
| BE-3.05 / BE-3.82 OpenAPI snapshot | `atlas` F3-5 (client spike), F4-1 (typed client) |
| BE-3.0x…3.7x endpoints + BE-4.2 | `atlas` F4-4 (flows wired), F4-6 (e2e on the full stack) |
| BE-4.1 `openapi-publish` | infra INF-4.1 |
| BE-4.5 staging readiness | `atlas` Gate 9; infra Gate 4 |
| Phase 9 BFF (FQ-22) | `atlas` sets `auth: true` (the F4-5 client is ready and off by default) |

**Critical path:** BE-1.14 → BE-2.2 / BE-2.1 → BE-3.0x → BE-3.3x → BE-3.82 → `atlas` F4-1 → F4-6 → staging e2e
(BE-4.5 with infra Phase 4).

## 4. Decisions

Accepted: ADR-0001, ADR-0002 (modular monolith), ADR-0003 (PostgreSQL/Flyway/JPA), ADR-0007/0008 (Java 25,
Boot 4.1, Maven Wrapper); identity provider Microsoft Entra External ID (B-1, 2026-11-12).

### 4.1 Open decisions to settle before the phase that needs them

| Decision | Recommended default | Needed by |
|---|---|---|
| ADR-0004 schema strategy, ADR-0006 REST/OpenAPI | Accept as proposed | Gate 2 |
| ADR-0005 authentication (provider-neutral OIDC) | Accept; BFF session in Phase 9 | Gate 2 |
| Image scanner (BE-1.13) | Trivy (Apache-2.0), same version and policy as `atlas` | Gate 1 |
| Staging access before Phase 9 (R-2) | Staging allow-listed (NSG) plus a staging-only Entra app registration for e2e | Gate 3 |
| Breaking-change check tool (BE-4.1) | Choose and licence-check during BE-4.1 | Phase 4 |
| Migration execution (B-7, infra ADR-0008) | Start-up Flyway until Phase 9, then PreSync Job | Phase 9 |

## 5. Risks

See PLAN-BACKEND §11 for the full list. The ones that drive this order:

- **R-2 (High/High):** staging e2e needs authentication before the Phase 9 IdP work. Decide the staging access
  model at Gate 3 at the latest.
- **R-1:** Boot 4.1 / Jackson 3 ecosystem gaps (springdoc). BE-2.3 de-risks before BE-3.05.
- **R-7:** Testcontainers ITs skipped without Docker. CI asserts the IT reports exist.
- **R-8:** over-engineering for one user. Gates and the PR-sized backlog keep scope tight.
