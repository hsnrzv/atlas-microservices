package dev.myatlas;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.client.RestTestClient;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Boots the full application against a real PostgreSQL 18 container and checks the Phase 1 runtime contract:
 * Flyway migrations, health probes, actuator exposure and Problem Details errors.
 *
 * <p>Skipped (not failed) when no Docker daemon is available; CI asserts that it actually ran.
 */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
@Import(TestcontainersConfiguration.class)
class AtlasApplicationIT {

	@Autowired
	private RestTestClient http;

	@Autowired
	private JdbcTemplate jdbc;

	@Test
	void flywayManagesTheAtlasSchema() {
		List<String> appliedVersions = jdbc.queryForList(
				"select version from atlas.flyway_schema_history where success and version is not null order by installed_rank",
				String.class);
		assertThat(appliedVersions).contains("1");

		String schemaComment = jdbc.queryForObject(
				"select obj_description('atlas'::regnamespace, 'pg_namespace')", String.class);
		assertThat(schemaComment).isNotBlank();

		Integer historyTablesInPublic = jdbc.queryForObject(
				"select count(*) from information_schema.tables where table_schema = 'public' and table_name = 'flyway_schema_history'",
				Integer.class);
		assertThat(historyTablesInPublic).isZero();
	}

	@ParameterizedTest
	@ValueSource(strings = { "/actuator/health", "/actuator/health/liveness", "/actuator/health/readiness" })
	void healthEndpointsReportUp(String path) {
		http.get().uri(path).exchange()
			.expectStatus().isOk()
			.expectBody().jsonPath("$.status").isEqualTo("UP");
	}

	@Test
	void infoEndpointIsExposed() {
		http.get().uri("/actuator/info").exchange().expectStatus().isOk();
	}

	@Test
	void onlyHealthAndInfoActuatorEndpointsAreExposed() {
		http.get().uri("/actuator/env").exchange().expectStatus().isNotFound();
	}

	@Test
	void unknownApiPathsReturnProblemDetails() {
		http.get().uri("/api/v1/does-not-exist").exchange()
			.expectStatus().isNotFound()
			.expectHeader().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON)
			.expectBody().jsonPath("$.status").isEqualTo(404);
	}

}
