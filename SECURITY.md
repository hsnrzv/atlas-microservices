# Security policy

IKIGAI ATLAS stores personal, financial, health-related and relationship context. Please treat any
security problem in this repository as sensitive.

## Reporting a vulnerability

- **Do not** open a public issue, discussion or pull request for a vulnerability.
- Report it privately through GitHub's
  [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
  on this repository (**Security** tab → **Report a vulnerability**).
  If that option is not available yet, contact the repository owner [@hsnrzv](https://github.com/hsnrzv)
  through GitHub and ask for a private channel. Do not include details in the first message.
- Include the affected version or commit, the impact, and steps to reproduce.

The owner aims to acknowledge reports within 7 days. This is a personal project without a formal SLA.

## Never post secrets or personal data

Never put credentials, tokens, connection strings, private keys, real financial or health data, or other
personal information into issues, pull requests, commit messages, logs or screenshots. If a secret was
exposed, report it privately; it must be revoked and rotated. Deleting the text is not enough.

## Supported versions

Only the latest commit on `main` is supported. There are no released versions yet.

## Security practices in this repository

- No secrets in Git. Local-only database credentials (`atlas`/`atlas`) exist only in `compose.yaml` and
  Testcontainers configuration and must never be used elsewhere.
- Only the `health` and `info` actuator endpoints are exposed; health details are hidden.
- The container runs as a non-root user (UID 10001).
- Dependabot updates dependencies, GitHub Actions and base images weekly; pull requests run GitHub
  dependency review.
- Authentication (OIDC) and owner-level authorization are planned before any public deployment
  (see [ADR-0005](docs/adr/0005-authentication-provider-neutral-oidc.md)).
