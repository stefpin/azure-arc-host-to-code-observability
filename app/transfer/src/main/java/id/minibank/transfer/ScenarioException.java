package id.minibank.transfer;

/** Thrown on purpose by a demo scenario (fail-java). TransferController maps it to HTTP 500 with a traceId. */
public class ScenarioException extends RuntimeException {

    public ScenarioException(String message) {
        super(message);
    }
}
