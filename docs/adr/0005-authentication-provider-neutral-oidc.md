# ADR-0005: Authentication: provider-neutral OIDC, BFF session for web, PKCE system browser for Capacitor

- Status: Proposed (provider choice accepted by the owner on 2026-11-12: Microsoft Entra External ID)
- Date: 2026-11-12
- Deciders: @hsnrzv (owner) to review; proposed by the backend planning agent

## Context

Atlas stores personal, financial, health-related and relationship data (`project-instruction.md` §13).
Authentication must be in place before any publicly reachable deployment. §13.1 requires:

- OIDC/OAuth2 instead of our own password storage.
- Authorization Code + PKCE for public/native clients, and preferably a BFF/session for the web.
- Validation of issuer, audience, signature, expiry and scopes.
- Owner-level authorization on every query.
- HttpOnly secure cookies with CSRF protection.
- A system-browser login for Capacitor, with tokens in secure native storage.
- No test identity in production.

The identity provider (§21.1) was decided by the owner on 2026-11-12: Microsoft Entra External ID (see the
provider choice below). The mobile auth/storage plugins (§21.9) are open. Phase 3 must enforce ownership; Phase 9
integrates the provider. The edge contract routes only `/api/` to the backend and
everything else to the frontend.

Verified on 2026-11-12: Spring Boot 4.1.2 manages Spring Security 7.1.2 and Spring Session 4.1.1.
Spring Security, not included in Phase 1, provides an OAuth2 resource server (JWT) and an OAuth2 client
(login).

## Decision

Proposed default:

1. **Provider-neutral Spring Security configuration.** Only standard OIDC discovery and JWKS are used.
   Provider-specific values (issuer URI, client ID/secret, audience) come from environment variables and
   secrets, never from code. No provider SDK is used.
2. **Resource server for `/api/**`** (`spring-boot-starter-security-oauth2-resource-server`; Boot 4
   deprecates the old `spring-boot-starter-oauth2-resource-server` name).
   - Every request is authenticated, except `/actuator/health/**` and `/actuator/info`.
   - JWT access tokens are validated for signature (JWKS), issuer, expiry/not-before, and a mandatory
     audience (custom `OAuth2TokenValidator`). Required scopes are checked per endpoint family.
3. **Web uses a BFF session.** The backend acts as a confidential OAuth2 client
   (`spring-boot-starter-security-oauth2-client`, Authorization Code + PKCE):
   - Tokens stay on the server.
   - The browser receives only a `__Host-` prefixed `Secure; HttpOnly; SameSite=Lax` session cookie.
   - Sessions are stored in PostgreSQL via Spring Session JDBC, so they survive restarts and rolling
     updates.
   - CSRF protection is on: cookie-to-header token for the Angular `HttpClient` XSRF support.
   - Login/callback/logout endpoints are mapped under `/api/auth/**` so the existing edge routing works
     unchanged.
4. **Native (Capacitor) uses Authorization Code + PKCE in the system browser** (RFC 8252) as a public
   client, with a claimed HTTPS redirect (or app-specific scheme if not possible).
   - Tokens are stored only in OS secure storage (Keychain / Android Keystore-backed) and sent as
     `Authorization: Bearer` to the resource server.
   - The `atlas` repository owns the plugin choice (to verify for Capacitor 8 compatibility).
5. **One owner model for both channels.** The authenticated principal (`iss`, `sub`) is mapped to an
   internal `owner_id` UUID (`profile_app_user`, created on first login). Application services take the
   owner from a `CurrentOwner` abstraction in `shared`, never from request bodies or paths. Every
   repository query is owner-scoped. Cross-owner access returns `404` (no existence leak).
6. **Tests and local development.**
   - Tests use `spring-security-test` JWT/OIDC request post-processors.
   - Local full-stack development uses Keycloak from `atlas-infra/local` when needed (open, see below).
   - A test/dev identity, if introduced, is only active in profiles `local`/test. The application fails
     to start if it is enabled together with `dev`, `staging` or `prod`.
7. **Phasing.** Phase 3 adds the resource server, owner mapping and owner checks (Phase 3 exit
   criterion). The BFF login flow and the production provider follow in Phase 9, or earlier if any
   environment becomes reachable from the internet.

