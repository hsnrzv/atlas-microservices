package dev.myatlas;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Entry point of the IKIGAI ATLAS backend, a Spring Modulith modular monolith.
 *
 * <p>Each direct sub-package of {@code dev.myatlas} is an application module (for example
 * {@code dev.myatlas.goals}). Modules are added in Phase 3; see {@code docs/architecture/DOMAIN-MODULES.md}.
 */
@SpringBootApplication
public class AtlasApplication {

	public static void main(String[] args) {
		SpringApplication.run(AtlasApplication.class, args);
	}

}
