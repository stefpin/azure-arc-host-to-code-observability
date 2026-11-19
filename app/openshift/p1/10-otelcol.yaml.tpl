# OpenTelemetry Collector for MiniBank (community "contrib" distribution, version pinned) -> Azure Monitor native OTLP ingestion.
# Sign-in with Azure Arc workload identity (managed identity id-otelcol): NO secret, NO key, NO connection string in this file.
# Destination: data collection endpoint in Indonesia Central -> law-appmon (traces, logs), amw-appmon (metrics), appi-minibank views.
# Placeholders: ACR name, client ID of id-otelcol, the two DCE endpoints, the DCR immutable ID (MANIFEST.md section 0b).
# P1-B-DEPLOY.md Step 4 fills them in and applies the filled-in copy (rendered\10-otelcol.yaml); none of them is a secret.
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otelcol
  namespace: minibank-otel
  labels: {app: otelcol, demo: minibank}
  annotations:
    azure.workload.identity/client-id: "OTELCOL_CLIENT_ID"
imagePullSecrets:
  - name: acr-pull
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: otelcol-config
  namespace: minibank-otel
  labels: {app: otelcol, demo: minibank}
data:
  config.yaml: |
    # MiniBank OpenTelemetry Collector -> Azure Monitor (Indonesia Central)
    extensions:
      health_check:
        endpoint: 0.0.0.0:13133
      azure_auth:                        # Microsoft Entra sign-in with Arc workload identity - no secret
        workload_identity:
          client_id: ${env:AZURE_CLIENT_ID}
          tenant_id: ${env:AZURE_TENANT_ID}
          federated_token_file: ${env:AZURE_FEDERATED_TOKEN_FILE}
        scopes:
          - https://monitor.azure.com/.default
    receivers:
      otlp:                              # the injected OpenTelemetry agents send here (OTLP, open standard)
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    processors:
      memory_limiter:
        check_interval: 1s
        limit_percentage: 80
        spike_limit_percentage: 25
      filter/health:                     # drop Kubernetes health-probe spans before they leave the cluster
        error_mode: ignore
        trace_conditions:
          - 'IsMatch(span.name, ".*/actuator/health.*")'
      batch: {}
    exporters:
      otlphttp/azuremonitor:             # Azure Monitor native OTLP ingestion, data collection endpoint in Indonesia Central
        traces_endpoint: DCE_LOGS_ENDPOINT/datacollectionRules/DCR_IMMUTABLE_ID/streams/Microsoft-OTLP-Traces/otlp/v1/traces
        logs_endpoint: DCE_LOGS_ENDPOINT/datacollectionRules/DCR_IMMUTABLE_ID/streams/Microsoft-OTLP-Logs/otlp/v1/logs
        metrics_endpoint: DCE_METRICS_ENDPOINT/datacollectionRules/DCR_IMMUTABLE_ID/streams/Custom-Metrics-Otel/otlp/v1/metrics
        auth:
          authenticator: azure_auth
    service:
      extensions: [health_check, azure_auth]
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, filter/health, batch]
          exporters: [otlphttp/azuremonitor]
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlphttp/azuremonitor]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlphttp/azuremonitor]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otelcol
  namespace: minibank-otel
  labels: {app: otelcol, demo: minibank}
spec:
  replicas: 2
  selector:
    matchLabels: {app: otelcol}
  template:
    metadata:
      labels: {app: otelcol, azure.workload.identity/use: "true"}
    spec:
      serviceAccountName: otelcol
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels: {app: otelcol}
      tolerations:
        - {key: node.kubernetes.io/not-ready, operator: Exists, effect: NoExecute, tolerationSeconds: 60}
        - {key: node.kubernetes.io/unreachable, operator: Exists, effect: NoExecute, tolerationSeconds: 60}
      containers:
        - name: otelcol
          image: ACR_NAME.azurecr.io/otel/opentelemetry-collector-contrib:0.164.0
          args: ["--config=/conf/config.yaml"]
          ports:
            - {name: otlp-grpc, containerPort: 4317}
            - {name: otlp-http, containerPort: 4318}
            - {name: health, containerPort: 13133}
          readinessProbe:
            httpGet: {path: /, port: health}
            periodSeconds: 10
          livenessProbe:
            httpGet: {path: /, port: health}
            initialDelaySeconds: 30
            periodSeconds: 15
          volumeMounts:
            - {name: conf, mountPath: /conf}
          resources:
            requests: {cpu: 50m, memory: 128Mi}
            limits: {cpu: 500m, memory: 512Mi}
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            capabilities: {drop: ["ALL"]}
            seccompProfile: {type: RuntimeDefault}
      volumes:
        - name: conf
          configMap: {name: otelcol-config}
---
apiVersion: v1
kind: Service
metadata:
  name: otelcol
  namespace: minibank-otel
  labels: {app: otelcol, demo: minibank}
spec:
  selector: {app: otelcol}
  ports:
    - {name: otlp-grpc, port: 4317, targetPort: 4317}
    - {name: otlp-http, port: 4318, targetPort: 4318}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: otelcol
  namespace: minibank-otel
  labels: {app: otelcol, demo: minibank}
spec:
  minAvailable: 1
  selector:
    matchLabels: {app: otelcol}
