# Multi-stage Dockerfile for Door Manufacturing Job Workflow Management Backend

# Stage 1: Build JAR with Maven and OpenJDK 21
FROM maven:3.9.6-eclipse-temurin-21-alpine AS builder
WORKDIR /build

# Cache maven dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Build application
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: Minimal JRE 21 Runtime image
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Add non-root system user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy executable jar from builder stage
COPY --from=builder --chown=appuser:appgroup /build/target/door-workflow-backend-*.jar app.jar

# Configuration environment variables
ENV SPRING_PROFILES_ACTIVE=production
ENV PORT=8080

EXPOSE 8080

ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
