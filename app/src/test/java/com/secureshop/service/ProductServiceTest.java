package com.secureshop.service;

import com.secureshop.model.Product;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

/**
 * US-012: JUnit unit tests for critical business logic.
 */
class ProductServiceTest {

    private ProductService productService;

    @BeforeEach
    void setUp() {
        productService = new ProductService();
    }

    @Test
    void findAll_returnsSeededProducts() {
        assertFalse(productService.findAll().isEmpty());
    }

    @Test
    void save_assignsIdWhenMissing() {
        Product p = new Product(null, "Test Product", "desc", new BigDecimal("9.99"), 5);
        Product saved = productService.save(p);
        assertNotNull(saved.getId());
    }

    @Test
    void reserveStock_succeedsWhenSufficientStock() {
        Product p = productService.save(new Product(null, "Widget", "desc", new BigDecimal("5.00"), 10));
        assertTrue(productService.reserveStock(p.getId(), 3));
        assertEquals(7, productService.findById(p.getId()).get().getStock());
    }

    @Test
    void reserveStock_failsWhenInsufficientStock() {
        Product p = productService.save(new Product(null, "Widget", "desc", new BigDecimal("5.00"), 2));
        assertFalse(productService.reserveStock(p.getId(), 5));
    }

    @Test
    void reserveStock_failsForUnknownProduct() {
        assertFalse(productService.reserveStock("does-not-exist", 1));
    }
}
