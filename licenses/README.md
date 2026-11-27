# Licence texts shipped in the image

Canonical plain-text licences from [SPDX license-list-data](https://github.com/spdx/license-list-data)
v3.29.0 (`text/<id>.txt`) for every licence class of the libraries packaged in `atlas-backend.jar`
(see [THIRD-PARTY-NOTICES](../THIRD-PARTY-NOTICES.md)). The Dockerfile copies them to `/licenses/texts/`, next to:

- `/licenses/THIRD-PARTY.txt`: every packaged library with its licence (`license-maven-plugin`, generated at build time);
- `/licenses/jars/<artifact>-<version>/`: the LICENSE/NOTICE files bundled in each jar (Apache-2.0 NOTICE files included).

| File | Used by |
|---|---|
| `Apache-2.0.txt` | Spring, Hibernate, Tomcat, Jackson, Flyway, Micrometer and most other libraries |
| `EPL-2.0.txt` | AspectJ, Jakarta Persistence/Annotations/Transaction APIs, Logback (dual with LGPL-2.1) |
| `LGPL-2.1-only.txt` | Logback (dual with EPL-2.0) |
| `GPL-2.0-only.txt`, `Classpath-exception-2.0.txt` | Jakarta Annotations/Transaction APIs (dual with EPL-2.0) |
| `BSD-3-Clause.txt` | ANTLR 4 runtime; Eclipse Distribution License 1.0 (Jakarta XML Binding, Activation, Angus) is BSD-3-Clause |
| `BSD-2-Clause.txt` | PostgreSQL JDBC driver, HdrHistogram |
| `CC0-1.0.txt` | HdrHistogram (dual with BSD-2-Clause) |
| `MIT.txt` | SLF4J, Checker Qual |

Add the SPDX text here when a dependency with a new licence class is added (THIRD-PARTY-NOTICES workflow).
