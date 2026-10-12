# Multi-stage build for Spring Boot Gradle Application
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY . .
RUN if ! ls build/libs/*.jar 1> /dev/null 2>&1; then chmod +x gradlew && ./gradlew bootJar -x test --no-daemon; fi

# Runtime stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
