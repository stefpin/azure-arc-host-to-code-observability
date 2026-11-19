package id.minibank.transfer;

import java.math.BigDecimal;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/** Calls minibank-fraud (POST {FRAUD_URL}/fraud/check). The Java agent traces this HTTP call automatically. */
@Component
public class FraudClient {

    public record FraudRequest(String referenceNo, String channel, BigDecimal amount, String scenario) {}

    public record FraudResult(String referenceNo, String decision, int score) {}

    private final RestClient rest;

    public FraudClient(@Value("${fraud.url}") String fraudUrl) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(3_000);   // ms
        factory.setReadTimeout(10_000);     // ms (slow-python and slow-postgres take 1.5 s)
        this.rest = RestClient.builder().baseUrl(fraudUrl).requestFactory(factory).build();
    }

    public FraudResult check(String referenceNo, String channel, BigDecimal amount, String scenario) {
        FraudResult result = rest.post()
                .uri("/fraud/check")
                .contentType(MediaType.APPLICATION_JSON)
                .header(TransferController.SCENARIO_HEADER, scenario)   // forward the demo scenario
                .body(new FraudRequest(referenceNo, channel, amount, scenario))
                .retrieve()                                             // HTTP 4xx/5xx -> RestClientException
                .body(FraudResult.class);
        if (result == null || result.decision() == null) {
            throw new IllegalStateException("Empty answer from minibank-fraud");
        }
        return result;
    }
}
