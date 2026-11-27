# Third-party notices

This file lists the third-party software that `atlas-backend` uses directly, the most relevant
transitive components shipped in the application jar, and the build/CI/runtime tooling. Versions are
the ones resolved by `pom.xml` on 2026-11-12 (Spring Boot 4.1.2 BOM, Spring Modulith 2.1.1 BOM).

License identifiers were taken from the artifacts' published POM metadata via
`./mvnw org.codehaus.mojo:license-maven-plugin:add-third-party` (output in
`target/licenses/THIRD-PARTY.txt`, not committed) and, for GitHub Actions and container images, from the
GitHub repository license API. Re-run the plugin and update this file whenever a dependency is added,
removed or upgraded (Dependabot PRs included). The consolidated cross-repository matrix lives in
`atlas/docs/architecture/DEPENDENCY-LICENSE-MATRIX.md`.

**Project license:** not chosen yet. This is an open owner decision, so there is no `LICENSE` file.

## Direct dependencies (`pom.xml`)

| Dependency | Version | Scope | License | Concrete use |
|---|---|---|---|---|
| `org.springframework.boot:spring-boot-starter-parent` | 4.1.2 | build (parent) | Apache-2.0 | Dependency/plugin management, packaging |
| `org.springframework.boot:spring-boot-starter-webmvc` | 4.1.2 | compile | Apache-2.0 | HTTP server (Tomcat), Spring MVC, Problem Details |
| `org.springframework.boot:spring-boot-starter-actuator` | 4.1.2 | compile | Apache-2.0 | Health/liveness/readiness and info endpoints, Micrometer |
| `org.springframework.boot:spring-boot-starter-validation` | 4.1.2 | compile | Apache-2.0 | Jakarta Bean Validation (Hibernate Validator) for API input |
| `org.springframework.boot:spring-boot-starter-data-jpa` | 4.1.2 | compile | Apache-2.0 | Spring Data JPA / Hibernate ORM, HikariCP |
| `org.springframework.boot:spring-boot-starter-flyway` | 4.1.2 | compile | Apache-2.0 | Flyway auto-configuration (schema migrations) |
| `org.flywaydb:flyway-database-postgresql` | 12.4.0 | compile | Apache-2.0 | Flyway PostgreSQL support (required since Flyway 10) |
| `org.springframework.modulith:spring-modulith-starter-core` | 2.1.1 | compile | Apache-2.0 | Module model, boundary verification, events infrastructure |
| `org.postgresql:postgresql` | 42.7.14 | runtime | BSD-2-Clause | PostgreSQL JDBC driver |
| `org.springframework.boot:spring-boot-docker-compose` | 4.1.2 | runtime, optional (not in the jar) | Apache-2.0 | Starts `compose.yaml` for the `local` profile |
| `org.springframework.boot:spring-boot-starter-webmvc-test` | 4.1.2 | test | Apache-2.0 | JUnit Jupiter, AssertJ, Mockito, `RestTestClient` |
| `org.springframework.boot:spring-boot-testcontainers` | 4.1.2 | test | Apache-2.0 | `@ServiceConnection` for Testcontainers |
| `org.springframework.modulith:spring-modulith-starter-test` | 2.1.1 | test | Apache-2.0 | `ApplicationModules.verify()`, `Documenter`, module tests |
| `org.testcontainers:testcontainers-junit-jupiter` | 2.0.5 | test | MIT | `@Testcontainers` JUnit 5 extension |
| `org.testcontainers:testcontainers-postgresql` | 2.0.5 | test | MIT | PostgreSQL 18 container for integration tests |

## Notable transitive components in the application jar

The packaged jar (`target/atlas-backend.jar`) contains 89 libraries. The most relevant are:

