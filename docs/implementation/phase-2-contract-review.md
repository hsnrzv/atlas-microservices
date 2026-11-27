# Phase 2 — Contract alignment review

- Date: 2026-11-27
- Status: **Confirmed by the owner (@hsnrzv) on 2026-11-27**, including the ADRs, B/D decisions, A-1…A-6 and
  the FQ answers.
- Scope: roadmap items BE-2.1, BE-2.2 (preparation), BE-2.3, DB-2.1 (preparation), DB-2.2. No feature code.
- Inputs:
  - `atlas` `origin/main` at `5807475`: `docs/architecture/frontend.md` §6.5 (FQ-1…FQ-22), `src/app/core/models/*`,
    `src/app/core/data-access/ports/*` and `src/app/core/data-access/http/*` (the delivered HTTP adapters);
  - [API-CONTRACT](../architecture/API-CONTRACT.md), [ADR-0004](../adr/0004-database-schema-strategy.md),
    [ADR-0005](../adr/0005-authentication-provider-neutral-oidc.md),
    [ADR-0006](../adr/0006-rest-api-openapi-problem-details.md), [PLAN-BACKEND](../plan/PLAN-BACKEND.md) §13,
    [PLAN-DATABASE](../plan/PLAN-DATABASE.md) §8 and §12.
- Result: the contract changes below are applied to API-CONTRACT, DOMAIN-MODULES and PLAN-DATABASE in the same PR.
  The owner accepted ADR-0004/0005/0006 on 2026-11-27 (§5). The frontend changes this review requires are listed
  in §6.

## 1. API decisions A-1…A-6

All six recommended defaults are adopted; none of the frontend adapters contradicts them. API-CONTRACT §14 records
them as resolved. The owner can still reopen one in review of this PR; after Phase 4 each is a breaking change.

| ID | Resolution | Evidence from the frontend adapters |
|---|---|---|
| A-1 | `DELETE /goals/{id}` is permanent; `archive`/`restore` are separate actions. ADR-0006 wording fixed ("archives unless documented otherwise" contradicted A-1) | `remove()` and `archive()` are separate port methods; the UI confirms deletion |
| A-2 | `ETag`/`If-Match` | `atlas-api.ts` sends `If-Match` from the resource's `version` and maps `412`/`428` |
| A-3 | Money `amount` is a decimal string | `Money.amount: string`; also used for `percent`, `progressWeight` and area `weight` |
| A-4 | `type` = `urn:problem:atlas:<kebab-case-code>`; the frontend switches on `code`, never on `type` | `problem-details.ts` reads `code` and `errors[]` only |
| A-5 | Spring Data `PagedModel` envelope | `getAll()` follows `page.totalPages`; it also accepts a plain array, which the bounded sub-collections use (§2, FQ-21) |
| A-6 | Code-first with springdoc and a committed snapshot; BE-2.3 confirms that springdoc 3.2.1 works on Boot 4.2 (§4) | The frontend generates types from the snapshot in F3-5/F4-1 |

## 2. Frontend questions FQ-1…FQ-22

"Accepted" means the backend implements the field or endpoint in the phase given, in the shape the frontend
proposed unless the answer says otherwise. "Changed" means accepted with a different shape, so the frontend adapts.

