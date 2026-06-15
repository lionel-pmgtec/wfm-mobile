package com.wfm.middleware;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Punto di ingresso del middleware WFM.
 *
 * Espone un'API REST/JSON consumata dall'app Flutter WFM Mobile e (in seguito)
 * traduce le chiamate in SOAP verso SAP. Per l'MVP usa uno store in memoria.
 *
 * Avvio:  mvn spring-boot:run
 * Base URL: http://localhost:8080/api/v1
 * Swagger:  http://localhost:8080/api/v1/swagger-ui.html
 */
@SpringBootApplication
public class WfmMiddlewareApplication {
    public static void main(String[] args) {
        SpringApplication.run(WfmMiddlewareApplication.class, args);
    }
}
