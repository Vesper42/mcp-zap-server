package mcp.server.zap.configuration;

import jakarta.annotation.PostConstruct;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Configuration properties for API key clients.
 */
@Slf4j
@Data
@Configuration
@ConfigurationProperties(prefix = "mcp.server.auth")
public class ApiKeyProperties {

    // Known default/weak keys that should be rejected
    private static final Set<String> WEAK_KEYS = Set.of(
        "changeme-default-key",
        "changeme",
        "default",
        "password",
        "secret",
        "api-key",
        "apikey"
    );

    /**
     * List of registered API key clients.
     */
    private List<ApiKeyClient> apiKeys = new ArrayList<>();
    
    /**
     * Skip API key validation (for testing only).
     */
    @Value("${mcp.server.auth.skipValidation:false}")
    private boolean skipValidation;

    /**
     * Validate API keys at startup.
     */
    @PostConstruct
    public void validateApiKeys() {
        if (skipValidation) {
            log.warn("⚠️ API key validation is DISABLED - do not use in production!");
            return;
        }
        
        for (ApiKeyClient client : apiKeys) {
            if (client.getKey() != null) {
                String keyLower = client.getKey().toLowerCase().trim();
                
                // Check for weak/default keys
                if (WEAK_KEYS.stream().anyMatch(keyLower::contains)) {
                    log.error("⛔ SECURITY ERROR: Weak or default API key detected for client '{}'. " +
                              "Please configure a strong, unique API key.", client.getClientId());
                    throw new IllegalStateException(
                        "Weak or default API key detected. Please set a strong API key via MCP_API_KEY environment variable."
                    );
                }
                
                // Check minimum length
                if (client.getKey().length() < 16) {
                    log.error("⛔ SECURITY ERROR: API key for client '{}' is too short (min 16 characters).", 
                              client.getClientId());
                    throw new IllegalStateException(
                        "API key is too short. Please use at least 16 characters."
                    );
                }
            }
        }
        
        if (!apiKeys.isEmpty()) {
            log.info("✓ API key validation passed for {} client(s)", apiKeys.size());
        }
    }

    @Data
    public static class ApiKeyClient {
        /**
         * The API key value.
         */
        private String key;

        /**
         * Client identifier.
         */
        private String clientId;

        /**
         * Client display name.
         */
        private String name;
        
        /**
         * Client description.
         */
        private String description;

        /**
         * Scopes/permissions granted to this client.
         * Use "*" for all permissions.
         */
        private List<String> scopes = List.of("*");
    }
}
