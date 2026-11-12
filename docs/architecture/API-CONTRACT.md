# API contract draft (atlas-backend)

- Status: **Draft / Proposed** (Phase 0). No business endpoints exist yet. Phase 1 serves only the
  actuator endpoints listed in [§12](#12-non-api-endpoints-phase-1-implemented).
- Decision record: [ADR-0006](../adr/0006-rest-api-openapi-problem-details.md) (REST + OpenAPI + Problem
  Details). Authentication: [ADR-0005](../adr/0005-authentication-provider-neutral-oidc.md).
- Source: `project-instruction.md` §3, §5, §7, §11.5–§11.6, §12.4, §13.4.
- The binding contract will be the generated OpenAPI document (Phase 3). This file explains the
  conventions and the planned endpoint families. Names may still change during Phase 3 review.

## 1. General conventions

| Topic | Convention |
|---|---|
| Base path | `/api/v1`. The edge proxy / ingress routes `/api/` to the backend and everything else to the frontend (same origin). |
| Format | `application/json` (UTF-8) for requests and responses; errors use `application/problem+json`. |
| JSON names | `camelCase` properties; enum values are `UPPER_SNAKE_CASE` strings; path segments are `kebab-case` plurals. |
| IDs | UUIDs (server-generated, UUIDv7 proposed; see PLAN-DATABASE) as strings. Clients never send `ownerId`. |
| Absent values | Optional properties are omitted or `null` in responses. In `PATCH`, an omitted property is unchanged and `null` clears it (JSON Merge Patch semantics, RFC 7396, `application/merge-patch+json` also accepted). |
| Unknown properties | Clients must ignore unknown response properties. The server rejects unknown request properties with `400` (catches typos and client drift early). |
| Date-only | ISO 8601 `YYYY-MM-DD` (`LocalDate`), e.g. due dates, valuation dates. |
| Planned dates with precision | `{ "date": "2027-07-01", "precision": "MONTH" }`; see [§5](#5-money-dates-and-units). |
| Instants | ISO 8601 UTC with `Z`, e.g. `"2026-11-12T09:30:00Z"` (`Instant`), for created/updated/completed timestamps and audit data. |
| Money | `{ "amount": "1000.00", "currency": "EUR" }` with `amount` as a **decimal string**; see [§5](#5-money-dates-and-units). |
| Timezone | The owner's IANA timezone (`Europe/Berlin`) is a profile preference. Date-only values are never shifted by timezone. "Today" is computed in the owner's timezone. |
| Authentication | From Phase 3: required for every `/api/**` request (BFF session cookie + CSRF header for web, `Authorization: Bearer` for native). `401` unauthenticated, `403` authenticated but missing scope. |
| Ownership | Every resource belongs to the authenticated owner. A resource of another owner returns `404` (no existence leak). |

## 2. UI vocabulary mapping

The UI uses the design vocabulary; the API, code and database keep the domain names (see `atlas`
ADR-0006, UI vocabulary & domain mapping).

| UI term (design) | API / domain term | API location |
|---|---|---|
| My Atlas | Dashboard | `GET /api/v1/dashboard` |
| Destination | `Goal` | `/api/v1/goals` |
| Waypoint | `GoalNode` with `nodeType = MILESTONE` (and `CHECKPOINT`) | `/api/v1/goals/{goalId}/nodes` |
| Step | `GoalNode` with `nodeType = TASK` | `/api/v1/goals/{goalId}/nodes` |
| Connection | `GoalLink` (between goals) and `GoalNodeDependency` (within a goal) | `/goals/{goalId}/links`, `/goals/{goalId}/dependencies` |
| Journey Overview | Timeline read model | `GET /api/v1/timeline` |
| Milestone Award | `GoalReward` (`PLANNED` / `EARNED` / `REDEEMED`) | `/goals/{goalId}/reward`, `/goals/{goalId}/nodes/{nodeId}/reward` |
| Life Dimension | Ikigai area | `/api/v1/ikigai/areas` |

Canonical Life Dimension keys (stable, never renamed; labels are user-editable): `CAREER`, `FINANCE`,
`HEALTH`, `LOVE`, `PASSION`, `FRIENDSHIP`, `FAMILY`.

## 3. HTTP semantics and status codes

| Operation | Success | Notes |
|---|---|---|
| `GET` single | `200` + `ETag` | `If-None-Match` → `304` (optional optimisation) |
| `GET` collection | `200` | Paginated envelope ([§6](#6-pagination-filtering-sorting)) |
| `POST` create | `201` + `Location` + `ETag` + body | `Idempotency-Key` where listed in [§8](#8-idempotency) |
| `POST` action (`/complete`, `/archive`, ...) | `200` + resulting resource | Actions are named verbs on a resource; a repeated action on a resource already in the target state returns `200` without side effects |
| `PUT` replace (singletons: profile, baseline, reward) | `200` + body | `If-Match` required once the resource exists |
| `PATCH` partial update | `200` + body | `If-Match` required |
| `DELETE` | `204` | `If-Match` required; semantics per resource are documented (archive vs permanent) |

Error status codes: `400` malformed/unknown input, `401`, `403`, `404` (also for other owners' data),
`405`, `409` state conflict (e.g. completing a locked node without override, circular dependency),
`412` stale `If-Match`, `415`, `422` semantically invalid request or idempotency-key reuse with a
different payload, `428` missing `If-Match`, `429` (later, rate limiting), `500` (no details),
`503` (not ready).

## 4. Errors: RFC 9457 Problem Details

Phase 1 already returns Problem Details for framework errors (`spring.mvc.problemdetails.enabled=true`;
verified by `AtlasApplicationIT`). Phase 3 adds one global `@RestControllerAdvice`.

```json
{
  "type": "urn:problem:atlas:validation-failed",
  "title": "Request validation failed",
  "status": 400,
  "detail": "2 fields are invalid.",
  "instance": "/api/v1/goals",
  "code": "VALIDATION_FAILED",
  "errors": [
    { "field": "title", "code": "NotBlank", "message": "must not be blank" },
    { "field": "targetDate.precision", "code": "InvalidEnum", "message": "must be one of DAY, MONTH, QUARTER, YEAR, APPROXIMATE" }
  ]
}
```

- `type` is a stable URI per error kind: `urn:problem:atlas:<kebab-case-code>` (open decision A-4). A
  resolvable documentation URL can replace it once a domain is decided. Changing `type` later is a
  breaking change, so decide before Phase 4.
- `code` is the stable machine-readable key the frontend switches on (`VALIDATION_FAILED`,
  `RESOURCE_NOT_FOUND`, `VERSION_CONFLICT`, `PRECONDITION_REQUIRED`, `NODE_LOCKED`,
  `DEPENDENCY_CYCLE`, `CROSS_GOAL_DEPENDENCY`, `INVALID_STATUS_TRANSITION`, `IDEMPOTENCY_KEY_REUSED`,
  `CURRENCY_MISMATCH`, ...).
- `detail` is a human-readable English message. User-facing text is localised in the frontend from
  `code`.
- Error bodies never contain stack traces, SQL, tokens, amounts, note text or other personal values.
  Server logs contain a correlation ID (`traceId`, from Micrometer tracing when added) that is also
  returned as the `traceId` extension member for `5xx`.

## 5. Money, dates and units

**Money** (§7.2, §7.3, §12.4):

```json
{ "amount": "1250.00", "currency": "EUR" }
```

- `amount` is a JSON **string** containing a plain decimal (`^-?\d{1,13}(\.\d{1,4})?$`; scale per
  currency, max 4). JSON numbers are rejected. This avoids binary floating-point rounding in
  JavaScript, and the UI must not do business arithmetic anyway. User-entered amounts (income,
  expenses, savings, impacts) must be ≥ 0; the direction comes from the category. Negative values
  appear only in calculated results (e.g. net monthly cash flow).
- `currency` is an ISO 4217 alphabetic code (`EUR`). Amounts in different currencies are never added
  without an explicit exchange rate and valuation date (no FX service in the MVP); such requests
  return `422 CURRENCY_MISMATCH`.
- Recurring amounts always carry `frequency` (`ONE_TIME`, `WEEKLY`, `MONTHLY`, `QUARTERLY`, `YEARLY`,
  `CUSTOM` + `schedule`) and `effectiveFrom`/`effectiveTo`. Income carries
  `basis`: `GROSS` | `NET` | `UNKNOWN` (never assumed).

**Dates:**

- Business deadlines are date-only (`LocalDate`). Events and audit data use `Instant`.
- Planned dates with precision (§3.5, §21.7). Proposed model, see PLAN-DATABASE D-3:

  ```json
  { "date": "2027-07-01", "precision": "MONTH" }
  ```

  `precision` ∈ `DAY`, `MONTH`, `QUARTER`, `YEAR`, `APPROXIMATE`. For `MONTH`/`QUARTER`/`YEAR` the
  server normalises `date` to the first day of the period. `APPROXIMATE` keeps the given date as a best
  estimate. "Season" is not in the MVP because it depends on the hemisphere.

**Units:** measurements are `{ "value": "72.5", "unit": "KG" }` (`KG`/`LB`, `CM`/`IN`); a raw number is
never interpreted without its unit.

## 6. Pagination, filtering, sorting

Every collection endpoint is paginated from the start (§11.5), even if data volumes are small.

- Request: `?page=0&size=20&sort=targetDate,asc&sort=title,asc` (0-based page; default `size=20`,
  max `100`; sort fields are an allow-list per endpoint, unknown fields → `400`).
- Response envelope (matches Spring Data's stable `PagedModel` DTO serialisation, so no custom
  envelope code is needed):

  ```json
  {
    "content": [ { "id": "…", "title": "…" } ],
    "page": { "size": 20, "number": 0, "totalElements": 1, "totalPages": 1 }
  }
  ```

- Filters are explicit, documented query parameters per endpoint (e.g. `status=ACTIVE&status=PAUSED`,
  `area=CAREER`, `q=master`, `targetFrom=2027-01-01&targetTo=2027-12-31`). Repeating a parameter means
  OR within that parameter; different parameters combine with AND. There is no generic query language.
- Small bounded sub-collections that are always shown completely (for example a goal's node tree or
  the seven areas) are returned unpaginated, and the document states it explicitly.

## 7. Optimistic locking

Every mutable aggregate has a `version` column (§11.5, §12.1). Two options were considered:

| Option | Pros | Cons |
|---|---|---|
| **A. `ETag` / `If-Match` (recommended)** | HTTP standard (RFC 9110); works for `PATCH`/`DELETE`/actions without a body; enables `304` caching; Spring has `ShallowEtagHeaderFilter` and `ResponseEntity.eTag()` support | Client must read the header (`HttpClient` `observe: 'response'`), plus a small amount of frontend plumbing |
| B. `version` field in request bodies | Simple for form-based clients | Non-standard; needs a body on `DELETE`/actions; easy to forget on new endpoints |

**Recommendation: A.** Responses carry a strong `ETag: "<version>"` and also include `version` as a
read-only property for display and debugging. `PUT`/`PATCH`/`DELETE` and state-changing actions on
versioned resources require `If-Match`:

- A missing header returns `428 PRECONDITION_REQUIRED`.
- A stale version returns `412 VERSION_CONFLICT` with the current `ETag`, so the client can reload and
  show a non-destructive conflict message.

There are no silent lost updates.

## 8. Idempotency

Retries happen (mobile networks, double taps). Operations that could duplicate a **financial impact**
or a **completion record** (§13.4) accept an `Idempotency-Key` header (client-generated UUID, proposed
per the IETF `Idempotency-Key` draft):

| Endpoint | Key |
|---|---|
| `POST /api/v1/finance/goal-impacts` | **required** |
| `POST /api/v1/finance/goal-impacts/{impactId}/realize` | **required** |
| `POST /api/v1/goals` | optional (avoids duplicate goals on retry) |
| `POST /api/v1/goals/{goalId}/nodes/{nodeId}/complete` | optional; the action is also state-idempotent (completing a completed node is a no-op `200`) |

Server behaviour:

- Keys are stored per owner and endpoint with a request hash and the original response, in the owning
  module's table, for 24 hours.
- The same key with the same payload replays the original status and body.
- The same key with a different payload returns `422 IDEMPOTENCY_KEY_REUSED`.
- A request still in progress with the same key returns `409`.

## 9. Planned endpoint families

Phase = implementation phase from `project-instruction.md` §18. Sketches show the main fields only; the
OpenAPI document is authoritative once generated.

### 9.1 Dashboard (Phase 3, step 7)

`GET /api/v1/dashboard`: read-only view model ("My Atlas"):

```json
{
  "today": "2026-11-12",
  "focus": { "goalId": "…", "nodeId": "…", "title": "…", "reason": "NEXT_AVAILABLE_NODE" },
  "lifeBalance": [ { "areaKey": "CAREER", "label": "Career / Profession", "activeGoals": 2 } ],
  "activeGoals": [ { "id": "…", "title": "…", "primaryAreaKey": "CAREER", "progress": { "percent": "42.5" },
                     "nextNode": { "id": "…", "title": "…" }, "targetDate": { "date": "2027-07-01", "precision": "MONTH" },
                     "reward": { "description": "…", "status": "PLANNED" } } ],
  "upcomingDeadlines": [ { "goalId": "…", "nodeId": "…", "title": "…", "dueDate": { "date": "2026-12-01", "precision": "DAY" } } ],
  "moneySnapshot": null,
  "timeCapacity": null,
  "recentAchievements": [ { "goalId": "…", "nodeId": "…", "title": "…", "completedAt": "2026-11-10T18:00:00Z" } ]
}
```

`moneySnapshot` and `timeCapacity` are `null` until Phase 6. `?horizonDays=30` sets the deadline horizon.

### 9.2 Profile (Phase 3, step 1)

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/profile` | Profile + preferences + optional personal context |
| `PUT` | `/api/v1/profile` | Replace (requires `If-Match`) |

```json
{
  "displayName": "…",
  "preferences": { "locale": "de-DE", "timezone": "Europe/Berlin", "currency": "EUR",
                   "weekStart": "MONDAY", "measurementSystem": "METRIC", "theme": "SYSTEM" },
  "personalContext": { "height": { "value": "180", "unit": "CM" }, "weight": null, "relationshipStatus": null },
  "version": 3
}
```

`personalContext` fields are optional, and each one is explained in the UI (§6.1). Account export and
deletion (`GET /api/v1/account/export`, `DELETE /api/v1/account`) follow in Phase 9 (§12.5).

### 9.3 Onboarding (Phase 3, step 1)

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/onboarding` | `{ "status": "IN_PROGRESS", "steps": [ { "key": "preferences", "status": "COMPLETED" }, … ], "completedAt": null }` |
| `PUT` | `/api/v1/onboarding/steps/{stepKey}` | Save one step. The payload is delegated to the owning module (profile/finance); the step can be `SKIPPED` |
| `POST` | `/api/v1/onboarding/complete` | Mark complete (allowed with skipped optional steps) |
| `POST` | `/api/v1/onboarding/reopen` | Reopen from Settings |

Step keys (proposed, align with PLAN-FRONTEND): `preferences`, `personal-context`, `financial-baseline`.

### 9.4 Ikigai / Life Dimensions (Phase 3, step 2)

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/ikigai/areas` | The 7 areas (unpaginated, bounded) with owner settings |
| `PATCH` | `/api/v1/ikigai/areas/{areaKey}` | Rename label, recolour (`colorToken` from design tokens), reorder, hide |

```json
{ "key": "CAREER", "label": "Career / Profession", "colorToken": "area-career", "sortOrder": 1, "hidden": false, "version": 0 }
```

### 9.5 Goals (Phase 3, steps 2–6)

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v1/goals` | Create (only `title` required, §3.5) |
| `GET` | `/api/v1/goals` | List; filters `status`, `area`, `q`, `targetFrom`, `targetTo`; sort `targetDate`, `priority`, `title`, `createdAt`, `updatedAt` |
| `GET` | `/api/v1/goals/{goalId}` | Detail incl. progress summary |
| `PATCH` | `/api/v1/goals/{goalId}` | Partial update (incl. status `DRAFT`/`ACTIVE`/`PAUSED`) |
| `POST` | `/api/v1/goals/{goalId}/archive`, `/restore` | Archive / restore (history preserved) |
| `DELETE` | `/api/v1/goals/{goalId}` | **Permanent** deletion of the goal and its subtree (proposed; see open decision A-1) |
| `GET` | `/api/v1/goals/{goalId}/progress` | Progress explanation (policy, weights, counted/excluded nodes) |
| `GET` | `/api/v1/goals/{goalId}/history` | Change log (paginated) |
| `GET`/`POST` | `/api/v1/goals/{goalId}/links` | Typed goal links (`SUPPORTS`, `DEPENDS_ON`, `CONFLICTS_WITH`, `AFFECTS`, `RELATED_TO`) |
| `DELETE` | `/api/v1/goals/{goalId}/links/{linkId}` | Remove link |

Goal (create request → response):

```json
{
  "title": "Master's degree",
  "outcome": "…", "description": "…",
  "primaryAreaKey": "CAREER", "secondaryAreas": [ { "areaKey": "FINANCE", "weight": "0.3" } ],
  "priority": "HIGH",
  "status": "ACTIVE",
  "startDate": { "date": "2027-01-01", "precision": "MONTH" },
  "targetDate": { "date": "2029-07-01", "precision": "QUARTER" },
  "expectedWeeklyEffortMinutes": 600,
  "progressPolicy": "DERIVED"
}
```

The response adds `id`, `progress`
(`{ "percent": "42.5", "policy": "DERIVED", "countedWeight": "17", "totalWeight": "40" }`),
`nextAvailableNode`, `reward`, `createdAt`, `updatedAt`, `version`. `priority` ∈ `LOW`/`MEDIUM`/`HIGH`
is proposed (scale to confirm with design). `progress.percent` is a decimal string with one decimal
place.

### 9.6 Goal nodes, dependencies, notes, rewards (Phase 3, steps 3–6)

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v1/goals/{goalId}/nodes` | Create node (`parentId` optional = top level) |
| `GET` | `/api/v1/goals/{goalId}/tree` | Whole goal tree (unpaginated, bounded by a max node count per goal) |
| `GET` | `/api/v1/goals/{goalId}/nodes/{nodeId}` | Node detail |
| `PATCH` | `/api/v1/goals/{goalId}/nodes/{nodeId}` | Partial update, incl. `status` (`NOT_STARTED`, `IN_PROGRESS`, `SKIPPED`, `CANCELLED`), `parentId`/`sortOrder` (move) |
| `DELETE` | `/api/v1/goals/{goalId}/nodes/{nodeId}` | Delete node and subtree (`?cascade=true` required when it has children) |
| `POST` | `/api/v1/goals/{goalId}/nodes/{nodeId}/complete` | Complete (`409 NODE_LOCKED` if locked and not overridden); earns reward, recalculates unlocks |
| `POST` | `/api/v1/goals/{goalId}/nodes/{nodeId}/reopen` | Reopen a completed node |
| `GET` | `/api/v1/goals/{goalId}/nodes/{nodeId}/tree` | Focus view: node, breadcrumbs, direct children, descendant progress, lock reasons |
| `GET`/`POST` | `/api/v1/goals/{goalId}/dependencies` | List/add (`prerequisiteNodeId`, `dependentNodeId`); same goal only, no cycles (`409 DEPENDENCY_CYCLE`) |
| `DELETE` | `/api/v1/goals/{goalId}/dependencies/{dependencyId}` | Remove |
| `PATCH` | `/api/v1/goals/{goalId}/nodes/{nodeId}/unlock-condition` | `ALL` (default) or `ANY` prerequisites |
| `POST`/`DELETE` | `/api/v1/goals/{goalId}/nodes/{nodeId}/lock-override` | Manual override with mandatory `reason` (audited) |
| `GET`/`POST` | `/api/v1/goals/{goalId}/notes` | Notes on the goal or a node (`?nodeId=`); Markdown stored as text and sanitised when rendered |
| `PATCH`/`DELETE` | `/api/v1/goals/{goalId}/notes/{noteId}` | Edit/delete note |
| `PUT`/`DELETE` | `/api/v1/goals/{goalId}/reward`, `/api/v1/goals/{goalId}/nodes/{nodeId}/reward` | Set/remove reward (one per goal/node) |
| `POST` | `…/reward/redeem` | Mark an `EARNED` reward as `REDEEMED` |

Node response sketch:

```json
{
  "id": "…", "goalId": "…", "parentId": null, "nodeType": "MILESTONE",
  "title": "Semester 1", "outcome": "…", "description": "…",
  "status": "IN_PROGRESS",
  "startDate": { "date": "2027-01-01", "precision": "MONTH" },
  "dueDate": { "date": "2027-06-30", "precision": "DAY" },
  "effortEstimateMinutes": 6000, "progressWeight": "1", "sortOrder": 0,
  "availability": { "state": "LOCKED", "reasons": [ { "prerequisiteNodeId": "…", "title": "Admission", "status": "IN_PROGRESS" } ],
                    "override": null },
  "progress": { "percent": "25.0", "policy": "DERIVED" },
  "reward": { "description": "Weekend trip", "status": "PLANNED" },
  "childCount": 4, "version": 7
}
```

`availability.state` (`AVAILABLE`, `LOCKED`, `OVERRIDDEN`) is **derived** from dependencies and never
stored as a work status (§5.3).

### 9.7 Timeline / Journey Overview (Phase 5; read model built in Phase 3)

`GET /api/v1/timeline?from=2026-01-01&to=2028-12-31&goalId=…&nodeType=MILESTONE`: flat list of dated
goals/nodes with precision, status, area and parent references for `vis-timeline`/calendar views.

### 9.8 Finance (Phase 6; reviewed in Phase 3 planning)

| Method | Path | Purpose |
|---|---|---|
| `GET`/`PUT` | `/api/v1/finance/baseline` | Actual baseline: income sources, recurring expenses, saving positions (each with money, frequency, effective dates, category) |
| `POST` | `/api/v1/finance/goal-impacts` | Create planned impact (`Idempotency-Key` required) |
| `GET` | `/api/v1/finance/goal-impacts` | List; filters `goalId`, `state`, `category` |
| `PATCH`/`DELETE` | `/api/v1/finance/goal-impacts/{impactId}` | Edit/remove planned impact |
| `POST` | `/api/v1/finance/goal-impacts/{impactId}/realize` | Confirm the impact became real: creates/links the actual baseline item and prevents double counting (`Idempotency-Key` required) |
| `GET`/`POST` | `/api/v1/finance/scenarios` | Named scenarios (selected impacts + assumption notes) |
| `GET` | `/api/v1/finance/projections?scenarioId=…&from=2027-01&months=24` | Deterministic monthly projection with inputs, period and assumption set (§7.3) |

Impact sketch:

```json
{
  "goalId": "…", "category": "ONE_TIME_COST",
  "money": { "amount": "1000.00", "currency": "EUR" },
  "frequency": "CUSTOM", "schedule": [ { "date": "2027-03-01", "money": { "amount": "200.00", "currency": "EUR" } } ],
  "effectiveFrom": { "date": "2027-01-01", "precision": "MONTH" }, "effectiveTo": null,
  "state": "PLANNED", "confidence": null, "notes": "…"
}
```

`category` ∈ `INCOME`, `EXPENSE`, `SAVINGS`, `ASSET`, `LIABILITY`, `DEBT_SERVICE`, `ONE_TIME_COST`.
`state` ∈ `PLANNED`, `SCENARIO`, `COMMITTED`, `REALIZED`. `confidence` is optional:
`{ "low": Money, "high": Money }` in the same currency with `low ≤ amount ≤ high` (PLAN-DATABASE §6.3).
Schedule items must use the impact's currency and are only allowed with `frequency = CUSTOM`.

### 9.9 Capacity (Phase 6)

| Method | Path | Purpose |
|---|---|---|
| `GET`/`PUT` | `/api/v1/capacity/availability` | Available hours per weekday or weekly total |
| `GET`/`POST`/`PATCH`/`DELETE` | `/api/v1/capacity/commitments[/{id}]` | Recurring/one-time personal commitments (optional) |
| `GET`/`PUT` | `/api/v1/capacity/plans/{goalId}` | Planned weekly hours for a goal/node and period |
| `GET` | `/api/v1/capacity/summary?weekOf=2026-11-09` | Planned vs available hours and explainable conflicts; nothing is auto-rescheduled |

### 9.10 Later families (not planned in detail yet)

`/api/v1/exports` (Phase 7), domain extensions such as `/api/v1/career/...` (Phase 8), `/api/v1/account`
(export/delete, Phase 9), `/api/v1/ai/suggestions` (Phase 11; dry-run, review, apply through normal use
cases).

## 10. Versioning and compatibility

- **Compatible (stays `v1`):** new endpoints; new optional request properties; new response properties;
  new enum values, only if the enum is documented as extensible. Clients must treat unknown values as
  "other".
- **Breaking:**
  - removing or renaming a property or endpoint;
  - changing a type, format or meaning;
  - making optional input required;
  - tightening validation of previously accepted input;
  - changing error `code` values.
- A breaking change needs either `/api/v2` for the affected resources (v1 kept until no supported
  client uses it; installed mobile apps count) or an expand/contract plan documented in the PR. Both
  require the OpenAPI snapshot diff to be reviewed.
- Deprecation: mark it in OpenAPI (`deprecated: true`), send `Deprecation`/`Sunset` response headers,
  and record it in this document.

## 11. OpenAPI generation (Proposed, Phase 3)

- Code-first with springdoc-openapi (`springdoc-openapi-starter-webmvc-api`). Latest release on Maven
  Central on 2026-11-12: **3.2.0**, built against Spring Boot 4.1.2, Apache-2.0. **Re-verify the
  version and compatibility when adding it; it is deliberately not part of Phase 1.**
- An integration test fetches `/v3/api-docs` and writes `target/openapi/openapi.json`. A committed
  snapshot `docs/api/openapi.json` must match it (the test fails with a diff otherwise), so every
  contract change is visible in review.
- CI uploads the document as an artifact. `openapi-publish.yml` (Phase 4) publishes versioned
  documents and runs a breaking-change check (tool to be selected and license-checked).
- `/v3/api-docs` is enabled for `local`/`dev` only. There is no Swagger UI in staging/prod.
- The frontend (`atlas`) generates TypeScript types/client from the published document; drift checks
  live in its CI.

## 12. Non-API endpoints (Phase 1, implemented)

| Path | Response | Use |
|---|---|---|
| `GET /actuator/health` | `200 {"status":"UP","groups":["liveness","readiness"]}` (no details) | Container health check |
| `GET /actuator/health/liveness` | `200 {"status":"UP"}` | Kubernetes liveness probe |
| `GET /actuator/health/readiness` | `200 {"status":"UP"}` (`503` when not ready, e.g. during shutdown) | Kubernetes readiness/startup probe |
| `GET /actuator/info` | build info (artifact, version, name, group) | Diagnostics |

All other actuator endpoints return `404`. When Spring Security is added, these four stay public.
Everything else is authenticated.

## 13. CORS

- Web (production and the local full stack) is same-origin behind the edge proxy/ingress, so no CORS
  configuration is needed.
- The Angular dev server proxies `/api` to `http://localhost:8080`, so no CORS is needed there either.
- Capacitor apps run in a WebView with their own origin (`capacitor://localhost` on iOS,
  `https://localhost` on Android by default; to verify for Capacitor 8). Either an explicit CORS
  allow-list for exactly those origins (bearer tokens, no cookies) or the native HTTP plugin is needed.
  This is decided in Phase 10 together with the `atlas` mobile auth decision (ADR-0005).

## 14. Open decisions (API)

| ID | Decision | Recommended default | Trade-offs |
|---|---|---|---|
| A-1 | `DELETE /goals/{id}`: archive or permanent? | Explicit `archive`/`restore` actions, and `DELETE` = permanent deletion (with `If-Match`; UI confirms) | Matches acceptance criterion "archive and delete" (§20.3) and data minimisation. Mistakes are irreversible, so the UI needs a confirmation step. |
| A-2 | Optimistic locking style | `ETag`/`If-Match` (§7) | Standard, works without bodies; slightly more client plumbing than a body `version`. |
| A-3 | Money `amount` as string or number | String | Exact decimal; clients must parse for display (Angular `Intl.NumberFormat` handles strings). |
| A-4 | Problem `type` URI base | `urn:problem:atlas:<kebab-case-code>` until a domain is decided | A resolvable URL could host documentation but needs a domain. |
| A-5 | Pagination envelope | Spring Data `PagedModel` shape (`content` + `page`) | No custom code; tied to a framework convention (stable since Spring Data 3.3). |
| A-6 | OpenAPI approach | Code-first + committed snapshot (ADR-0006) | Simple for one developer; contract-first would give stricter review but more tooling. |
