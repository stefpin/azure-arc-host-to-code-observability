package id.minibank.rates;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** MiniBank fee and limit check. Plain Spring Boot: no monitoring library, no monitoring code. */
@SpringBootApplication
public class RatesApplication {

    public static void main(String[] args) {
        SpringApplication.run(RatesApplication.class, args);
    }
}
