package com.secureshop.service;

import com.secureshop.model.Order;
import com.secureshop.model.OrderItem;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Order placement / retrieval logic (US-010: "Submit orders", "Retrieve order information").
 */
@Service
public class OrderService {

    private final Map<String, Order> orders = new ConcurrentHashMap<>();
    private final ProductService productService;

    public OrderService(ProductService productService) {
        this.productService = productService;
    }

    public Order placeOrder(List<OrderItem> items) {
        if (items == null || items.isEmpty()) {
            throw new IllegalArgumentException("Order must contain at least one item");
        }

        BigDecimal total = BigDecimal.ZERO;
        for (OrderItem item : items) {
            var product = productService.findById(item.getProductId())
                    .orElseThrow(() -> new NoSuchElementException("Unknown product: " + item.getProductId()));
            if (!productService.reserveStock(item.getProductId(), item.getQuantity())) {
                throw new IllegalStateException("Insufficient stock for product: " + item.getProductId());
            }
            total = total.add(product.getPrice().multiply(BigDecimal.valueOf(item.getQuantity())));
        }

        Order order = new Order(UUID.randomUUID().toString(), items, total, "SUBMITTED", Instant.now());
        orders.put(order.getId(), order);
        return order;
    }

    public Optional<Order> findById(String id) {
        return Optional.ofNullable(orders.get(id));
    }

    public List<Order> findAll() {
        return new ArrayList<>(orders.values());
    }
}
