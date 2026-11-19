package id.minibank.rates;

import java.math.BigDecimal;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET /api/rates/check?channel=TRANSFER|QRIS&amount=2500000
 * Fee and per-transaction limit for a MiniBank payment (demo rule set, synthetic).
 * Called by minibank-transfer inside the cluster. No account numbers are passed in.
 */
@RestController
@RequestMapping("/api/rates")
public class RatesController {

    public record RateCheck(String channel, BigDecimal amount, BigDecimal fee, BigDecimal perTransactionLimit,
                            boolean withinLimit, String ruleSet) {}

    private static final Logger log = LoggerFactory.getLogger(RatesController.class);
    private static final String RULE_SET = "MINIBANK-2026-11";
    private static final BigDecimal TRANSFER_LIMIT = new BigDecimal("500000000");   // IDR 500 million
    private static final BigDecimal QRIS_LIMIT = new BigDecimal("10000000");        // IDR 10 million

    @GetMapping("/check")
    public RateCheck check(@RequestParam String channel, @RequestParam BigDecimal amount) {
        String ch = channel.trim().toUpperCase(Locale.ROOT);
        BigDecimal limit = switch (ch) {
            case "TRANSFER" -> TRANSFER_LIMIT;
            case "QRIS" -> QRIS_LIMIT;
            default -> throw new IllegalArgumentException("Unknown channel: " + channel);
        };
        // MiniBank to MiniBank transfers and QRIS payments carry no customer fee in this demo rule set
        BigDecimal fee = BigDecimal.ZERO;
        boolean within = amount.signum() > 0 && amount.compareTo(limit) <= 0;
        log.info("rate check {} amount {} fee {} within limit {}", ch, amount.toPlainString(), fee, within);
        return new RateCheck(ch, amount, fee, limit, within, RULE_SET);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, String>> badRequest(IllegalArgumentException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(Map.of("error", ex.getMessage(), "service", "minibank-rates"));
    }
}
