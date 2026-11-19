package id.minibank.transfer;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

/** All Oracle access (user MINIBANK, table LEDGER_ENTRY in FREEPDB1). The Java agent records every JDBC call. */
@Repository
public class LedgerRepository {

    public record LedgerLine(String referenceNo, String counterparty, BigDecimal amount,
                             String direction, String channel, Instant createdAt) {}

    private static final String INSERT_SQL =
            "INSERT INTO LEDGER_ENTRY (REFERENCE_NO, ACCOUNT_NO, COUNTERPARTY, AMOUNT, DIRECTION, CHANNEL, TRACE_ID) "
            + "VALUES (?, ?, ?, ?, ?, ?, ?)";

    private final JdbcTemplate jdbc;

    public LedgerRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Demo scenarios that happen inside Oracle. */
    private void applyScenario(String scenario) {
        if ("slow-oracle".equals(scenario)) {
            jdbc.execute("BEGIN DBMS_SESSION.SLEEP(2); END;");                          // Oracle waits 2 s
        } else if ("fail-oracle".equals(scenario)) {
            jdbc.queryForObject("SELECT COUNT(*) FROM LEDGER_MISSING", Integer.class);   // ORA-00942
        }
    }

    /** Transfer = debit row for the sender + credit row for the receiver, in one transaction. */
    @Transactional
    public void bookTransfer(String referenceNo, String fromAccount, String toAccount, BigDecimal amount,
                             String traceId, String scenario) {
        applyScenario(scenario);
        jdbc.update(INSERT_SQL, referenceNo, fromAccount, toAccount, amount, "D", "TRANSFER", traceId);
        jdbc.update(INSERT_SQL, referenceNo, toAccount, fromAccount, amount, "C", "TRANSFER", traceId);
    }

    /** QRIS = one debit row; the counterparty is the merchant name. */
    @Transactional
    public void bookQris(String referenceNo, String fromAccount, String merchant, BigDecimal amount,
                         String traceId, String scenario) {
        applyScenario(scenario);
        jdbc.update(INSERT_SQL, referenceNo, fromAccount, merchant, amount, "D", "QRIS", traceId);
    }

    /** Ledger lines of one account for the last N days, newest first. */
    public List<LedgerLine> statement(String accountNo, int days, String scenario) {
        applyScenario(scenario);
        return jdbc.query(
                "SELECT REFERENCE_NO, COUNTERPARTY, AMOUNT, DIRECTION, CHANNEL, CREATED_AT FROM LEDGER_ENTRY "
                + "WHERE ACCOUNT_NO = ? AND CREATED_AT >= SYS_EXTRACT_UTC(SYSTIMESTAMP) - NUMTODSINTERVAL(?, 'DAY') "
                + "ORDER BY CREATED_AT DESC FETCH FIRST 100 ROWS ONLY",
                (rs, rowNum) -> new LedgerLine(rs.getString(1), rs.getString(2), rs.getBigDecimal(3),
                        rs.getString(4), rs.getString(5), toInstant(rs.getTimestamp(6))),
                accountNo, days);
    }

    /** CREATED_AT holds UTC wall-clock time (TIMESTAMP without time zone). */
    private static Instant toInstant(Timestamp ts) {
        return ts == null ? null : ts.toLocalDateTime().toInstant(ZoneOffset.UTC);
    }
}