Provider choice (§21.1). Options as compared before the decision:

| Option | Pros | Cons |
|---|---|---|
| Managed OIDC (e.g. Microsoft Entra External ID, Auth0, other OIDC-certified SaaS) | No identity server to patch, back up or monitor; MFA/passkeys/brute-force protection included; fits a one-person operation | Vendor terms, free-tier limits and pricing to verify; data residency to check; less control over login UI |
| Self-hosted Keycloak | Full control, open source (Apache-2.0), same server locally and in production | Another stateful workload with its own database, upgrades, backups and security patching; extra compute cost on a small cluster (§13.1 warns about this) |

Recommended default: **managed OIDC provider for dev/staging/prod**, and Keycloak only as an optional local
test IdP, so that operating effort stays low.

**Owner decision (2026-11-12): Microsoft Entra External ID** (external tenant linked to the Azure subscription;
`atlas-infra` ADR-0009). Facts checked on 2026-11-12:

- The first 50,000 monthly active users are free. The SMS authentication factor is a paid add-on and is not used.
- Azure AD B2C is no longer available to new customers since 2025-05-01, so it is not an option.
- Authority: `https://<tenant-subdomain>.ciamlogin.com/`. A custom sign-in domain needs Azure Front Door, which is
  out of MVP scope.
- Authorization Code + PKCE for public native clients and confidential web clients are supported.
- Self-service sign-up is disabled in the user flow (`isSignUpAllowed: false`); the owner account is created by an
  admin (B-8).

This decision does not change the provider-neutral design above. Issuer, client IDs, audience and secrets remain
configuration. No Microsoft SDK is added to the backend.

## Consequences

- The backend has two authentication entry points (session cookie, bearer token) that must both resolve
  to the same owner. Security tests must cover unauthenticated access, wrong audience/issuer, expired
  tokens, CSRF, and cross-owner access for both channels (§17.2).
- The BFF makes the backend stateful (sessions). Spring Session JDBC keeps it compatible with several
  replicas but adds a `spring_session` table set, which is created by Flyway, not by Spring Session's
  auto-initialiser.
- Same-origin hosting (edge routes `/api/` and `/` on one host) is required for the cookie model. This
  matches the local edge and the planned Kubernetes ingress.
- Changing the identity provider later is a configuration change plus a subject-mapping migration
  (`profile_app_user` keeps `issuer` + `subject`).

## Alternatives considered

- **SPA as public OAuth client with tokens in the browser:** simpler backend, but tokens in browser
  storage are exposed to XSS, and the IETF browser-based apps guidance prefers a BFF. The spec also
  prefers a BFF.
- **Separate BFF gateway (e.g. Spring Cloud Gateway, oauth2-proxy):** keeps the API stateless, but adds
  another deployable and configuration for one user. Can be reconsidered if more clients appear.
- **Own username/password storage:** explicitly forbidden by §13.1.
- **Embedded WebView login on mobile:** insecure and against RFC 8252; providers often block it.

## References

- `project-instruction.md` §13.1, §13.2, §17.2, §18 (Phases 3 and 9), §21.1, §21.9
- Spring Security, OAuth2 resource server JWT:
  <https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html>
  (accessed 2026-11-12)
- RFC 8252, OAuth 2.0 for Native Apps: <https://datatracker.ietf.org/doc/html/rfc8252>
- RFC 9700, Best Current Practice for OAuth 2.0 Security: <https://datatracker.ietf.org/doc/html/rfc9700>
- IETF draft, OAuth 2.0 for Browser-Based Applications:
  <https://datatracker.ietf.org/doc/draft-ietf-oauth-browser-based-apps/> (accessed 2026-11-12)
- ADR-0004 (owner FK), ADR-0006 (error format); see `atlas-infra` PLAN-INFRASTRUCTURE-CICD (secrets,
  ingress), `atlas-infra` ADR-0009 (Azure services) and the `atlas` PLAN-FRONTEND (Capacitor auth plugin)
- Microsoft Entra External ID overview:
  <https://learn.microsoft.com/en-us/entra/external-id/customers/overview-customers-ciam> (accessed 2026-11-12)
- Microsoft Entra External ID pricing:
  <https://learn.microsoft.com/en-us/entra/external-id/external-identities-pricing> (accessed 2026-11-12)
