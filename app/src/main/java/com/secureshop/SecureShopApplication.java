package com.secureshop;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * SecureShop entry point (US-010).
 * Application configuration is externalized via application.yml
 * and environment variables / Vault-injected secrets (US-036, US-037).
 */
@SpringBootApplication
public class SecureShopApplication {
    public static void main(String[] args) {
        SpringApplication.run(SecureShopApplication.class, args);
    }
}
