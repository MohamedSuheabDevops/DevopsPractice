package com.careconnect.appointments;

import java.net.InetAddress;
import java.util.Map;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Minimal CareConnect service. It answers on / and /health and reports which container served the request. */
@SpringBootApplication
@RestController
public class AppointmentsApplication {

    private static final String SERVICE = System.getenv().getOrDefault("SERVICE_NAME", "appointments");

    public static void main(String[] args) {
        SpringApplication.run(AppointmentsApplication.class, args);
    }

    @GetMapping("/")
    public Map<String, String> home() {
        return Map.of("service", SERVICE, "container", hostname());
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }

    /** Used by the tracing demo: another service calls this so a trace spans two services. */
    @GetMapping("/work")
    public Map<String, String> work() throws InterruptedException {
        Thread.sleep(20 + (long) (Math.random() * 120));
        return Map.of("service", SERVICE, "container", hostname(), "work", "done");
    }

    private static String hostname() {
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            return "unknown";
        }
    }
}