| Component | Version | License |
|---|---|---|
| Spring Framework (`spring-core`, `-web`, `-webmvc`, `-orm`, ...) | 7.0.10 | Apache-2.0 |
| Spring Data JPA / Commons | 4.1.2 | Apache-2.0 |
| Hibernate ORM (`hibernate-core`), Hibernate Models | 7.4.13.Final, 1.1.2 | Apache-2.0 |
| Hibernate Validator | 9.1.5.Final | Apache-2.0 |
| Apache Tomcat embed (`core`, `el`, `websocket`) | 11.0.27 | Apache-2.0 |
| Jackson (`tools.jackson.core` 3.x; `jackson-annotations` 2.x) | 3.1.7 / 2.21 | Apache-2.0 |
| HikariCP | 7.0.2 | Apache-2.0 |
| Flyway core | 12.4.0 | Apache-2.0 |
| Micrometer (`core`, `observation`, `commons`, `jakarta9`) | 1.17.2 | Apache-2.0 |
| Logback (`classic`, `core`) | 1.5.38 | EPL-2.0 OR LGPL-2.1-only (dual) |
| SLF4J API, `jul-to-slf4j` | 2.0.20 | MIT |
| Log4j API / `log4j-to-slf4j` (bridge only) | 2.25.5 | Apache-2.0 |
| Spring Modulith `api`, `core`, `moments` | 2.1.1 | Apache-2.0 |
| ArchUnit (used by Spring Modulith core) | 1.4.2 | Apache-2.0 |
| jMolecules (`jmolecules-events`, `jstereotype`) | 2.0.1 | Apache-2.0 |
| Byte Buddy | 1.18.15 | Apache-2.0 |
| ANTLR 4 runtime (Hibernate HQL) | 4.13.2 | BSD-3-Clause |
| AspectJ weaver (`spring-aspects`) | 1.9.25.1 | EPL-2.0 |
| Jakarta Persistence API | 3.2.0 | EPL-2.0 OR EDL-1.0 |
| Jakarta Annotations API, Jakarta Transaction API | 3.0.0, 2.0.1 | EPL-2.0 OR GPL-2.0-with-classpath-exception |
| Jakarta Validation API, Jakarta Inject API | 3.1.1, 2.0.1 | Apache-2.0 |
| Jakarta XML Binding API, JAXB runtime/core, TXW2, istack, Jakarta Activation, Angus Activation | 4.0.5, 4.0.9, 4.0.9, 4.1.2, 2.1.4, 2.0.3 | EDL-1.0 (BSD-3-Clause) |
| JSpecify | 1.0.1 | Apache-2.0 |
| Checker Qual | 3.55.1 | MIT |
| HdrHistogram | 2.2.2 | BSD-2-Clause OR CC0-1.0 |
| SnakeYAML | 2.6 | Apache-2.0 |
| JBoss Logging, ClassMate, Commons Logging | 3.6.3.Final, 1.7.3, 1.3.6 | Apache-2.0 |

Test-only transitive components include JUnit Jupiter/Platform 6.0.3 (EPL-2.0), Mockito 5.23.0 (MIT),
AssertJ 3.27.7 (Apache-2.0), Hamcrest 3.0 (BSD-3-Clause), Awaitility 4.3.0 (Apache-2.0), docker-java
3.7.1 (Apache-2.0), JNA 5.18.1 (Apache-2.0 OR LGPL-2.1-or-later), Apache Commons Compress 1.28.0
(Apache-2.0), Duct Tape 1.0.8 (MIT) and Structurizr 5.0.3 (Apache-2.0, Spring Modulith documentation).

No dependency is GPL-only. Where a component offers a choice of licenses (Logback, JNA, Jakarta APIs),
the permissive or weak-copyleft option applies to unmodified binary use.

## Build, CI and runtime tooling (not linked into the application)

| Tool | Version | License | Use |
|---|---|---|---|
| Apache Maven (via Maven Wrapper 3.3.4) | 3.10.1 | Apache-2.0 | Build |
| Maven Enforcer / Surefire / Failsafe / Compiler plugins | 3.6.3 / 3.5.6 / 3.5.6 / 3.15.0 | Apache-2.0 | Build rules, tests |
| JaCoCo (`jacoco-maven-plugin`, test agent) | 0.8.16 | EPL-2.0 | Coverage report in `verify`; the agent is attached to test JVMs only, never packaged |
| CycloneDX Maven plugin (`cyclonedx-maven-plugin`, version managed by Spring Boot) | 2.9.3 | Apache-2.0 | SBOM generation (the generated `application.cdx.json` is data, not code) |
| Trivy, `aquasecurity/trivy-action` | v0.76.2, v0.36.0 (commit pin) | Apache-2.0 | CI image vulnerability scan and image SBOM |
| `eclipse-temurin:25-jdk-noble`, `eclipse-temurin:25-jre-noble` | Java 25 (25.0.5 at build time) | OpenJDK: GPL-2.0 with Classpath Exception; image definitions: Apache-2.0 ([adoptium/containers](https://github.com/adoptium/containers)); Ubuntu 24.04 packages under their own licenses | Container build and runtime |
| `postgres:18.6-alpine` | PostgreSQL 18.6 | PostgreSQL License; image definitions: MIT ([docker-library/postgres](https://github.com/docker-library/postgres)) | Local database, Testcontainers, CI smoke test |
| `actions/checkout`, `actions/setup-java`, `actions/upload-artifact`, `actions/dependency-review-action` | v7, v6, v7, v5 | MIT | CI |
| `docker/setup-buildx-action`, `docker/build-push-action` | v4, v7 | Apache-2.0 | Container build in CI |
