# Build stage
FROM gradle:9.2.1-jdk25 AS builder
WORKDIR /usr/src/app
COPY src ./src
COPY build.gradle .
COPY settings.gradle .
RUN gradle build -x test && \
    ls -la build/libs/ && \
    find build/libs -name "mcp-zap-server-*.jar" ! -name "*-plain.jar" -exec cp {} build/libs/app.jar \;

# Runtime stage
FROM eclipse-temurin:25-jre-alpine

# Security: Run as non-root user
RUN apk add --no-cache curl && \
    addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /usr/src/app/build/libs/app.jar ./app.jar

# Switch to non-root user
USER appuser

EXPOSE 7456
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:7456/actuator/health || exit 1
ENTRYPOINT ["java", "-Dspring.ai.mcp.server.type=sync", "-jar","/app/app.jar"]
