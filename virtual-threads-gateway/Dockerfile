# Stage 1: Build the application using Gradle
FROM gradle:8.8-jdk21 AS builder
WORKDIR /app

# Copy only necessary files first to leverage Docker cache
COPY build.gradle.kts settings.gradle.kts gradlew ./ 
COPY gradle ./gradle

# Download dependencies (if needed, often handled by build)
# RUN ./gradlew dependencies

# Copy the rest of the project
COPY . .

# Build the application, skipping tests for faster image build
RUN ./gradlew :virtual-threads-gateway:bootJar --no-daemon

# Stage 2: Create the runtime image
# Switch to openjdk base image
FROM openjdk:21-slim
WORKDIR /app

# Copy the built JAR from the builder stage
COPY --from=builder /app/virtual-threads-gateway/build/libs/virtual-threads-gateway.jar ./app.jar

# Expose the application port
EXPOSE 8081

# Command to run the application
ENTRYPOINT ["java", "-jar", "./app.jar"] 