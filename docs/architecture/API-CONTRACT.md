# API contract draft (atlas-backend)

- Status: **Draft / Proposed** (Phase 0). No business endpoints exist yet. Phase 1 serves only the
  actuator endpoints listed in [§12](#12-non-api-endpoints-phase-1-implemented).
- Decision record: [ADR-0006](../adr/0006-rest-api-openapi-problem-details.md) (REST + OpenAPI + Problem
  Details). Authentication: [ADR-0005](../adr/0005-authentication-provider-neutral-oidc.md).
- Source: `project-instruction.md` §3, §5, §7, §11.5–§11.6, §12.4, §13.4.
- The binding contract will be the generated OpenAPI document (Phase 3). This file explains the
  conventions and the planned endpoint families. Names may still change during Phase 3 review.
- Phase 2 alignment with the delivered frontend (2026-11-28): A-1…A-6 resolved, FQ-1…FQ-22 answered; see
  [phase-2-contract-review.md](../implementation/phase-2-contract-review.md). "(FQ-n)" marks a field or rule
  added by that review.

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
| `PUT` replace (singletons: profile, baseline, reward) | `200` + body | `If-Match` required once the resource exists (a reward uses the `ETag` of its goal or node, [§7](#7-optimistic-locking)) |
| `PATCH` partial update | `200` + body | `If-Match` required |
| `DELETE` | `204` | `If-Match` required on versioned resources; semantics per resource are documented (archive vs permanent) |

Exceptions without `If-Match` (FQ-21): goal dependencies are only created or deleted, never updated, and the
server serialises them per goal; `PUT /onboarding/steps/{stepKey}` is an idempotent upsert whose payload replaces
the owning module's value as a whole.

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
- `code` is the stable machine-readable key the frontend switches on. Initial catalogue (Phase 2 review;
  new codes may be added, existing ones never change):

  | `code` | Status | When |
  |---|---|---|
  | `MALFORMED_REQUEST` | `400` | Unparseable JSON, wrong type, unknown property |
  | `VALIDATION_FAILED` | `400` | Field violations in `errors[]` |
  | `UNAUTHENTICATED` | `401` | No or invalid credentials (Phase 3, BE-3.03) |
  | `FORBIDDEN` | `403` | Authenticated but missing scope |
  | `RESOURCE_NOT_FOUND` | `404` | Also for other owners' data |
  | `NODE_LOCKED` | `409` | Completing a locked node without override |
  | `NODE_HAS_CHILDREN` | `409` | Deleting a node with children without `cascade=true` |
  | `DEPENDENCY_CYCLE` | `409` | The new dependency would create a cycle |
  | `CROSS_GOAL_DEPENDENCY` | `409` | Prerequisite and dependent belong to different goals |
  | `INVALID_STATUS_TRANSITION` | `409` | For example completing a parent with open counted descendants, reopening a node that is not completed |
  | `REWARD_NOT_EARNED` | `409` | Redeeming a reward that is not `EARNED` |
  | `IDEMPOTENCY_IN_PROGRESS` | `409` | Same `Idempotency-Key` still being processed |
  | `VERSION_CONFLICT` | `412` | Stale `If-Match` |
  | `IDEMPOTENCY_KEY_REUSED` | `422` | Same key, different payload |
  | `CURRENCY_MISMATCH` | `422` | Amounts in different currencies combined |
  | `GOAL_TOO_LARGE` | `422` | Node count or depth bound exceeded (PLAN-BACKEND B-12) |
  | `BUSINESS_RULE_VIOLATED` | `422` | Other semantically invalid requests (`detail` explains) |
  | `PRECONDITION_REQUIRED` | `428` | Missing `If-Match` |
  | `INTERNAL_ERROR` | `500` | Unexpected error; carries `traceId` |

  Field-violation codes in `errors[].code` are the Jakarta constraint names (`NotBlank`, `NotNull`,
  `NotEmpty`, `Size`, `Range`, `Pattern`, ...) plus `InvalidEnum`, `InvalidFormat` and `Unknown` (unknown
  property). Clients show a generic message for codes they do not know.
- `detail` is a human-readable English message. User-facing text is localised in the frontend from
  `code`.
- Error bodies never contain stack traces, SQL, tokens, amounts, note text or other personal values.
  Server logs contain a correlation ID (`traceId`, from Micrometer tracing when added) that is also
  returned as the `traceId` extension member for `5xx`. Clients send no custom correlation header; the
  backend honours W3C `traceparent` once tracing is added (FQ-21).

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
- Small bounded sub-collections that are always shown completely are returned unpaginated, and the
  document states it explicitly: a goal's node tree, its dependencies (plain JSON array), the seven
  areas, and the owner-wide read models `GET /timeline` (`{ "items": [...] }`) and `GET /rewards`
  (revisit if a list exceeds 500 entries).

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

Which `ETag` a write needs (FQ-21):

| Write | `If-Match` |
|---|---|
| Goal `PATCH`, `DELETE`, `archive`, `restore`; goal reward `PUT`, `DELETE`, `redeem` | Goal `ETag` |
| Node `PATCH`, `DELETE`, `complete`, `reopen`, `unlock-condition`, `lock-override`; node reward `PUT`, `DELETE`, `redeem` | Node `ETag` |
| Note `PATCH`, `DELETE` | Note `ETag` |
| Creates (`POST` goal, node, note, dependency), dependency `DELETE`, onboarding step `PUT` | none |

Structural changes inside a goal (node create, move or delete, dependency changes, reward set or removed,
derived Waypoint status changes) also increment the **goal** version, so a goal `ETag` held across them is
stale.

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
  "summary": { "activeGoals": 2, "achievedWaypoints": 3 },
  "lifeBalance": [ { "areaKey": "CAREER", "label": "Career / Profession", "activeGoals": 2,
                     "progress": { "percent": "30.0" } } ],
  "activeGoals": [ { "id": "…", "title": "…", "primaryAreaKey": "CAREER",
                     "progress": { "percent": "40.0", "policy": "DERIVED", "countedWeight": "2", "totalWeight": "5",
                                   "excludedNodes": [ { "nodeId": "…", "title": "…" } ] },
                     "achievedWaypoints": 2,
                     "nextNode": { "id": "…", "title": "…", "nodeType": "MILESTONE", "status": "IN_PROGRESS",
                                   "availability": { "state": "AVAILABLE" },
                                   "dueDate": { "date": "2027-03-01", "precision": "MONTH" }, "progress": { "percent": "50.0" } },
                     "keyDates": [ { "nodeId": "…", "title": "Receive admission decision", "date": null } ],
                     "targetDate": { "date": "2027-07-01", "precision": "MONTH" },
                     "reward": { "description": "…", "status": "PLANNED" } } ],
  "upcomingDeadlines": [ { "goalId": "…", "nodeId": "…", "title": "…", "dueDate": { "date": "2026-12-01", "precision": "DAY" } } ],
  "inProgress": [ { "goalId": "…", "nodeId": "…", "title": "…", "nodeType": "TASK" } ],
  "moneySnapshot": null,
  "timeCapacity": null,
  "recentAchievements": [ { "goalId": "…", "nodeId": "…", "title": "…", "nodeType": "TASK",
                            "completedAt": "2026-11-10T18:00:00Z" } ]
}
```

`moneySnapshot` and `timeCapacity` are `null` until Phase 6. `?horizonDays=30` sets the deadline horizon.

Derivation rules (Phase 2 review, FQ-1…FQ-6):

- `progress` is `null` wherever there is nothing to measure (PLAN-DATABASE §8.1 rule 5); the backend never
  reports an invented `0 %`. `excludedNodes` lists skipped and cancelled nodes (FQ-5).
- An **achieved Waypoint** is a node with `nodeType` `MILESTONE` or `CHECKPOINT` and status `COMPLETED`
  (FQ-3); `summary.achievedWaypoints` counts them over active goals.
- `lifeBalance[].progress` is the weighted average of the area's active goals with measurable progress
  (primary assignment weight 1, secondary assignments their `weight`, default 1), else `null` (FQ-2).
- `nextNode` is the goal's next available node in tree order (FQ-1). `keyDates` are the goal's open
  top-level Waypoints in tree order, at most 5, with their `dueDate` or `null` (FQ-6).
- `inProgress` lists `TASK` nodes with status `IN_PROGRESS` of active goals, newest `updatedAt` first, at
  most 10 (FQ-4).

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
| `PUT` | `/api/v1/onboarding/steps/{stepKey}` | Save one step: `{ "status": "COMPLETED" \| "SKIPPED", "payload": { … } \| null }`. The payload is applied by the owning module; no `If-Match` ([§3](#3-http-semantics-and-status-codes)) |
| `POST` | `/api/v1/onboarding/complete` | Mark complete (allowed with skipped optional steps) |
| `POST` | `/api/v1/onboarding/reopen` | Reopen from Settings |

Step keys (agreed in Phase 2, DB-2.2), in wizard order:

| Key | Payload | Owning module | Available |
|---|---|---|---|
| `areas` (FQ-17) | `{ "areaKeys": ["CAREER", "HEALTH"] }`: the owner's focus Life Dimensions (0–7 canonical keys; replaces the previous selection) | `ikigai` (`focused` flag) | Phase 3 |
| `preferences` | profile preferences ([§9.2](#92-profile-phase-3-step-1)) | `profile` | Phase 3 |
| `personal-context` | optional personal context | `profile` | Phase 3 |
| `financial-baseline` | finance baseline | `finance` | Phase 6; optional and shown as "available later" before (B-10) |

Overall status: `NOT_STARTED`, `IN_PROGRESS`, `COMPLETED`. Step status: `NOT_STARTED`, `COMPLETED`, `SKIPPED`.
A `SKIPPED` step leaves the owning module's data unchanged.

### 9.4 Ikigai / Life Dimensions (Phase 3, step 2)

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/ikigai/areas` | The 7 areas (unpaginated, bounded) with owner settings |
| `PATCH` | `/api/v1/ikigai/areas/{areaKey}` | Rename label, recolour (`colorToken` from design tokens), reorder, hide, focus |

```json
{ "key": "CAREER", "label": "Career / Profession", "colorToken": "area-career", "sortOrder": 1, "hidden": false, "focused": true, "version": 0 }
```

`focused` marks the owner's focus Life Dimensions (set by the onboarding step `areas`, FQ-17, or by `PATCH`).
A Life Dimension "intention" is not an entity; the UI opens the goal form for the dimension (FQ-19).

### 9.5 Goals (Phase 3, steps 2–6)

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v1/goals` | Create (only `title` required, §3.5) |
| `GET` | `/api/v1/goals` | List; filters `status`, `area`, `q`, `targetFrom`, `targetTo`; sort `targetDate`, `priority`, `title`, `createdAt`, `updatedAt`. Without `status`, `ARCHIVED` goals are excluded; `status=ARCHIVED` lists them (FQ-8) |
| `GET` | `/api/v1/goals/{goalId}` | Detail incl. progress summary |
| `PATCH` | `/api/v1/goals/{goalId}` | Partial update (incl. status `DRAFT`/`ACTIVE`/`PAUSED`) |
| `POST` | `/api/v1/goals/{goalId}/archive`, `/restore` | Archive / restore (history preserved) |
| `DELETE` | `/api/v1/goals/{goalId}` | **Permanent** deletion of the goal and its subtree (A-1, resolved in Phase 2) |
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
(`{ "percent": "42.5", "policy": "DERIVED", "countedWeight": "17", "totalWeight": "40", "excludedNodes": [] }`,
or `null` when there is nothing to measure), `achievedWaypoints` (FQ-12), `nextAvailableNode`, `reward`,
`createdAt`, `updatedAt`, `version`. The list returns the summary `id`, `title`, `primaryAreaKey`, `status`,
`targetDate`, `progress`, `achievedWaypoints`, `nextAvailableNode`, `reward`. `progress.percent` is a decimal
string with one decimal place.

- `priority` ∈ `LOW`/`MEDIUM`/`HIGH` or `null` (agreed in DB-2.2). Nodes have no priority (FQ-11, deferred).
- `status` ∈ `DRAFT`, `ACTIVE`, `PAUSED`, `COMPLETED`, `ARCHIVED`; `PATCH` can set only the first three.
  `archive`/`restore` handle `ARCHIVED` (restore returns to the status before archiving).
- `secondaryAreas[].weight` is optional: a decimal string with up to three decimals and
  `0 < weight ≤ 1`; otherwise `400 VALIDATION_FAILED` with field code `Range` (FQ-20).
- There is no application-date field; an application deadline is a Waypoint with a `dueDate` (FQ-7).

### 9.6 Goal nodes, dependencies, notes, rewards (Phase 3, steps 3–6)

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v1/goals/{goalId}/nodes` | Create node (`parentId` optional = top level) |
| `GET` | `/api/v1/goals/{goalId}/tree` | Whole goal tree (unpaginated, bounded by a max node count per goal) |
| `GET` | `/api/v1/goals/{goalId}/nodes/{nodeId}` | Node detail |
| `PATCH` | `/api/v1/goals/{goalId}/nodes/{nodeId}` | Partial update, incl. `status` (`NOT_STARTED`, `IN_PROGRESS`, `SKIPPED`, `CANCELLED`), `parentId`/`sortOrder` (move) |
| `DELETE` | `/api/v1/goals/{goalId}/nodes/{nodeId}` | Delete node and subtree (`?cascade=true` required when it has children, else `409 NODE_HAS_CHILDREN`) |
| `POST` | `/api/v1/goals/{goalId}/nodes/{nodeId}/complete` | Complete (`409 NODE_LOCKED` if locked and not overridden); earns reward, recalculates unlocks |
| `POST` | `/api/v1/goals/{goalId}/nodes/{nodeId}/reopen` | Reopen a completed node: status becomes `IN_PROGRESS`; an `EARNED` reward returns to `PLANNED`, a `REDEEMED` one stays (FQ-10) |
| `GET` | `/api/v1/goals/{goalId}/nodes/{nodeId}/tree` | Focus view: node, breadcrumbs, direct children, descendant progress, lock reasons |
| `GET`/`POST` | `/api/v1/goals/{goalId}/dependencies` | List (plain JSON array, unpaginated) / add (`prerequisiteNodeId`, `dependentNodeId`); same goal only (`409 CROSS_GOAL_DEPENDENCY`), no cycles (`409 DEPENDENCY_CYCLE`) |
| `DELETE` | `/api/v1/goals/{goalId}/dependencies/{dependencyId}` | Remove |
| `PATCH` | `/api/v1/goals/{goalId}/nodes/{nodeId}/unlock-condition` | `ALL` (default) or `ANY` prerequisites |
| `POST`/`DELETE` | `/api/v1/goals/{goalId}/nodes/{nodeId}/lock-override` | Manual override with mandatory `reason` (audited) |
| `GET`/`POST` | `/api/v1/goals/{goalId}/notes` | Notes on the goal or a node. `GET` is paginated (default sort `createdAt,desc`); without `nodeId` it returns all notes of the goal, `?nodeId=` filters on the server (FQ-21) |
| `PATCH`/`DELETE` | `/api/v1/goals/{goalId}/notes/{noteId}` | Edit/delete note (`If-Match` with the note `ETag`) |
| `PUT`/`DELETE` | `/api/v1/goals/{goalId}/reward`, `/api/v1/goals/{goalId}/nodes/{nodeId}/reward` | Set/remove reward (one per goal/node; `{ "description": "…" }`; `If-Match` with the goal or node `ETag`) |
| `POST` | `…/reward/redeem` | Mark an `EARNED` reward as `REDEEMED` (else `409 REWARD_NOT_EARNED`); returns `{ "description", "status", "earnedAt", "redeemedAt" }` |

Note (FQ-9): `{ "id", "goalId", "nodeId": null, "body": "…", "format": "PLAIN", "createdAt", "updatedAt",
"version" }`. `body` holds at most 20,000 characters; `format` is `PLAIN` (default) or `MARKDOWN` (stored as text,
sanitised when rendered).

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
  "childCount": 4, "noteCount": 2, "version": 7
}
```

`availability.state` (`AVAILABLE`, `LOCKED`, `OVERRIDDEN`) is **derived** from dependencies and never
stored as a work status (§5.3). `noteCount` is returned in the tree (FQ-13).

**Waypoint status follows its Steps** (FQ-18, extends PLAN-DATABASE §8.1): after every write, a node with
`nodeType` `MILESTONE`/`CHECKPOINT` and counted children gets its status from them, in the same transaction:
all counted children `COMPLETED` → `COMPLETED` (earns its reward); any child `IN_PROGRESS` or `COMPLETED` →
`IN_PROGRESS`; otherwise the stored status, except that a Waypoint that is no longer complete returns to
`NOT_STARTED`. `SKIPPED`/`CANCELLED` Waypoints keep their status. The change is recorded as a system change.
`PATCH` cannot set a status that contradicts this rule (`409 INVALID_STATUS_TRANSITION`).

### 9.7 Timeline / Journey Overview (Phase 5; read model built in Phase 3)

`GET /api/v1/timeline?from=2026-01-01&to=2028-12-31&goalId=…&nodeType=MILESTONE`: flat list of dated
goals/nodes with precision, status, area and parent references for `vis-timeline`/calendar views.

```json
{ "items": [ { "goalId": "…", "goalTitle": "…", "nodeId": "…", "parentId": null, "nodeType": "MILESTONE",
               "title": "…", "status": "IN_PROGRESS", "areaKey": "CAREER",
               "date": { "date": "2027-03-01", "precision": "MONTH" }, "progress": { "percent": "50.0" } } ] }
```

Unpaginated ([§6](#6-pagination-filtering-sorting)). Goal items have `nodeId`/`nodeType` `null` and a goal
status. Undated items (`date: null`) are always returned for the selected goals; `from`/`to` filter dated items
only (FQ-14). `progress` is `null` when there is nothing to measure.

### 9.7a Milestone Awards (Phase 5, FQ-16)

`GET /api/v1/rewards`: owner-wide read model, unpaginated ([§6](#6-pagination-filtering-sorting)).

```json
{
  "summary": { "earned": 1, "planned": 2, "redeemed": 0 },
  "rewards": [ { "goalId": "…", "nodeId": null, "sourceTitle": "…", "areaKey": "CAREER", "description": "…",
                 "status": "EARNED", "earnedAt": "2026-11-10T18:00:00Z", "redeemedAt": null } ],
  "achievedWaypoints": [ { "goalId": "…", "nodeId": "…", "title": "…", "areaKey": "CAREER",
                           "completedAt": "2026-11-10T18:00:00Z", "progress": { "percent": "100.0" } } ]
}
```

### 9.7b Connections (Phase 6, FQ-15, deferred)

`GET /api/v1/connections` (associations and unverified possible impacts per goal) needs finance impacts and is
specified with the Phase 6 finance contract. The frontend's proposed `GoalConnection` model is the starting
point. No amount is returned without a confirmed source.

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

- Code-first with springdoc-openapi (`springdoc-openapi-starter-webmvc-api`, Apache-2.0). Spike BE-2.3
  (2026-11-28): **3.2.1** works with Spring Boot 4.2.0 and Jackson 3.1.8 and produces OpenAPI 3.1.0. The
  snapshot must be made reproducible and accurate (findings S-3…S-5 in
  [phase-2-contract-review.md §4](../implementation/phase-2-contract-review.md#4-spike-be-23-springdoc-3x-and-jwt-audiences)):
  - `BigDecimal` is documented as `number` by default although it is serialised as a string; a global
    schema replacement documents it as `string` with a decimal `pattern`.
  - An `OpenAPI` bean fixes title, version and `servers: [{ "url": "/" }]` (the default contains the random
    test port), and `springdoc.default-produces-media-type=application/json` replaces `*/*`.
  - Required properties, the bearer security scheme and the `ETag`/`If-Match` headers are added by
    annotations or customisers.
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

All six were resolved on 2026-11-28 in the Phase 2 review
([phase-2-contract-review.md §1](../implementation/phase-2-contract-review.md#1-api-decisions-a-1a-6)): the
recommended default is adopted in each case. Changing one after Phase 4 is a breaking change ([§10](#10-versioning-and-compatibility)).

| ID | Decision | Resolution | Trade-offs |
|---|---|---|---|
| A-1 | `DELETE /goals/{id}`: archive or permanent? | **Resolved:** explicit `archive`/`restore` actions, and `DELETE` = permanent deletion (with `If-Match`; UI confirms) | Matches acceptance criterion "archive and delete" (§20.3) and data minimisation. Mistakes are irreversible, so the UI needs a confirmation step. |
| A-2 | Optimistic locking style | **Resolved:** `ETag`/`If-Match` (§7) | Standard, works without bodies; slightly more client plumbing than a body `version`. |
| A-3 | Money `amount` as string or number | **Resolved:** string | Exact decimal; clients must parse for display (Angular `Intl.NumberFormat` handles strings). |
| A-4 | Problem `type` URI base | **Resolved:** `urn:problem:atlas:<kebab-case-code>` until a domain is decided | A resolvable URL could host documentation but needs a domain. |
| A-5 | Pagination envelope | **Resolved:** Spring Data `PagedModel` shape (`content` + `page`) | No custom code; tied to a framework convention (stable since Spring Data 3.3). |
| A-6 | OpenAPI approach | **Resolved:** code-first + committed snapshot (ADR-0006); springdoc 3.2.1 verified by spike BE-2.3 | Simple for one developer; contract-first would give stricter review but more tooling. |
