package mcp.server.zap.service;

import lombok.extern.slf4j.Slf4j;
import mcp.server.zap.exception.ZapApiException;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Service;
import org.zaproxy.clientapi.core.*;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
public class OpenApiService {

    private static final Path ALLOWED_BASE_PATH = Paths.get("/zap/wrk").toAbsolutePath().normalize();

    private final ClientApi zap;
    private final UrlValidationService urlValidationService;

    public OpenApiService(ClientApi zap, UrlValidationService urlValidationService) {
        this.zap = zap;
        this.urlValidationService = urlValidationService;
    }

    /**
     * Import an OpenAPI/Swagger spec by URL into ZAP and return the importId.
     *
     * @param apiUrl       The OpenAPI/Swagger spec URL (JSON or YAML)
     * @param hostOverride Optional host override for the API spec
     * @return A message indicating the import status
     */
    @Tool(
            name        = "zap_import_openapi_spec_url",
            description = "Import an OpenAPI/Swagger spec by URL into ZAP and return the importId"
    )
    public String importOpenApiSpec(
            @ToolParam(description = "OpenAPI/Swagger spec URL (JSON or YAML, e.g., http://example.com/openapi.yaml)") String apiUrl,
            @ToolParam(description = "Host override for the API spec (optional)") String hostOverride
    ) {
        // Validate URL before importing
        urlValidationService.validateUrl(apiUrl);
        
        // Validate hostOverride if provided (SSRF protection)
        String sanitizedHostOverride = validateHostOverride(hostOverride);

        try {
            ApiResponse importResp = zap.openapi.importUrl(apiUrl, sanitizedHostOverride);
            List<String> importIds = new ArrayList<>();
            if (importResp instanceof ApiResponseList list) {
                for (ApiResponse item : list.getItems()) {
                    if (item instanceof ApiResponseElement elt) {
                        importIds.add(elt.getValue());
                    }
                }
            }
            return importIds.isEmpty()
                    ? "Import completed synchronously and is ready to scan."
                    : "Import completed asynchronously (jobs: " + String.join(",", importIds) + ") and is ready to scan.";
        } catch (ClientApiException e) {
            log.error("Failed to import OpenAPI spec from URL: {}", e.getMessage(), e);
            throw new ZapApiException("Failed to import OpenAPI spec", e);
        }
    }

    /**
     * Validate and sanitize hostOverride to prevent SSRF attacks.
     */
    private String validateHostOverride(String hostOverride) {
        if (hostOverride == null || hostOverride.trim().isEmpty()) {
            return "";
        }
        
        // Construct a URL to validate the host override
        String testUrl = "http://" + hostOverride.trim();
        try {
            urlValidationService.validateUrl(testUrl);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid host override: " + e.getMessage());
        }
        
        return hostOverride.trim();
    }


    /**
     * Import an OpenAPI/Swagger spec from a local file into ZAP and return the importId.
     *
     * @param filePath     The path to the OpenAPI/Swagger spec file (JSON or YAML)
     * @param hostOverride Optional host override for the API spec
     * @return A message indicating the import status
     */
    @Tool(
            name = "zap_import_openapi_spec_file",
            description = "Import an OpenAPI/Swagger spec (JSON or YAML) from a local file into ZAP and return the importId"
    )
    public String importOpenApiSpecFile(
            @ToolParam(description = "Path to the OpenAPI/Swagger spec file (JSON or YAML)") String filePath,
            @ToolParam(description = "Host override for the API spec") String hostOverride
    ) {
        // Validate file path to prevent path traversal attacks
        String validatedPath = validateFilePath(filePath);
        
        // Validate hostOverride if provided (SSRF protection)
        String sanitizedHostOverride = validateHostOverride(hostOverride);
        
        try {
            ApiResponse importResp = zap.openapi.importFile(validatedPath, sanitizedHostOverride);
            List<String> importIds = new ArrayList<>();
            if (importResp instanceof ApiResponseList list) {
                for (ApiResponse item : list.getItems()) {
                    if (item instanceof ApiResponseElement elt) {
                        importIds.add(elt.getValue());
                    }
                }
            }
            return importIds.isEmpty()
                    ? "Import completed synchronously and is ready to scan."
                    : "Import completed asynchronously (jobs: " + String.join(",", importIds) + ") and is ready to scan.";
        } catch (ClientApiException e) {
            log.error("Error importing OpenAPI spec file: {}", e.getMessage(), e);
            throw new ZapApiException("Error importing OpenAPI/Swagger spec file", e);
        }
    }

    /**
     * Validate file path to prevent path traversal attacks.
     * Uses path normalization instead of string contains check.
     */
    private String validateFilePath(String filePath) {
        if (filePath == null || filePath.trim().isEmpty()) {
            throw new IllegalArgumentException("File path cannot be null or empty");
        }
        
        try {
            // Normalize the path to resolve any .. or . components
            Path normalizedPath = Paths.get(filePath).toAbsolutePath().normalize();
            
            // Ensure the normalized path is still within the allowed directory
            if (!normalizedPath.startsWith(ALLOWED_BASE_PATH)) {
                log.warn("Path traversal attempt detected: {} normalized to {}", filePath, normalizedPath);
                throw new IllegalArgumentException("File must be in /zap/wrk/ directory");
            }
            
            return normalizedPath.toString();
        } catch (IllegalArgumentException e) {
            throw e; // Re-throw our own exceptions
        } catch (Exception e) {
            log.warn("Invalid file path: {}", filePath, e);
            throw new IllegalArgumentException("Invalid file path");
        }
    }

}
