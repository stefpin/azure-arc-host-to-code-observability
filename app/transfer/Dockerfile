# minibank-transfer image 1.2.0: Java 21 + Spring Boot 3.5 + Application Insights Java agent 3.7.9 (calls minibank-rates)
# Build in Azure with ACR Tasks, from the transfer/ folder (replace ACR_NAME):
#   podman build -t ACR_NAME.azurecr.io/minibank-transfer:1.2.0 .   (ACR Tasks are not available in Indonesia Central)
# Runs under the OpenShift restricted SCC with a random UID: nothing is written except /tmp.

# ---------- Stage 1: build the jar with Maven ----------
FROM registry.access.redhat.com/ubi9/openjdk-21 AS build
USER root
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -q -DskipTests package

# ---------- Stage 2: runtime image ----------
FROM registry.access.redhat.com/ubi9/openjdk-21-runtime
# root only to download the agent and set file permissions
USER root
RUN (command -v curl >/dev/null 2>&1 || microdnf -y install curl-minimal) \
 && mkdir -p /opt/appinsights \
 && curl -fsSL -o /opt/appinsights/applicationinsights-agent-3.7.9.jar \
    https://github.com/microsoft/ApplicationInsights-Java/releases/download/3.7.9/applicationinsights-agent-3.7.9.jar
# agent configuration must sit next to the agent jar (no connection string inside: env var)
COPY applicationinsights.json /opt/appinsights/applicationinsights.json
RUN chmod 755 /opt/appinsights && chmod 644 /opt/appinsights/*
COPY --from=build /build/target/minibank-transfer.jar /deployments/app.jar
RUN chmod 644 /deployments/app.jar
# back to the non-root user of the base image (OpenShift replaces it with a random UID, group 0)
USER 185
EXPOSE 8080
# heap = at most half of the container memory limit (limit 768Mi in openshift/10-deployment.yaml)
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=50"
ENTRYPOINT ["java", "-javaagent:/opt/appinsights/applicationinsights-agent-3.7.9.jar", "-jar", "/deployments/app.jar"]
