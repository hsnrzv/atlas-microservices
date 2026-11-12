package dev.myatlas;

import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModules;
import org.springframework.modulith.docs.Documenter;

/**
 * Verifies Spring Modulith module boundaries and renders module documentation to
 * {@code target/spring-modulith-docs} (generated, not committed).
 */
class ModularityTests {

	private static final ApplicationModules MODULES = ApplicationModules.of(AtlasApplication.class);

	@Test
	void verifiesModuleBoundaries() {
		MODULES.verify();
	}

	@Test
	void writesModuleDocumentation() {
		new Documenter(MODULES).writeDocumentation();
	}

}
