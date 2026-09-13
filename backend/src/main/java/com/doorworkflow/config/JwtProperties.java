package com.doorworkflow.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Binds JWT properties from application.yml.
 */
@Component
@ConfigurationProperties(prefix = "jwt")
public class JwtProperties {
    /** Secret key for signing JWTs. */
    private String secret = "0123456789ABCDEF0123456789ABCDEF"; // 32-byte secret for HS256
    /** Expiration time in seconds. */
    private long expiration = 3600L; // default 1 hour

    public String getSecret() {
        return secret;
    }
    public void setSecret(String secret) {
        this.secret = secret;
    }
    public long getExpiration() {
        return expiration;
    }
    public void setExpiration(long expiration) {
        this.expiration = expiration;
    }
}

