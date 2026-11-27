# syntax=docker/dockerfile:1

# ---- Build stage -------------------------------------------------------------------------------
FROM eclipse-temurin:25-jdk-noble AS build
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /workspace

# Dependency layer: re-used until pom.xml or the Maven Wrapper changes.
COPY --chmod=0755 mvnw ./
COPY .mvn/ .mvn/
COPY pom.xml ./
RUN ./mvnw -B -q dependency:go-offline

COPY src/ src/
RUN ./mvnw -B -DskipTests package \
    && java -Djarmode=tools -jar target/atlas-backend.jar extract --layers --launcher --destination target/extracted

# Third-party licence texts shipped with the image (BE-2.4, THIRD-PARTY-NOTICES.md): THIRD-PARTY.txt lists every
# packaged library with its licence, and the LICENSE/NOTICE files bundled in each jar are kept per jar. The
# canonical licence texts come from licenses/ (see licenses/README.md).
RUN ./mvnw -B -q license:add-third-party \
    && find target/extracted -path '*/BOOT-INF/lib/*.jar' -print0 | while IFS= read -r -d '' lib; do \
         entries="$(jar tf "$lib" | grep -iE '^META-INF/([^/]+/)?(LICENSE|NOTICE|COPYING)[^/]*$' || true)"; \
         [ -n "$entries" ] || continue; \
         dest="target/licenses/jars/$(basename "$lib" .jar)"; \
         mkdir -p "$dest" && (cd "$dest" && echo "$entries" | xargs jar xf "/workspace/$lib"); \
       done \
    && test -s target/licenses/THIRD-PARTY.txt

# ---- Runtime stage -----------------------------------------------------------------------------
FROM eclipse-temurin:25-jre-noble AS runtime

ARG VERSION=0.0.1-SNAPSHOT
ARG REVISION=unknown
ARG CREATED=unknown

LABEL org.opencontainers.image.title="atlas-backend" \
      org.opencontainers.image.description="IKIGAI ATLAS backend (Spring Boot modular monolith)" \
      org.opencontainers.image.source="https://github.com/hsnrzv/atlas-microservices" \
      org.opencontainers.image.url="https://github.com/hsnrzv/atlas-microservices" \
      org.opencontainers.image.vendor="hsnrzv" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${CREATED}" \
      org.opencontainers.image.base.name="docker.io/library/eclipse-temurin:25-jre-noble"

# Fixed, non-root UID/GID so Kubernetes `runAsNonRoot`/`runAsUser: 10001` can be enforced.
RUN groupadd --system --gid 10001 atlas \
    && useradd --system --uid 10001 --gid atlas --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin atlas

WORKDIR /app
# Least-frequently changing layers first. Files stay root-owned and read-only for the runtime user;
# the application writes only to /tmp (Tomcat work dir), so a read-only root filesystem needs a /tmp volume.
COPY --from=build /workspace/target/extracted/dependencies/ ./
COPY --from=build /workspace/target/extracted/spring-boot-loader/ ./
COPY --from=build /workspace/target/extracted/snapshot-dependencies/ ./
COPY --from=build /workspace/target/extracted/application/ ./
COPY --from=build /workspace/target/licenses/ /licenses/
COPY licenses/*.txt /licenses/texts/

USER 10001:10001
EXPOSE 8080

# Container-aware heap sizing; exit (and let the orchestrator restart) on OOM instead of limping on.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"

# Exec form: the JVM is PID 1 and receives SIGTERM for graceful shutdown.
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
