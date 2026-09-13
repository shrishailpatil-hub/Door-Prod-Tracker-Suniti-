package com.doorworkflow.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * Exception thrown when attempting to create or update a user with an email that already exists.
 * Mapped to HTTP 409 CONFLICT.
 */
@ResponseStatus(HttpStatus.CONFLICT)
public class EmailAlreadyExistsException extends RuntimeException {
    public EmailAlreadyExistsException(String message) {
        super(message);
    }
    public EmailAlreadyExistsException() {
        super("Email already exists");
    }
}
