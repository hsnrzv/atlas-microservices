# ADR-0008: Java 25 LTS as the backend runtime

- Status: Accepted
- Date: 2026-11-12
- Deciders: @hsnrzv (owner)

## Context

[ADR-0007](0007-java-21-spring-boot-4-1-maven-wrapper.md) set Java 21 LTS as the baseline because
`project-instruction.md` §9.3 proposes "Java 21 LTS, conservative LTS baseline". It listed "Java 25 LTS now"
as an alternative to revisit later. The owner asked to move to the newest LTS before any feature code exists,
because the change is cheapest now.

Verified on 2026-11-12:

- Java 25 is the newest LTS release (GA September 2025). Java 26 is end-of-life, and Java 27 (GA 2026-09-22)
  is a non-LTS feature release that Eclipse Temurin supports only until 2027-03-23.
- Eclipse Temurin support: 25 until 2031-09-30, 21 until 2029-12-31. The latest Temurin 25 patch is 25.0.5+8
  (2026-10-22). Source: <https://endoflife.date/eclipse-temurin> and <https://adoptium.net/support/>.
- Spring Boot 4.1.2 supports Java 17 up to Java 27 (Spring Boot system requirements), so Spring Framework 7,
  Hibernate 7.4, Flyway 12, Testcontainers 2 and Spring Modulith 2.1 need no version change.
- The images `eclipse-temurin:25-jdk-noble` and `eclipse-temurin:25-jre-noble` are published on Docker Hub.

## Decision

We will build and run the backend on **Java 25 LTS**. This supersedes the Java part of ADR-0007; Spring Boot
4.1, Spring Modulith 2.1 and the Maven Wrapper decisions in ADR-0007 stay unchanged.

- `pom.xml`: `<java.version>25</java.version>`. The existing Maven Enforcer rule `requireJavaVersion
  [${java.version},)` now fails the build on JDKs older than 25.
- Container images: `eclipse-temurin:25-jdk-noble` (build) and `eclipse-temurin:25-jre-noble` (runtime).
- CI: Temurin 25 through `actions/setup-java@v6`.
- Dependabot keeps ignoring Temurin major versions. The next LTS (expected Java 29) is again an ADR decision.
- Non-LTS releases (26, 27, 28) are not used, because each is supported for only six months.

## Consequences

- Developers need `JAVA_HOME` pointing to a JDK 25 (README and CONTRIBUTING). The owner's machine already
  has JDK 25 as its default.
- Open-source support for the runtime is about 21 months longer (2031-09-30 instead of 2029-12-31).
- Java 22–25 features become available to the code base, for example unnamed variables and patterns
  (`_`), flexible constructor bodies, module import declarations and the finalized Stream Gatherers and
  Class-File APIs. Preview features stay disabled (no `--enable-preview`).
- Runtime improvements apply without code changes: virtual threads no longer pin carrier threads in
  `synchronized` blocks (JEP 491), and the AOT class loading and linking cache (JEPs 483, 514, 515) can
  shorten startup.
- Follow-ups, each measured before adoption and not part of this switch:
  - compact object headers (`-XX:+UseCompactObjectHeaders`, JEP 519) to reduce heap use on the small
    k3s node;
  - an AOT cache in the container image for faster pod start;
  - `spring.threads.virtual.enabled=true` once the request and database load profile is known.
- Risk: a library or tool may lag behind Java 25. Java 25 has been generally available for 14 months, and the
  full `./mvnw verify` (modularity tests and Testcontainers integration tests) passes on it. A blocking issue
  would be handled by a temporary fallback to Java 21 through this ADR.

## Alternatives considered

- **Keep Java 21 (ADR-0007):** matches the spec text, but gives a shorter support window and older runtime,
  and the later upgrade would happen with more code to re-test.
- **Java 27 (newest feature release):** supported for only six months, so it would force a major upgrade
  every half year. Not suitable for production.

## References

- [ADR-0007](0007-java-21-spring-boot-4-1-maven-wrapper.md) (Spring Boot 4.1 and Maven Wrapper baseline)
- `project-instruction.md` §9.3 (Java 21 proposed as the conservative baseline; this ADR records the owner's
  deviation)
- Spring Boot system requirements: <https://docs.spring.io/spring-boot/system-requirements.html>
  (accessed 2026-11-12)
- <https://endoflife.date/eclipse-temurin>, <https://adoptium.net/support/> (accessed 2026-11-12)
- JDK 25 release notes: <https://openjdk.org/projects/jdk/25/> (accessed 2026-11-12)
