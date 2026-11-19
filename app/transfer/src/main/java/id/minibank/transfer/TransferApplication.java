package id.minibank.transfer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * minibank-transfer: books transfers and QRIS payments in Oracle (table LEDGER_ENTRY)
 * after asking minibank-fraud (Python) for a fraud decision.
 * Telemetry comes from the Application Insights Java agent (-javaagent in the Dockerfile):
 * this code contains no telemetry calls at all.
 */
@SpringBootApplication
public class TransferApplication {

    public static void main(String[] args) {
        SpringApplication.run(TransferApplication.class, args);
    }
}
