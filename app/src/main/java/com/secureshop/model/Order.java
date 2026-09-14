package com.secureshop.model;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public class Order {
    private String id;
    private List<OrderItem> items;
    private BigDecimal total;
    private String status;
    private Instant createdAt;

    public Order() {}

    public Order(String id, List<OrderItem> items, BigDecimal total, String status, Instant createdAt) {
        this.id = id;
        this.items = items;
        this.total = total;
        this.status = status;
        this.createdAt = createdAt;
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public List<OrderItem> getItems() { return items; }
    public void setItems(List<OrderItem> items) { this.items = items; }
    public BigDecimal getTotal() { return total; }
    public void setTotal(BigDecimal total) { this.total = total; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
