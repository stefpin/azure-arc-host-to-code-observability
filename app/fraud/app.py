"""minibank-fraud - fraud-check service of the MiniBank demo (Python 3.11, FastAPI + uvicorn, port 8082).

POST /fraud/check  amount >= IDR 50,000,000 -> REVIEW, else APPROVE; one row in PostgreSQL table fraud_check
GET  /health       {"status": "ok"}
Demo scenarios: slow-python (time.sleep 1.5 s), slow-postgres (pg_sleep 1.5 s), fail-python (raise).
"""
import logging
import os
import time

# 1) Telemetry FIRST: configure_azure_monitor() runs before FastAPI is imported and the app is created,
#    so FastAPI requests and psycopg2 (PostgreSQL) calls are traced automatically.
#    Connection string: env APPLICATIONINSIGHTS_CONNECTION_STRING. Cloud role name: env OTEL_SERVICE_NAME=minibank-fraud.
from azure.monitor.opentelemetry import configure_azure_monitor

if os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    configure_azure_monitor(logger_name="minibank.fraud")
else:
    print("APPLICATIONINSIGHTS_CONNECTION_STRING is not set: telemetry is disabled", flush=True)

import psycopg2  # noqa: E402  (imported after telemetry on purpose)
from fastapi import FastAPI, Header  # noqa: E402
from fastapi.responses import JSONResponse  # noqa: E402
from opentelemetry import trace  # noqa: E402
from pydantic import BaseModel  # noqa: E402

log = logging.getLogger("minibank.fraud")
log.setLevel(logging.INFO)

PG_DSN = os.environ["PG_DSN"]   # postgresql://minibank_app:<password>@127.0.0.1:5432/minibank (from fraud.env)
REVIEW_THRESHOLD = 50_000_000   # IDR: at or above this amount the decision is REVIEW

app = FastAPI(title="minibank-fraud", version="1.1.0")


class FraudRequest(BaseModel):
    referenceNo: str
    channel: str = "TRANSFER"
    amount: float
    scenario: str | None = None


def current_trace_id() -> str:
    """W3C trace ID of the current request (the Trace ID shown in the browser)."""
    ctx = trace.get_current_span().get_span_context()
    return format(ctx.trace_id, "032x") if ctx.is_valid else "n/a"


@app.get("/health")
def health():
    return {"status": "ok", "service": "minibank-fraud", "version": "1.1.0"}


@app.post("/fraud/check")
def fraud_check(req: FraudRequest, x_minibank_scenario: str | None = Header(default=None)):
    # scenario: JSON field first, then header X-MiniBank-Scenario, else "normal"
    scenario = (req.scenario or x_minibank_scenario or "normal").strip().lower()
    try:
        if scenario == "fail-python":
            raise RuntimeError("Simulated failure in minibank-fraud (fail-python)")
        if scenario == "slow-python":
            time.sleep(1.5)  # time spent inside Python code

        decision = "REVIEW" if req.amount >= REVIEW_THRESHOLD else "APPROVE"
        score = 85 if decision == "REVIEW" else 10

        conn = psycopg2.connect(PG_DSN, connect_timeout=5)
        try:
            with conn, conn.cursor() as cur:  # "with conn" commits the transaction
                if scenario == "slow-postgres":
                    cur.execute("SELECT pg_sleep(1.5)")  # time spent inside PostgreSQL
                cur.execute(
                    "INSERT INTO fraud_check (reference_no, channel, amount, score, decision)"
                    " VALUES (%s, %s, %s, %s, %s)",
                    (req.referenceNo, req.channel, req.amount, score, decision),
                )
        finally:
            conn.close()
    except Exception as exc:  # noqa: BLE001 - every failure becomes JSON {error, traceId}
        # log.exception sends the exception to Application Insights (AppExceptions)
        log.exception("Fraud check failed for %s (scenario %s)", req.referenceNo, scenario)
        return JSONResponse(status_code=500, content={
            "error": str(exc), "service": "minibank-fraud", "traceId": current_trace_id()})

    log.info("Fraud check %s %s: %s (score %s, scenario %s)", req.channel, req.referenceNo, decision, score, scenario)
    return {"referenceNo": req.referenceNo, "decision": decision, "score": score, "traceId": current_trace_id()}
