# minibank-rates image 1.0.0: Java 21 + Spring Boot 3.5. NO monitoring agent inside (compare transfer/Dockerfile).
# The Red Hat build of OpenTelemetry operator injects the OpenTelemetry Java agent when the Deployment carries
# the annotation instrumentation.opentelemetry.io/inject-java: "true" (zero code, zero image change).
# Build on APP-RHEL (ACR Tasks are not available in Indonesia Central):
#   podman build -t ACR_NAME.azurecr.io/minibank-rates:1.0.0 .
FROM registry.access.redhat.com/ubi9/openjdk-21 AS build
USER root
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -q -DskipTests package

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime
USER root
COPY --from=build /build/target/minibank-rates.jar /deployments/app.jar
RUN chmod 644 /deployments/app.jar
USER 185
EXPOSE 8080
# heap settings come from the Deployment (JAVA_TOOL_OPTIONS), because the operator adds -javaagent to that variable
ENTRYPOINT ["java", "-jar", "/deployments/app.jar"]