| ID | Decision | Phase | Answer |
|---|---|---|---|
| FQ-1 | Accepted | 3 (step 7) | `activeGoals[].nextNode` = `{ id, title, nodeType, status, availability: { state }, dueDate, progress }`; `progress` is `null` when the node has nothing to measure |
| FQ-2 | Accepted | 3 (step 7) | `lifeBalance[].progress`: weighted average of the area's active goals (primary assignment weight 1, secondary assignments their `weight`, default 1); `null` when the area has no active goal with measurable progress |
| FQ-3 | Accepted | 3 (step 7) | `summary { activeGoals, achievedWaypoints }` and `activeGoals[].achievedWaypoints`. "Achieved Waypoint" = node with `nodeType` `MILESTONE` or `CHECKPOINT` and status `COMPLETED` |
| FQ-4 | Accepted | 3 (step 7) | `inProgress[]` = Steps (`TASK`) with status `IN_PROGRESS` of active goals, ordered by `updatedAt` descending, at most 10; `recentAchievements[].nodeType` added |
| FQ-5 | Accepted | 3 (step 4) | `progress.excludedNodes[] { nodeId, title }` lists the skipped and cancelled nodes (PLAN-DATABASE §8.1 rules 3–4); it appears wherever `progress` carries the explanation fields |
| FQ-6 | Accepted | 3 (step 7) | `activeGoals[].keyDates[] { nodeId, title, date }`: the goal's open top-level Waypoints in tree order, at most 5; `date` is the node's `dueDate` or `null` |
| FQ-7 | Rejected | — | An application date is modelled as a Waypoint (for example "Submit application") with a `dueDate`, not as a goal field. The form keeps it out; the sample can add the Waypoint |
| FQ-8 | Accepted | 3 (step 2) | Archived goals have `status: "ARCHIVED"`. `GET /goals` excludes `ARCHIVED` unless `status=ARCHIVED` is requested; `restore` returns the goal to `status_before_archive`. Goal status values are `DRAFT`, `ACTIVE`, `PAUSED`, `COMPLETED`, `ARCHIVED`; only the first three can be set with `PATCH` |
| FQ-9 | Accepted | 3 (step 6) | Note text is `body` (≤ 20,000 characters, PLAN-DATABASE §6.2) with `format`: `PLAIN` (default) or `MARKDOWN`. The frontend renders `PLAIN` only (D13) |
| FQ-10 | Changed | 3 (step 4) | `reopen` sets a `COMPLETED` node to `IN_PROGRESS` (no previous-status column). An `EARNED` reward of that node returns to `PLANNED`; a `REDEEMED` reward stays `REDEEMED` |
| FQ-11 | Deferred | after MVP | No node priority. Goals have `priority` (`LOW`/`MEDIUM`/`HIGH`, DB-2.2) |
| FQ-12 | Accepted | 3 (step 4) | `achievedWaypoints` (count, FQ-3 definition) on the goal detail and the goal list summary |
| FQ-13 | Accepted | 3 (step 6) | `noteCount` on every node of `GET /goals/{goalId}/tree` (one grouped query) |
| FQ-14 | Accepted | 5 | Timeline items carry `date: null` when undated and their `progress` (`null` for nothing to measure). `from`/`to` filter dated items only; undated items of the selected goals are always returned. The response is `{ "items": [...] }`, unpaginated (bounded by B-12 per goal) |
| FQ-15 | Deferred | 6 | `GET /connections` needs finance impacts (`POSSIBLE_IMPACT`). The proposed `GoalConnection` model is the starting point for the Phase 6 contract; `ASSOCIATION` entries can come from `goal_ikigai_area` earlier if Phase 5 needs them. Rule kept: no amount without a confirmed source |
| FQ-16 | Accepted | 5 | `GET /rewards` returns the proposed `Awards` model (`summary`, `rewards[]`, `achievedWaypoints[]`), unpaginated in `v1` (one owner's rewards; revisit if a list exceeds 500 entries) |
| FQ-17 | Accepted | 3 (step 1) | Step key `areas`; `PUT /onboarding/steps/areas` with `{ status, payload: { areaKeys } \| null }`. The payload sets the owner's focus Life Dimensions (new `ikigai_area.focused` flag); `onboarding` may now call `ikigai` (DOMAIN-MODULES updated). Ikigai area responses gain `focused` |
| FQ-18 | Accepted | 3 (step 4) | A Waypoint with counted Steps follows them, as the mock does: all counted Steps completed → `COMPLETED` (earns its reward); any started → `IN_PROGRESS`; none started → stored status, but a no-longer-complete Waypoint returns to `NOT_STARTED`. Skipped and cancelled Waypoints keep their status. Derived in the write transaction, recorded as a system change |
| FQ-19 | Deferred | after MVP | No intention entity. "Add intention" keeps opening the goal form for the dimension |
| FQ-20 | Accepted | 3 (step 2) | `weight` is optional, a decimal string with up to 3 decimals, `0 < weight ≤ 1` (`NUMERIC(4,3)`); out of range → `400 VALIDATION_FAILED` with field code `Range`. `GET /connections` returns it when that endpoint exists (FQ-15) |
| FQ-21 | Changed | 3 | See the table below. Correlation: no custom request header; the backend accepts W3C `traceparent` once tracing is added and returns `traceId` on `5xx` |
| FQ-22 | Deferred | 9 | The BFF lands with ADR-0005 in Phase 9. The frontend's assumptions are compatible and become the starting proposal: `GET /api/v1/me` → `200 { displayName }` or `401`; sign-in `GET /api/auth/login` (optional relative `returnTo`, validated against an allow-list); sign-out `POST /api/auth/logout` with CSRF; the `XSRF-TOKEN` cookie is set on the first response of a session |

FQ-21 — preconditions and bodies of the sub-resources:

| Resource | Precondition | Notes |
|---|---|---|
| Goal (`PATCH`, `DELETE`, `archive`, `restore`) | `If-Match` with the goal `ETag` | Structural changes (node create/move/delete, dependency add/remove, reward set/remove) also increment the goal version, so a goal `ETag` held across them is stale (`412`) |
| Node (`PATCH`, `DELETE`, `complete`, `reopen`) | `If-Match` with the node `ETag` | Node create sends none (it is a create); `complete` also takes `Idempotency-Key` |
| Goal reward (`PUT`, `DELETE`, `redeem`) | `If-Match` with the goal `ETag` | The reward is part of the goal aggregate and has no own version — matches the adapter |
| Node reward (`PUT`, `DELETE`, `redeem`) | `If-Match` with the node `ETag` | Same rule for the node level |
| Dependency (`POST`, `DELETE`) | none | Insert-or-delete only (no update). The server serialises writes per goal and checks cycles; the list is unpaginated (a plain JSON array, bounded by B-12) |
| Note (`PATCH`, `DELETE`) | `If-Match` with the note `ETag` | **Change:** notes get `version`. `POST` sends none. `GET …/notes` is paginated; without `nodeId` it returns all notes of the goal, with `nodeId` only that node's notes (server-side filter) |
| Onboarding step (`PUT`) | none | Idempotent upsert of the step state; the payload is applied by the owning module as a whole-value replace. Documented exception to API-CONTRACT §3 |

Other alignment points found in the review:

- Goal progress may be `null` (PLAN-DATABASE §8.1 rule 5: nothing to measure). The backend does not invent `0 %`.
  `DashboardGoal.progress` in the frontend is non-null and must become `Progress | null` (§6).
- `GoalStatus` in the frontend lacks `COMPLETED` and `ARCHIVED` (FQ-8).
- Error codes the frontend handles but the catalogue lacked: `NODE_HAS_CHILDREN` (`409`, delete without
  `cascade=true`) and `REWARD_NOT_EARNED` (`409`, redeem of a reward that is not `EARNED`). Both are added to
  API-CONTRACT §4 with the other codes (`UNAUTHENTICATED`, `FORBIDDEN`, `GOAL_TOO_LARGE`, ...).
- Field-violation codes are the Jakarta constraint names (`NotBlank`, `NotNull`, `NotEmpty`, `Size`, `Range`,
  `Pattern`) plus `InvalidEnum`, `InvalidFormat` and `Unknown` (unknown property). The frontend maps unknown codes
  to a generic message, so the list can grow.
- The backend never returns `410`; the frontend's mapping of `410` to not-found is harmless.
- `primaryAreaKey` is always sent by the goal form. The contract keeps it optional (only `title` is required, §3.5),
  so the form's choice does not constrain other clients.
- The frontend's references to "API-CONTRACT §5/§6" for pagination and `If-Match` mean §6 and §7 (§6).

## 3. Enum value lists (DB-2.2)

| Enum | Values | Extensible? | Note |
|---|---|---|---|
| Goal priority | `LOW`, `MEDIUM`, `HIGH` | no | Matches `GoalPriority` in `atlas`; `null` = not set |
| Goal status | `DRAFT`, `ACTIVE`, `PAUSED`, `COMPLETED`, `ARCHIVED` | no | FQ-8 |
| Node type | `MILESTONE`, `CHECKPOINT`, `TASK` | yes | UI: Waypoint = `MILESTONE`/`CHECKPOINT`, Step = `TASK` |
| Node status | `NOT_STARTED`, `IN_PROGRESS`, `COMPLETED`, `SKIPPED`, `CANCELLED` | no | |
| Reward status | `PLANNED`, `EARNED`, `REDEEMED` | no | |
| Onboarding status | `NOT_STARTED`, `IN_PROGRESS`, `COMPLETED` | no | |
| Onboarding step status | `NOT_STARTED`, `COMPLETED`, `SKIPPED` | no | The frontend has no `IN_PROGRESS` per step; neither does `onboarding_step` |
| Onboarding step keys | `areas`, `preferences`, `personal-context`, `financial-baseline` | yes | `financial-baseline` is optional and "available later" until Phase 6 (B-10) |
| Relationship status | `SINGLE`, `IN_RELATIONSHIP`, `MARRIED_OR_CIVIL_PARTNERSHIP`, `SEPARATED_OR_DIVORCED`, `WIDOWED`, `OTHER` | yes | Neutral; `null` = not given (the UI offers "prefer not to say" as `null`). Optional field (§6.1) |
| Expense categories | — | — | Deferred to the Phase 6 finance contract (needs the finance design pages) |

## 4. Spike BE-2.3: springdoc 3.x and JWT audiences

Throwaway branch `spike/be-2.3-springdoc-jwt`, run on 2026-11-27 with JDK 25 and Docker, then deleted (not merged).
It added `springdoc-openapi-starter-webmvc-api` 3.2.1, `spring-boot-starter-security-oauth2-resource-server` and
`spring-security-test`, a sample controller with `Money`/`PlannedDate` records, a stateless security filter chain and
a Testcontainers integration test.

Resolved versions: Spring Boot 4.2.0, springdoc 3.2.1 (latest on Maven Central on 2026-11-27), swagger-core 3.0.0,
Jackson 3.1.8 (`tools.jackson`; annotations `com.fasterxml.jackson.annotation` 2.21), Spring Security 7.2.0,
Nimbus JOSE + JWT 10.9.1. All Apache-2.0. No Jackson 2 `databind` on the classpath.

| # | Finding | Consequence for Phase 3 |
|---|---|---|
| S-1 | springdoc 3.2.1 starts on Boot 4.2.0 / Jackson 3 and serves `/v3/api-docs` as OpenAPI **3.1.0** | ADR-0006 point 5 holds; use 3.2.1 or later in BE-3.05 |
| S-2 | Records, `UUID`, `LocalDate` (`format: date`), `Instant` (`format: date-time`) and enums (`enum` list) are described correctly | No custom schema code for these |
| S-3 | **`BigDecimal` with `@JsonFormat(shape = STRING)` is documented as `type: number`**, although Jackson 3 serialises `"1200.50"` | BE-3.05 replaces the `BigDecimal` schema globally (`SpringDocUtils.getConfig().replaceWithSchema(BigDecimal.class, StringSchema...)`) and the snapshot test asserts `Money.amount.type = string`; BE-3.01 serialises `BigDecimal` as a string globally |
| S-4 | The default document contains `servers: [{ url: "http://localhost:<random port>" }]`, title "OpenAPI definition" and response content `*/*` | BE-3.05 sets an `OpenAPI` bean (title, version, `servers: [{ url: "/" }]`) and `springdoc.default-produces-media-type=application/json`; otherwise the snapshot is not reproducible |
| S-5 | Record components are not marked `required`; the `ETag` header and the security scheme are not documented by default | BE-3.05 adds `@Schema(requiredMode = REQUIRED)` (or a customiser) for non-null fields, a bearer security scheme and the `ETag`/`If-Match` headers through an operation customiser |
| S-6 | `spring.security.oauth2.resourceserver.jwt.audiences` works with `public-key-location`: a token with the right `aud` → `200`; wrong `aud` → `401`; no token → `401` | ADR-0005 needs no custom audience validator; the property is enough. Issuer validation comes from `issuer-uri` |
| S-7 | Once the resource-server starter is on the classpath, the context fails to start without a `JwtDecoder` (no issuer/key configured) | BE-3.03 must configure the tests (the existing `AtlasApplicationIT` failed in the spike) and the `local` identity (B-2) before the starter is merged |
| S-8 | Spring Security's `401` has an empty body and `WWW-Authenticate: Bearer resource_metadata="…/.well-known/oauth-protected-resource"` (RFC 9728, new in Security 7) | BE-3.03 adds an authentication entry point and access-denied handler that return Problem Details (`UNAUTHENTICATED`, `FORBIDDEN`). Unknown `/api/**` paths return `401` before `404` for anonymous callers, so `AtlasApplicationIT.unknownApiPathsReturnProblemDetails` must authenticate. Decide in BE-3.03 whether to expose the protected-resource metadata |

## 5. Owner review package (BE-2.2, DB-2.1)

The owner accepts or revises these; this review does not change their status. Recommendation for each: accept as
written, with the amendments made in this PR.

| Item | Recommendation | Amendment in this PR |
|---|---|---|
| ADR-0004 schema strategy (D-1) | Accept | — |
| ADR-0005 authentication | Accept | Spike S-6…S-8 recorded; the audience is validated through the Boot property, not a custom validator |
| ADR-0006 REST/OpenAPI/Problem Details | Accept | `DELETE` wording aligned with A-1; spike S-1…S-5 recorded; springdoc 3.2.1 |
| B-3 `goals` owns `goal_ikigai_area` | Accept | — |
| B-6 code-first OpenAPI | Accept | Confirmed by the spike (= A-6) |
| B-10 optional `financial-baseline` until Phase 6 | Accept | Step key list now also contains `areas` (FQ-17) |
| B-1, B-2, B-4, B-5, B-7…B-9, B-11…B-13 | Keep the recommended defaults; each is decided at the time given in PLAN-BACKEND §13 | — |
| D-1…D-9 | Accept the recommended defaults | D-2 extended by the Waypoint status rule (FQ-18); D-2 rule 5 (`null` progress) confirmed |

Owner checklist (tick in the PR or a follow-up):

- [x] ADR-0004 → Accepted (owner, 2026-11-27; covers D-1)
- [x] ADR-0005 → Accepted (owner, 2026-11-27)
- [x] ADR-0006 → Accepted (owner, 2026-11-27; covers B-6/A-6)
- [x] B-3, B-10 confirmed (owner, 2026-11-27; B-6 accepted with ADR-0006)
- [x] D-2…D-9 confirmed (owner, 2026-11-27; D-1 accepted with ADR-0004) (PLAN-DATABASE §12)
- [x] A-1…A-6 and the FQ answers in §2 confirmed (owner, 2026-11-27)

## 6. Follow-ups in other repositories

`atlas` (frontend), before or with F4-1:

- Mirror the FQ answers in `docs/architecture/frontend.md` §6.5 and remove the "Proposed" markers of the accepted
  fields; drop the FQ-7 field idea; keep FQ-11/FQ-19 UI elements out.
- `DashboardGoal.progress` → `Progress | null`; `GoalStatus` gains `COMPLETED` and `ARCHIVED`.
- Reopen (FQ-10): expect `IN_PROGRESS`; the mock should do the same.
- Notes: add `version` to `GoalNote` and send `If-Match` on `PATCH`/`DELETE`; filter by `nodeId` on the server.
- Node rewards: send `If-Match` with the node version; goal rewards keep the goal version.
- Ikigai area model: add `focused` (FQ-17).
- Fix the section references "API-CONTRACT §5/§6" → §6 (pagination) and §7 (`If-Match`).

`atlas-infra`: BE-2.4 stays blocked until ADR-0007 is accepted.
