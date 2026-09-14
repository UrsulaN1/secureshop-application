package com.secureshop.service;

import com.secureshop.model.Product;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Product catalog logic (US-010: "Browse products", "View product details").
 * In-memory store used for demo purposes; swap for a real datastore in production
 * (connection credentials are retrieved from Vault - see US-036/US-037).
 */
@Service
public class ProductService {

    private final Map<String, Product> catalog = new ConcurrentHashMap<>();

    public ProductService() {
        seed();
    }

    private void seed() {
        save(new Product(UUID.randomUUID().toString(), "SecureShop T-Shirt",
                "Organic cotton tee", new BigDecimal("19.99"), 100));
        save(new Product(UUID.randomUUID().toString(), "SecureShop Mug",
                "Ceramic mug, 350ml", new BigDecimal("12.50"), 200));
    }

    public Product save(Product product) {
        if (product.getId() == null || product.getId().isBlank()) {
            product.setId(UUID.randomUUID().toString());
        }
        catalog.put(product.getId(), product);
        return product;
    }

    public List<Product> findAll() {
        return new ArrayList<>(catalog.values());
    }

    public Optional<Product> findById(String id) {
        return Optional.ofNullable(catalog.get(id));
    }

    public boolean reserveStock(String productId, int quantity) {
        Product p = catalog.get(productId);
        if (p == null || p.getStock() < quantity) {
            return false;
        }
        p.setStock(p.getStock() - quantity);
        return true;
    }
}
