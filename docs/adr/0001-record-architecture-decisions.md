# ADR-0001: Record architecture decisions

- Status: Accepted
- Date: 2026-11-12
- Deciders: @hsnrzv (owner)

## Context

`project-instruction.md` §0.1 requires that decisions which materially affect future work are recorded
before implementation, and that open choices are not silently assumed (§21). The project spans three
repositories (`atlas`, `atlas-microservices`, `atlas-infra`), each with its own lifecycle. Decisions
must stay reviewable next to the code they govern.

## Decision

We record backend architecture decisions as Architecture Decision Records in `docs/adr/` of this
repository, using the lightweight format of Michael Nygard as adapted in the cross-repository contract:

- File name `NNNN-kebab-case-title.md`, numbered sequentially from `0001` per repository; `0000-template.md`
  is the template and `README.md` the index.
- Header `# ADR-NNNN: Title`, then `- Status:`, `- Date:`, `- Deciders:`, then the sections Context,
  Decision, Consequences, Alternatives considered, References.
- Status values: `Proposed` (open, awaiting owner review), `Accepted` (owner decision or baseline
  implemented and verified), `Superseded by ADR-NNNN`.
- Accepted ADRs are not rewritten. A changed decision gets a new ADR that supersedes the old one; the old
  one only receives the status change and a link.
- Decisions that span repositories live in `atlas/docs/adr/` (for example repository topology and UI
  vocabulary) and are referenced as "see `atlas` ADR-NNNN (title)". Backend-specific decisions live here.

## Consequences

- Reviewers can trace why the backend looks the way it does; Copilot and humans have a fixed place to
  check before changing architecture.
- Every PR that changes an architectural rule must add or update an ADR (part of the Definition of Done).
- Numbers are local to each repository, so references must always name the repository.

## Alternatives considered

- **One ADR log for all repositories (in `atlas`):** a single place to look, but backend decisions would
  be reviewed away from the backend code, and backend PRs could not update them atomically.
- **Wiki or design documents without a fixed format:** easier to write, harder to review and to keep
  history; not versioned with the code.

## References

- `project-instruction.md` §0.1, §0.2, §21
- Michael Nygard, "Documenting Architecture Decisions" (2011),
  <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions> (accessed 2026-11-12)
- <https://adr.github.io/> (accessed 2026-11-12)
- See `atlas` ADR-0001 (record decisions) and `atlas` ADR-0002 (repository topology & ownership)
