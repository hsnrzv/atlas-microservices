## Summary

<!-- What changes and why. Link the backlog item (docs/plan/PLAN-BACKEND.md / PLAN-DATABASE.md) or issue. -->

## Type

- [ ] feat
- [ ] fix
- [ ] docs
- [ ] chore / build / ci
- [ ] refactor / test

## Tests

<!-- Which tests cover this change (unit, Spring Modulith, Testcontainers IT, API). Paste the command you ran. -->

## Migration steps

<!-- New Flyway migrations, expand/contract stage, backfill, config or env-var changes. Write "None" if not applicable. -->

## Known limitations / follow-ups

<!-- Write "None" if not applicable. -->

## Definition of Done (project-instruction.md §19)

- [ ] Acceptance criteria are met and demonstrated.
- [ ] Code follows repository and module boundaries (`ModularityTests` pass; no access to another module's internals).
- [ ] No business logic is duplicated between the UI and the backend.
- [ ] Automated tests cover the behaviour and important edge cases.
- [ ] API and database changes are versioned and documented (`docs/architecture/API-CONTRACT.md`, Flyway migration, `docs/plan/PLAN-DATABASE.md`).
- [ ] Applied Flyway migrations are unchanged; new migrations are forward-compatible (expand/contract).
- [ ] Security/privacy implications are considered (owner checks, no sensitive values in logs).
- [ ] CI passes, and no new critical/high vulnerability is ignored without a documented exception.
- [ ] No secrets or personal sample data are committed.
- [ ] README / plan / ADR updates are made where needed.
