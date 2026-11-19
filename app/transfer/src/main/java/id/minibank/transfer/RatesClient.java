package id.minibank.transfer;

import java.math.BigDecimal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Calls minibank-rates (GET {RATES_URL}/api/rates/check?channel=..&amount=..) for the fee and limit check.
 * minibank-rates runs on OpenShift with the Red Hat build of OpenTelemetry (zero-code agent injection).
 * The check never blocks a payment: after 2 seconds, or on any error, the fallback rate is used.
 * No account numbers are sent to minibank-rates (only channel and amount).
 */
@Component
public class RatesClient {

    public record RateCheck(String channel, BigDecimal amount, BigDecimal fee, BigDecimal perTransactionLimit,
                            boolean withinLimit, String ruleSet) {}

    private static final Logger log = LoggerFactory.getLogger(RatesClient.class);

    private final RestClient rest;

    public RatesClient(@Value("${rates.url}") String ratesUrl) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(1_000);   // ms
        factory.setReadTimeout(2_000);      // ms - 2 s budget, then fallback
        this.rest = RestClient.builder().baseUrl(ratesUrl).requestFactory(factory).build();
    }

    public RateCheck check(String channel, BigDecimal amount, String scenario) {
        try {
            RateCheck result = rest.get()
                    .uri(u -> u.path("/api/rates/check")
                            .queryParam("channel", channel)
                            .queryParam("amount", amount.toPlainString())
                            .build())
                    .header(TransferController.SCENARIO_HEADER, scenario)
                    .retrieve()
                    .body(RateCheck.class);
            if (result != null) {
                return result;
            }
            log.warn("minibank-rates returned an empty answer - fallback rate used");
        } catch (RuntimeException ex) {
            log.warn("minibank-rates unavailable ({}) - fallback rate used", ex.getClass().getSimpleName());
        }
        return new RateCheck(channel, amount, BigDecimal.ZERO, null, true, "FALLBACK");
    }
}
